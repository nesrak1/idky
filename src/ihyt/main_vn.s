.p816
.i16
.a8

.include "main_vn.inc"

.include "variables.inc"

.include "wf_input.inc"
.include "wf_macros.inc"
.include "wf_regs.inc"
.include "wf_video.inc"

.include "vn_char.inc"
.include "vn_text.inc"

.include "all_assets.inc"

.segment "MODEVN_CODE"

;

; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; first time setup
ModeVnReset:
    A8
    XY16
    jsr ModeVnSetupZero
ModeVnResetNext:
    jsr ModeVnMainSetup
    jmp ModeVnMainLoop
;; [pfend] ModeVnReset

.proc ModeVnSetupZero
    stz VPad1Val

    A16
    stz VZero
    A8

    rts
.endproc

; todo: where should these actually go?
VnCharHdmaTable:
    .byte $70, %01100010
    .byte $70, %01100011
    .byte $00

VnZero:
    .word $0000

;; [inputs] ?
;; [outputs] ?
;; [kills] A, X, Y
.proc ModeVnMainSetup
SetupStart:
    ; INIDSP = force blank
    WfvScreenHide

    ; NMITIMEN = enable vblank nmi events and controller reads
    ; we could move this at the bottom of the function maybe?
    ; but eh, it works so why change it?
    WfvInterruptSetup

SetupBg:
    ; see planning/memory-maps/mode-vn-v2.png for the layout
    ; we will have to do some trickery to get everything to
    ; fit in vram.
    ;
    ; BG1 (background): surprisingly, this always fits within
    ; 0x3000 words of memory, so we can reuse the last 0x4000
    ; for someone else.
    ;
    ; BG2 (chatbox & UI): uses a very tiny amount of VRAM
    ; since it is mainly the chatbox rectangles, taking up
    ; only about four tiles of space and the UI elements
    ; take up the remaining space.
    ;
    ; BG3 (chatbox & UI text): uses about 0x300 words of
    ; VRAM. BG2 and BG3 therefore can share 0x400 words of
    ; VRAM. thankfully, there is a slot open at 0x0000 since
    ; we don't need it for tilemaps; BG1, BG2, and BG3 are
    ; at 0x0400, 0x0800, and 0x0c00 respectively, giving
    ; us a little space. edit: we need more space with the
    ; higher text. thankfully, we can use the unseen parts
    ; of BG1, BG2, and BG3's tilemaps :P
    ;
    ; Sprites: preferably, we'd have about 0x3000 words of
    ; VRAM just for sprites. the hardware doesn't support
    ; that, so we need to do some trickery where we use
    ; HDMA to swap from the sprite VRAM at 0x4000 to 0x6000
    ; while drawing the characters. specifically, we cut
    ; characters into three parts (64 pixels high each),
    ; then swap from the first two parts to the last two
    ; parts in VRAM. the swap occurs when the beam hits the
    ; last part, aka 64 pixels from the bottom of the
    ; screen. That way, sprites can have different Y values
    ; and not be affected. This just means sprites' VRAM
    ; layouts have to be modified depending on the multiple
    ; of 64 pixels the sprite is from the screen bottom.

    ; BGMODE = mode 1, BG3 priority, 8x8 size BGs
    WfvBgMode 1, 1, 0,0,0,0

    ; BG12NBA = start BG1/BG2 tileset at BG1=$1000,BG2=$0000
    ; BG34NBA = start BG3/BG4 tileset at BG3=$0000,BG4=$0000
    WfvBgTilesetConfig CVramBg1Tiles, CVramBg2Tiles, CVramBg3Tiles, $0000

    ; BG1SC = start BG1 tilemap at $0400
    WfvBgTilemapConfig 1, CVramBg1Map, 0,0
    ; BG2SC = start BG2 tilemap at $0800
    WfvBgTilemapConfig 2, CVramBg2Map, 0,0
    ; BG3SC = start BG3 tilemap at $0C00
    WfvBgTilemapConfig 3, CVramBg3Map, 0,0

    ; VMAIN = enable increment mode
    lda #$80
    sta VMAIN

    ; TMAIN = enable BG1, BG2, BG3, and sprites
    lda #%00010111
    sta TMAIN

    ; TSUB = enable BG1 and BG3
    ; BG2 is skipped from SUB so it can be transparent looking
    lda #%00010101 ; use BG1 & BG3
    sta TSUB

    jsr VnResetBg1
    jsr VnResetBg2
    jsr VnChatResetBg3

    lda #3
    sta VScb0 ; x
    lda #22
    sta VScb1 ; y
    lda #26
    sta VScb2 ; width
    lda #3
    sta VScb3 ; height
    jsr VnChatDrawSetup

SetupColor:

    ; set background palette color to black
    stz CGADD
    stz CGDATA
    stz CGDATA

    ; CGWSEL
    lda #%00000010
    sta CGWSEL

    ; CGADSUB = add color math, half color math, BG1 color math enabled
    lda #%01000010
    sta CGADSUB

    ; set the "backdrop pixel" color to all black, matching palette 0,0's color
    stz COLDATA

SetupSprites:

    ; OBJSEL = start sprite tileset at $4000 (will reposition to $6000 with HDMA)
    WfvSpriteConfig SpriteCfgSize::SZ_16x16_32x32, CVramSpritesA, SpriteCfgGap::NO_GAP

    ; Setup HDMA so we can compact sprite data
    ; DMAP1 = pattern 0, increment A, from A to B
    stz DMAP1

    ; DMADEST1 = modify OBJSEL
    lda #<OBJSEL
    sta DMADEST1

    ; DMASRC1 = VnCharHdmaTable
    ldx #.loword(VnCharHdmaTable)
    stx DMASRC1L
    lda #^VnCharHdmaTable
    sta DMASRC1B

SetupOther:

    jsr VnCharReset

SetupEnd:
    stz VFrameReady
    :
        lda VFrameReady
    beq :-

    ; init display, full brightness
    WfvScreenShow

    ; enable sprite HDMA
    lda #00000010
    sta HDMAEN

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP ;

; SCENE SWAP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] todo: handle multiple backgrounds
.proc VnResetBg1
    ; copy bg palette data to palette 0, 0
    WfvPal16Addr 0
    WfvPalLoad ABkgClassroom1_Palette_P, $20

    ; copy bg tile set
    WfvBgAddr $1000
    WfvBgLoad ABkgClassroom1_Tileset_T, (ABkgClassroom1_Tileset_TE-ABkgClassroom1_Tileset_T)

    ; copy bg tile map
    WfvBgAddr $0400
    WfvBgLoad ABkgClassroom1_Tilemap_M, (ABkgClassroom1_Tilemap_ME-ABkgClassroom1_Tilemap_M)

    ; move BG1 down one pixel (otherwise we get uninitialized pixels at the bottom)
    lda #$FF
    sta BG1VOFS
    sta BG1VOFS

    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] todo: handle multiple backgrounds
.proc VnResetBg2
    ; clear all tiles
    stz VMADDH
    ldx #$0800
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $800

    ; copy bg palette data to palette 1, 0
    WfvPal16Addr 1
    WfvPalLoad AUiChatboxDark_Palette_P, $20

    ; copy bg tile set (offset so first tile is empty)
    WfvBgAddr $0010
    WfvBgLoad AUiChatboxDark_Tileset_T, (AUiChatboxDark_Tileset_TE-AUiChatboxDark_Tileset_T)

    ; copy bg tile map (at the bottom of the screen)
    WfvBgAddr $0AA0
    WfvBgLoad AUiChatboxDark_Tilemap_M, (AUiChatboxDark_Tilemap_ME-AUiChatboxDark_Tilemap_M)

    ; move BG2 down one pixel
    lda #$FF
    sta BG2VOFS
    sta BG2VOFS

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SCENE SWAP ;

; LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [inputs] none
;; [outputs] none
;; [kills] A
;; [inlined]
.proc UpdateInput
    last_pad1_val = VScw0

    A16
    WaitJoy:
        lda HVBJOY
        and #1
    bne WaitJoy

    ; last_pad1_val = VPad1Val
    ; VPad1Val = JOY1L
    ; VPad1Fir = VPad1Val & (~last_pad1_val)

    lda VPad1Val
    sta last_pad1_val

    lda JOY1L
    sta VPad1Val

    ; could trb be faster here?
    lda last_pad1_val
    eor #$FFFF
    and VPad1Val
    sta VPad1Fir

    A8Zero
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A
;; [inlined]
.proc TestingStuff
CCharIdx_A = 0
CCharIdx_B = 1
CCharIdx_C = 2
CCharIdx_D = 3
CCharIdx_E = 4
CCharIdx_F = 5
CCharIdx_G = 6
CCharIdx_H = 7
CCharIdx_I = 8
CCharIdx_J = 9
CCharIdx_K = 10
CCharIdx_L = 11
CCharIdx_M = 12
CCharIdx_N = 13
CCharIdx_O = 14
CCharIdx_P = 15
CCharIdx_Q = 16
CCharIdx_R = 17
CCharIdx_S = 18
CCharIdx_T = 19
CCharIdx_U = 20
CCharIdx_V = 21
CCharIdx_W = 22
CCharIdx_X = 23
CCharIdx_Y = 24
CCharIdx_Z = 25
CCharIdx_a = 26
CCharIdx_b = 27
CCharIdx_c = 28
CCharIdx_d = 29
CCharIdx_e = 30
CCharIdx_f = 31
CCharIdx_g = 32
CCharIdx_h = 33
CCharIdx_i = 34
CCharIdx_j = 35
CCharIdx_k = 36
CCharIdx_l = 37
CCharIdx_m = 38
CCharIdx_n = 39
CCharIdx_o = 40
CCharIdx_p = 41
CCharIdx_q = 42
CCharIdx_r = 43
CCharIdx_s = 44
CCharIdx_t = 45
CCharIdx_u = 46
CCharIdx_v = 47
CCharIdx_w = 48
CCharIdx_x = 49
CCharIdx_y = 50
CCharIdx_z = 51
CCharIdx_0 = 52
CCharIdx_1 = 53
CCharIdx_2 = 54
CCharIdx_3 = 55
CCharIdx_4 = 56
CCharIdx_5 = 57
CCharIdx_6 = 58
CCharIdx_7 = 59
CCharIdx_8 = 60
CCharIdx_9 = 61
CCharIdx_period = 62
CCharIdx_question = 63
CCharIdx_exclamation = 64
CCharIdx_comma = 65
CCharIdx_quote = 66
CCharIdx_doublequote = 67
CCharIdx_colon = 68
CCharIdx_semicolon = 69
CCharIdx_tilde = 70
CCharIdx_ellipsis = 71
CCharIdx_space = 72

    A16

    lda #JOY_A
    trb VPad1Fir
    beq NotAddChar
        A8Zero
        jsr VnCharAdd
        A16
    NotAddChar:

    lda #JOY_RIGHT
    trb VPad1Val
    beq NotMoveRight
        inc VCharData + TCharData::cx
    NotMoveRight:

    lda #JOY_LEFT
    trb VPad1Val
    beq NotMoveLeft
        dec VCharData + TCharData::cx
    NotMoveLeft:

    lda #JOY_B
    trb VPad1Fir
    beq NotWriteMsg
        A8Zero
        jsr VnChatResetLine
        lda #CCharIdx_H
        jsr VnChatDraw
        lda #CCharIdx_e
        jsr VnChatDraw
        lda #CCharIdx_l
        jsr VnChatDraw
        lda #CCharIdx_l
        jsr VnChatDraw
        lda #CCharIdx_o
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_q
        jsr VnChatDraw
        lda #CCharIdx_u
        jsr VnChatDraw
        lda #CCharIdx_i
        jsr VnChatDraw
        lda #CCharIdx_c
        jsr VnChatDraw
        lda #CCharIdx_k
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_b
        jsr VnChatDraw
        lda #CCharIdx_r
        jsr VnChatDraw
        lda #CCharIdx_o
        jsr VnChatDraw
        lda #CCharIdx_w
        jsr VnChatDraw
        lda #CCharIdx_n
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_f
        jsr VnChatDraw
        lda #CCharIdx_o
        jsr VnChatDraw
        lda #CCharIdx_x
        jsr VnChatDraw
        lda #CCharIdx_exclamation
        jsr VnChatDraw
        A16
    NotWriteMsg:

    lda #JOY_X
    trb VPad1Fir
    bne WriteMsg2
    jmp NotWriteMsg2
    WriteMsg2:
        A8Zero
        jsr VnChatResetLine
        lda #CCharIdx_T
        jsr VnChatDraw
        lda #CCharIdx_h
        jsr VnChatDraw
        lda #CCharIdx_i
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_i
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_a
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_t
        jsr VnChatDraw
        lda #CCharIdx_e
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_t
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_m
        jsr VnChatDraw
        lda #CCharIdx_e
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_a
        jsr VnChatDraw
        lda #CCharIdx_g
        jsr VnChatDraw
        lda #CCharIdx_e
        jsr VnChatDraw
        lda #CCharIdx_comma
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_i
        jsr VnChatDraw
        lda #CCharIdx_t
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_i
        jsr VnChatDraw
        lda #CCharIdx_s
        jsr VnChatDraw
        lda #CCharIdx_space
        jsr VnChatDraw
        lda #CCharIdx_l
        jsr VnChatDraw
        lda #CCharIdx_o
        jsr VnChatDraw
        lda #CCharIdx_n
        jsr VnChatDraw
        lda #CCharIdx_g
        jsr VnChatDraw
        lda #CCharIdx_exclamation
        jsr VnChatDraw
        A16
    NotWriteMsg2:

    lda #JOY_DOWN
    trb VPad1Fir
    beq NotMoveTextDown
        A8Zero
        inc VMsgTileMode
        lda #1
        sta VMsgTilesReady
        A16
    NotMoveTextDown:

    lda #JOY_UP
    trb VPad1Fir
    beq NotMoveTextUp
        A8Zero
        dec VMsgTileMode
        lda #1
        sta VMsgTilesReady
        A16
    NotMoveTextUp:

    A8Zero
    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; LOOP ;

; MAIN LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [noreturn]
.proc ModeVnMainLoop
MainLoopWait:
    ; === during vblank ===
    WfvDmaCopyOneRegRev OAMDATA, (VSprLo + 511), 512
    WfvDmaCopyOneReg OAMDATA, VSprHi, 32
    
    lda VMsgTilesReady
    beq ChatTilesReadyFalse
        jsr VnChatCopyTilesToVram
    ChatTilesReadyFalse:

    ; note: UpdateInput can't be first, otherwise we wait
    ; ages for the controller to get back to us
    jsr UpdateInput

    ; === during screen time ===
    jsr TestingStuff
    jsr VnCharUpdate

    ; wait for next frame
    stz VFrameReady
    :
        lda VFrameReady
    beq :-

    jmp ModeVnMainLoop
.endproc