.p816
.i16
.a8

.include "main_pf.inc"

.include "variables.inc"

.include "wf_input.inc"
.include "wf_macros.inc"
.include "wf_regs.inc"
.include "wf_video.inc"

.include "all_assets.inc"

.segment "MODEPF_CODE"

;

; SETUP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; first time setup
ModePfReset:
    A8
    XY16
    jsr ModePfSetupZero
ModePfResetNext:
    jsr ModePfMainSetup
    jmp ModePfMainLoop
;; [pfend] ModePfReset

.proc ModePfSetupZero
    stz VPad1Val

    A16
    stz VZero

    lda #240
    sta VWrdNextX
    lda #240
    sta VWrdNextY

    stz VFlags + 0
    stz VFlags + 2
    stz VFlags + 4
    stz VFlags + 6
    stz VFlags + 8
    A8

    stz VWrdCamTime

    lda #1
    sta VWrdNextLvl
    sta VWrdCurLvl
    rts
.endproc

PfZero:
    .word $0000

;; [inputs] ?
;; [outputs] ?
;; [kills] A, X, Y
.proc ModePfMainSetup
SetupStart:
    ; INIDSP = force blank
    WfvScreenHide

    ; NMITIMEN = enable vblank nmi events and controller reads
    WfvInterruptSetup

SetupBG:
    ; BGMODE = mode 1, BG3 priority, 16x16 size BGs 1 & 2
    WfvBgMode 1, 1, 1,1,0,0

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

    ; TMAIN = enable BG1, ~~BG2~~, ~~BG3~~, and ~~sprites~~
    lda #%00000001
    sta TMAIN

    jsr PfLoadMapTileAndPal
    jsr PfLoadMap
    jsr PfLoadMapSprites

SetupOther:

    ; if we were transitioning levels, unset the next level byte
    stz VWrdNextLvl
    
    ; remove!!! dbg only!!!
    A16
    stz VPlyData + TPlyData::px
    stz VPlyData + TPlyData::py
    A8

SetupEnd:
    stz VFrameReady
    :
        lda VFrameReady
    beq :-

    ; init display, full brightness
    WfvScreenShow

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; SETUP ;

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
.proc PfLoadMapTileAndPal
    ; Y = &AWorldTilesetAll_MetaTable[AWorldLevelAll_MetaTable[VWrdNextLvl].6].0 - &AWorldTilesetAll_MetaTable
    ; (Y is used by WfvDmaCopyOneRegOff)
    lda VWrdNextLvl
    beq NoLevelSubtract ; 2026 me: why are we doing this?
        dec
    NoLevelSubtract:
    ;
    A16
    mul8
    ;
    lda AWorldLevelAll_MetaTable + 6, Y
    and #$00FF
    mul16
    ;
    tay
    A8Zero

    ; start at pal 1, 0
    WfvPal16Addr 1
    ; copy normal map top palette to 1, 0
    WfvDmaCopyOneRegOff CGDATA, AWorldTilesetAll_MetaTable + 0, $20

    ; set bg color
    WfvPal16Addr $00
    ; lda #$BE
    ; sta CGDATA
    ; lda #$77
    ; sta CGDATA
    stz CGDATA
    stz CGDATA

    ; copy normal level tile data
    WfvBgAddr $0000
    WfvDmaCopyTwoRegOff VMDATAL, AWorldTilesetAll_MetaTable + 3, AWorldTilesetAll_MetaTable + 9

    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
.proc PfLoadMap
    src_tileidx = VScw0
    tmp = VScw1
    ctr = VScw2
    ; load the waffle level data but insert 00s every
    ; other byte as a form of decompression (since we
    ; never use the upper half of the tile word)
LoadRawMapBytes:
    AZero
    lda VWrdNextLvl
    beq NoLevelSubtract
        dec
    NoLevelSubtract:
    ;
    A16
    mul8
    tax
    A8

    ldy AWorldLevelAll_MetaTable + 0, X

    ; also set the right data bank value
    phb ; save old DB
    ;
    lda AWorldLevelAll_MetaTable + 2, X
    pha
    plb ; then load bank into DB

    ; load width and height values
    lda a:4, Y
    sta VWrdBoundW
    dec
    sta VWrdBoundmskW
    ;
    lda a:5, Y
    sta VWrdBoundH
    dec
    sta VWrdBoundmskH
    ;
    ldx a:6, Y
    stx ctr
    dex
    stx VWrdBoundmskF

    A16
    ; set camera on player, then clip camera within bounds
    ldx VWrdNextX
    jsr ClipCameraX
    sub #128
    sta VWrdCamX
    ;
    and #$0F
    sta VWrdCamPX

    tyx
    ldy VWrdNextY
    jsr ClipCameraY
    sub #112
    sta VWrdCamY
    ;
    and #$0F
    sta VWrdCamPY
    
    ; start of real map data src
    txa
    add #16
    tay
    
    ; expanded map data dest
    ldx #.loword(VMapData0)

    TileCopyLoop:
        A8
        ; *(u8*)(X++) = *(u8*)(Y++)
        ; *(u8*)(X++) = 0x04
        lda a:0, Y
        sta f:VMapData0, X
        cmp #$80
        bge TileCopyEight
            lda #$04 ; use palette at $10
            sta f:VMapData0 + 1, X
            bra TileCopyEightDone
        TileCopyEight:
            lda #$04 ; use palette at $20 (todo: not setup yet)
            sta f:VMapData0 + 1, X
        TileCopyEightDone:

        iny
        inx
        inx

        A16
        dec ctr
    bne TileCopyLoop

    ; starting at the camera X and Y tile coords, start
    ; copying horizontal strips from the top down
LoadVisibleIntoVramStaging:
    SetSrcTileYOff:
        ; VWrdCamTY = ((VWrdCamY >> 4) - 8)
        ; src_tileyoff = (((VWrdCamY >> 4) - 8) * V_WRD_BOUNDW) << 1
        lda VWrdCamY
        div16
        
        sec
        sbc #8

        ; store into VWrdCamTY while we're at it
        A8
        sta VWrdCamTY
        sta WRMPYA
        
        lda VWrdBoundW
        sta WRMPYB
        A16

        nop
        lda VWrdBoundmskF
        and RDMPYL

        asl
        sta tmp
    ; SetSrcTileYOff

    SetTileIdx:
        ; VWrdCamTX = ((VWrdCamX >> 4) - 8)
        ; src_tileidx = (((VWrdCamX >> 4) - 8) << 1) + src_tileyoff
        ; if on the edges, this will cause us to read garbage. this is fine
        ; since the bg scroll camera won't be showing it.
        lda VWrdCamX
        div16
        sub #8

        ; store into VWrdCamTX while we're at it
        A8
        sta VWrdCamTX
        A16

        asl
        clc
        adc tmp ; src_tileyoff
        sta src_tileidx
    ; SetTileIdx

    ; set offset such that bg scroll camera always starts in the center
    ; of the screen.
    ; VWrdCamOX = 128 - (VWrdCamX & 0xF0)
    ; VWrdCamOY = 128 - (VWrdCamY & 0xF0)
    SetDefaultCamPos:
        lda VWrdCamX
        and #$FFF0
        sta tmp
        ;
        lda #128
        sec
        sbc tmp
        sta VWrdCamOX

        lda VWrdCamY
        and #$FFF0
        sta tmp
        ;
        lda #128
        sec
        sbc tmp
        sta VWrdCamOY
    ; SetDefaultCamPos
    
    ; mvn will change DB but thankfully we already pushed
    ; it to the stack at the beginning of this function

    ; set counter for 32 tiles vertically
    lda #$20
    sta ctr

    ldx src_tileidx ; copy from src_tileidx
    ldy #.loword(VMapTiles0) ; copy to VMapTiles0
    CopyHStripLoop:
        lda #($40 - $1) ; reset A to copy 64 bytes horizontally
        mvn #$7F, #$7F ; copy from hiram1 -> hiram1
        ;; [here] DB = 0x7F
        ; ^ this is fine because we only use ZP values in this loop

        ; move src_tileidx to next row (by adding width)
        lda VWrdBoundW
        asl
        and #$FF
        add src_tileidx
        and VWrdBoundmskF
        tax
        stx src_tileidx

        ; Y (dest) register is already in the correct spot
        ; (since mvn moved it there)

        dec ctr
    bne CopyHStripLoop
    
    plb ; restore DB

    ; A16 sets both X and Y
    stz VWrdCamVsX
    A8Zero

    stz VWrdCamVRdy

LoadVramStagingIntoVram:
    ; VMADDL = CVramBg1Map (layer 1 map data)
    ldx #CVramBg1Map
    stx VMADDL

    WfvDmaCopyTwoReg VMDATAL, VMapTiles0, $800

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;

; SPRITE LOAD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; LoadMapSpritesNpcs:
;     .word .loword(A_OVERWORLD_LAYER1_LEVEL0_N)
;     .word .loword(A_OVERWORLD_LAYER1_LEVEL1_N)

LoadMapSprites_Zero: .word $0000

;; [inputs] none
;; [outputs] none
;; [kills] axy
.proc PfLoadMapSprites
    tmp = VScw1

    ; clear all sprite data
    stz WMADDH
    ldx #.loword(VSprLo)
    stx WMADDL
    WfvDmaMemsetOneReg WMDATA, LoadMapSprites_Zero, $220

    ; and move sprites offscreen by default
    ; todo: we have a better way to do this now (vn_char.s, VnCharReset)
    ldx #1
    ldy #128
    SetSpriteYOffscreenLoop:
        lda #$E0
        sta VSprLo, X
        inx
        inx
        inx
        inx

        dey
    bne SetSpriteYOffscreenLoop

    ; ; copy player/npc palettes
    ; lda #$80
    ; sta CGADD
    ; BGDmaCopyOnereg CGDATA, AOverworldCharsP, $20
    ; BGDmaCopyOnereg CGDATA, AOverworldMitatP, $20
    ; ;
    ; ; copy player/npc tiles
    ; lda #$80
    ; sta VMAIN
    ; ldx #$2000
    ; stx VMADDL
    ; BGDmaCopyTworeg VMDATAL, AOverworldCharsT, $400
    ; BGDmaCopyTworeg VMDATAL, AOverworldMitatT, $400

    ; ; get level index
    ; AZero
    ; lda VWrdNextLvl
    ; beq NoLevelSubtract
    ;     dec
    ; NoLevelSubtract:
    ; asl
    ; tax
    ; ldy LoadMapSpritesNpcs, X

    ; ; copy map npc data data
    ; CopyMapSize = (A_OVERWORLD_LAYER1_LEVEL0_NE - A_OVERWORLD_LAYER1_LEVEL0_N) ; always the same size for every level
    ; lda #$0000
    ; sta WMADDH
    ; ldx #V_NPCDATA
    ; stx WMADDL
    ; BGDmaCopyOneregDyn WMDATA, $00, CopyMapSize

    lda #%00000001
    sta OBJSEL ; OBJSEL.base = $2000

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;

; LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [inputs] none
;; [outputs] none
;; [kills] a
;; [inlined]
.proc UpdateInput
    lastPad1Val = VScw0

    A16
    WaitJoy:
        lda HVBJOY
        and #1
    bne WaitJoy

    ; lastPad1Val = VPad1Val
    ; VPad1Val = JOY1L
    ; VPad1Fir = VPad1Val & (~lastPad1Val)

    lda VPad1Val
    sta lastPad1Val

    lda JOY1L
    sta VPad1Val

    ; could trb be faster here?
    lda lastPad1Val
    eor #$FFFF
    and VPad1Val
    sta VPad1Fir

    A8Zero
    rts
.endproc

; AnimTable:
;     .byte 0, 2, 4, 6, 8, 6, 4, 2

; for moving left and right
;; [inputs] y: isright
;; [outputs] none
;; [kills] axy
;; [assume] SCRW0, SCRW1, SCRB0, SCRB1
.proc LoadTilesVerticalStrip
    srcTileYOff = VScw2
    ctr = VScb2
GetStartingMapCoord:
    A16
    SrcTileYOff:
        ; srcTileYOff = (VWrdCamTY * VWrdBoundW) << 1
        A8
        lda VWrdCamTY
        sta WRMPYA
        
        lda VWrdBoundW
        sta WRMPYB
        A16

        nop
        lda RDMPYL

        asl
        sta srcTileYOff
    ; SrcTileYOff

    ; tya
    ; cmp #1
    cpy #1
    bne SrcTileXYOffLeft
    SrcTileXYOffRight:
        ; srcTileYOff = ((VWrdCamTX + 31) << 1) + srcTileYOff
        ; we really want 32 tiles ahead, but VWrdCamTX increased
        ; by 1 before this function was called.
        lda VWrdCamTX
        clc
        adc #32
        and #$FF
        and VWrdBoundmskW ; map width - 1
        asl

        clc
        adc srcTileYOff

        ; set X = src offset (far)
        tax
        A8
        ; set flag to copy on next vblank
        lda VWrdCamVRdy
        ora #%00000001
        sta VWrdCamVRdy

        lda VWrdCamVsX
        inc
        and #$1F
        sta VWrdCamVsX
        A16
        
        bra SrcTileXYOffDone
    SrcTileXYOffLeft:
        ; srcTileYOff = (VWrdCamTX << 1) + srcTileYOff
        ; we really want 1 tile back, but VWrdCamTX decreased
        ; by 1 before this function was called.
        lda VWrdCamTX
        dec
        and #$FF
        and VWrdBoundmskW ; map width - 1
        asl

        clc
        adc srcTileYOff

        ; set X = src offset (far)
        tax
        A8
        ; set flag to copy on next vblank
        lda VWrdCamVRdy
        ora #%00000010
        sta VWrdCamVRdy

        lda VWrdCamVsX
        dec
        and #$1F
        sta VWrdCamVsX
        A16
    SrcTileXYOffDone:

CopyMapData:
    ; set Y = dst offset (short)
    lda VWrdCamVsY
    asl
    and #$FF
    tay

    lda #32
    sta ctr

    CopyMapDataLoop:
        txa
        and VWrdBoundmskF ; (map width * map height * 2 bytes per tile) - 1
        tax

        lda f:VMapData0, X
        sta VWrdStripCpyX, Y

        tya
        inc
        inc
        ; wrap around the strip if we don't start at 0
        and #(32 * 2 - 1) ; (32 tiles * 2 bytes per tile) - 1
        tay

        txa
        clc
        adc VWrdBoundW
        adc VWrdBoundW
        tax

        dec ctr
    bne CopyMapDataLoop

    A8
    rts
.endproc

; for moving up and down
;; [inputs] y: isdown
;; [outputs] none
;; [kills] axy
;; [assume] SCRW0, SCRW1, SCRB0, SCRB1
.proc LoadTilesHorizontalStrip
    srcTileYOff = VScw2
    tmp = VScw3
    ctr = VScb2
GetStartingMapCoord2:
    A16
    ; tya
    ; cmp #1
    cpy #1
    bne SrcTileYOffTop
    SrcTileYOffBottom:
        ; srcTileYOff = ((VWrdCamTY + 31) * VWrdBoundW) << 1
        A8
        lda VWrdCamTY
        clc
        adc #32
        and #$FF
        sta WRMPYA
        
        lda VWrdBoundW
        sta WRMPYB
        
        ; set flag to copy on next vblank
        lda VWrdCamVRdy
        ora #%00000100
        sta VWrdCamVRdy

        lda VWrdCamVsY
        inc
        and #$1F
        sta VWrdCamVsY
        A16

        bra SrcTileYOffDone
    SrcTileYOffTop:
        ; srcTileYOff = ((VWrdCamTY - 0) * VWrdBoundW) << 1
        A8
        lda VWrdCamTY
        dec
        sta WRMPYA
        
        lda VWrdBoundW
        sta WRMPYB
        
        ; set flag to copy on next vblank
        lda VWrdCamVRdy
        ora #%00001000
        sta VWrdCamVRdy

        lda VWrdCamVsY
        dec
        and #$1F
        sta VWrdCamVsY
        A16
    SrcTileYOffDone:
    
    lda RDMPYL
    asl
    sta srcTileYOff

    ldy #0
    SrcTileXYOffLeft:
        ; srcTileYOff = (VWrdCamTX << 1) + srcTileYOff
        ; if (VWrdCamTX < 0) srcTileYOff -= (VWrdBoundW << 1)
        lda VWrdCamTX
        and #$FF

        ; hack to prevent X wrap from going down a Y
        bit #%10000000
        beq NotMovingUpOne
            XY8
            ldy VWrdBoundW
            XY16
        NotMovingUpOne:
        sty tmp

        and VWrdBoundmskW ; map width - 1
        asl

        clc
        adc srcTileYOff
        sec
        sbc tmp
        sbc tmp

        ; set X = src offset (far)
        tax

CopyMapData2:
    ; set Y = dst offset (short)
    lda VWrdCamVsX
    asl
    and #$FF
    tay

    lda #32
    sta ctr

    CopyMapDataLoop2:
        ; this causes us to wrap to the left and one down, but the
        ; "hack to prevent X wrap from going down a Y" raised the
        ; starting Y by 1 tile so that after wrap around, we're on
        ; the correct tile.
        txa
        and VWrdBoundmskF ; (map width * map height * 2 bytes per tile) - 1
        tax

        lda f:VMapData0, X
        sta VWrdStripCpyY, Y

        tya
        inc
        inc
        ; wrap around the strip if we don't start at 0
        and #(32 * 2 - 1) ; (32 tiles * 2 bytes per tile) - 1
        tay

        inx
        inx

        dec ctr
    bne CopyMapDataLoop2

    A8
    rts
.endproc

;; [inputs] x: target cam X
;; [outputs] none
;; [kills] a
;; [assume] A16, XY16
.a16
.proc ClipCameraX
    tmp = VScw3
    ; calculate camera max X
    lda VWrdBoundW
    and #$FF
    sub #8 ; amount of tiles wide of BG camera
    mul16
    sta tmp

    ; VWrdCamX = ((VPlyData.x - 128 - VWrdCamX) / 4) + VWrdCamX
    txa
    
    ; bounds check
    cmp #$80
    bge :+
        lda #$80
        bra :+++
    :
        cmp tmp
        blt :+
            lda tmp
        :
    :
    rts
.endproc
.a8

;; [inputs] y: target cam Y
;; [outputs] none
;; [kills] a
;; [assume] A16, XY16
.a16
.proc ClipCameraY
    tmp = VScw3
    ; calculate camera max Y
    lda VWrdBoundH
    and #$FF
    sub #8 ; amount of tiles wide of BG camera
    mul16
    sta tmp

    ; VWrdCamY = ((VPlyData.y - 128 - VWrdCamY) / 4) + VWrdCamY
    tya

    ; bounds check
    cmp #$80
    bge :+
        lda #$80
        bra :+++
    :
        cmp tmp
        blt :+
            lda tmp
        :
    :
    rts
.endproc
.a8

;; [inputs] none
;; [outputs] none
;; [kills] axy
;; [inlined]
.proc UpdateCamera
    newCamTileXY = VScw0
    tmp = VScw1
    flagsX = VScb0
    flagsY = VScb1
CheckLoadNewTilesX:
    A16
    lda VWrdCamX
    div16
    tax

    ; sets both flagsX and flagsY
    stz flagsX

    lda VWrdCamTX
    sta newCamTileXY

    ; CAMT_X is based on -8 being the first index,
    ; so we add 8 so the unsigned compare works.
    lda VWrdCamTX
    clc
    adc #8
    and #$FF ; wrap single byte
    sta tmp
    ;
    cpx tmp
    beq CheckLoadNewTilesXDone
    bcc NewXLessThan
    NewXGreaterThan:
        ; load tiles on the right of screen
        A8Zero
        inc newCamTileXY

        ; set right direction flag
        lda #1
        sta flagsX
        A16

        bra CheckLoadNewTilesXDone
    NewXLessThan:
        ; load tiles on the left of screen
        A8Zero
        dec newCamTileXY

        ; set left direction flag
        lda #2
        sta flagsX
        A16
    CheckLoadNewTilesXDone:

CheckLoadNewTilesY:
    lda VWrdCamY
    div16
    tax

    ; CamTY is based on -8 being the first index,
    ; so we add 8 so the unsigned compare works.
    lda VWrdCamTY
    clc
    adc #8
    and #$FF ; wrap single byte
    sta tmp
    ;
    cpx tmp
    beq CheckLoadNewTilesYDone
    bcc NewYLessThan
    NewYGreaterThan:
        ; load tiles on the bottom of screen
        A8Zero
        inc newCamTileXY + 1

        ; set down direction flag
        lda #1
        sta flagsY
        A16

        bra CheckLoadNewTilesYDone
    NewYLessThan:
        ; load tiles on the top of screen
        A8Zero
        dec newCamTileXY + 1

        ; set up direction flag
        lda #2
        sta flagsY
        A16
    CheckLoadNewTilesYDone:
    
    A8Zero
    lda flagsX
    beq NoNewTilesX
        tay
        jsr LoadTilesVerticalStrip
    NoNewTilesX:

    ; set new X
    lda newCamTileXY
    sta VWrdCamTX

    A8Zero
    lda flagsY
    beq NoNewTilesY
        tay
        jsr LoadTilesHorizontalStrip
    NoNewTilesY:

    ; set new Y
    lda newCamTileXY + 1
    sta VWrdCamTY

    A8Zero
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] ax
.proc RenderMap
SetBgScroll:
    A16
    lda VWrdCamY
    clc
    adc VWrdCamOY
    A8

    sta BG1VOFS
    xba
    sta BG1VOFS

    A16
    lda VWrdCamX
    clc
    adc VWrdCamOX
    A8

    sta BG1HOFS
    xba
    sta BG1HOFS
    xba

    ; fg parallax, disabled since it was kinda ugly (for now)
    ; A16
    ; mul2
    ; A8
    ; sta BG3HOFS
    ; xba
    ; sta BG3HOFS
    ; xba

CopyTilesIfNeeded:
    lda VWrdCamVRdy
    bne HaveTilesToCopy
        rts
    HaveTilesToCopy:

    ; copy vertical strip
    lda VWrdCamVRdy
    bit #%00000011
    beq NoVerticalStripCopy
        ; undo move VWrdCamVsX left early
        lda VWrdCamVRdy
        bit #%00000001
        beq NotMovingLeft
            lda VWrdCamVsX
            dec
            and #$1F
            sta VWrdCamVsX
        NotMovingLeft:

        ; VMADDL = CVramBg1Map + X
        A16
        lda VWrdCamVsX
        and #$1F
        clc
        adc #CVramBg1Map
        sta VMADDL
        A8

        ; VMAIN = enable increment mode down
        lda #$81
        sta VMAIN
        
        WfvDmaCopyTwoReg VMDATAL, VWrdStripCpyX, $40

        ; VMAIN = enable increment mode right (reset to normal mode)
        lda #$80
        sta VMAIN

        ; redo move VWrdCamVsX right late
        lda VWrdCamVRdy
        bit #%00000001
        beq NotMovingRight
            lda VWrdCamVsX
            inc
            and #$1F
            sta VWrdCamVsX
        NotMovingRight:

        lda VWrdCamVRdy
        and #%11111100
        sta VWrdCamVRdy
    NoVerticalStripCopy:

    ; copy horizontal strip
    lda VWrdCamVRdy
    bit #%00001100
    beq NoHorizontalStripCopy
        ; undo VWrdCamVsY down early
        lda VWrdCamVRdy
        bit #%00000100
        beq NotMovingDownUndo
            lda VWrdCamVsY
            dec
            and #$1F
            sta VWrdCamVsY
        NotMovingDownUndo:

        ; VMADDL = CVramBg1Map + Y * 32
        A16
        lda VWrdCamVsY
        and #$1F
        mul32
        clc
        adc #CVramBg1Map
        sta VMADDL
        A8

        ; VMAIN = enable increment mode right
        lda #$80
        sta VMAIN

        WfvDmaCopyTwoReg VMDATAL, VWrdStripCpyY, $40

        ; redo move VWrdCamVsY down late
        lda VWrdCamVRdy
        bit #%00000100
        beq NotMovingDown
            lda VWrdCamVsY
            inc
            and #$1F
            sta VWrdCamVsY
        NotMovingDown:

        lda VWrdCamVRdy
        and #%11110011
        sta VWrdCamVRdy
    NoHorizontalStripCopy:
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] axy
.proc RenderSceneTransition
    lda VWrdCamTime
    bne CamtimeRunning
        rts
    CamtimeRunning:

    lda VWrdNextLvl
    beq CamtimeNegative
        ; 0 -> 31
        lda #31
        sub VWrdCamTime
        div2
        sta INIDSP

        lda VWrdCamTime
        inc
        sta VWrdCamTime
        cmp #31
        beq CamtimeGoingNegative
            rts
        CamtimeGoingNegative:

        ; reset the stack pointer since EVERYTHING is resetting
        ldx #(VStackSpace + $100 - 1)
        txs

        jmp ModePfResetNext
    CamtimeNegative:
        ; 31 -> 0
        lda #31
        sub VWrdCamTime
        div2
        sta INIDSP

        dec VWrdCamTime
        rts
    CamtimeNegativeEnd:

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; MAIN LOOP ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc DebugCamera
    A16
    
    lda #JOY_LEFT
    trb VPad1Val
    beq NotMoveLeft
        dec VPlyData + TPlyData::px
        dec VPlyData + TPlyData::px
        dec VPlyData + TPlyData::px
    NotMoveLeft:
    
    lda #JOY_RIGHT
    trb VPad1Val
    beq NotMoveRight
        inc VPlyData + TPlyData::px
        inc VPlyData + TPlyData::px
        inc VPlyData + TPlyData::px
    NotMoveRight:
    
    lda #JOY_UP
    trb VPad1Val
    beq NotMoveUp
        dec VPlyData + TPlyData::py
        dec VPlyData + TPlyData::py
        dec VPlyData + TPlyData::py
    NotMoveUp:
    
    lda #JOY_DOWN
    trb VPad1Val
    beq NotMoveDown
        inc VPlyData + TPlyData::py
        inc VPlyData + TPlyData::py
        inc VPlyData + TPlyData::py
    NotMoveDown:

    ldx VPlyData + TPlyData::px
    ldy VPlyData + TPlyData::py

    UpdateCameraPosition:
        jsr ClipCameraX
        sub #128
        sub VWrdCamX
        div2signed
        div2signed
        div2signed
        add VWrdCamX
        sta VWrdCamX
        and #$0F
        sta VWrdCamPX

        jsr ClipCameraY
        sub #112
        sub VWrdCamY
        div2signed
        div2signed
        div2signed
        add VWrdCamY
        sta VWrdCamY
        and #$0F
        sta VWrdCamPY

    A8Zero
    rts
.endproc

;; [inputs] ?
;; [outputs] ?
;; [kills] ?
;; [noreturn]
.proc ModePfMainLoop
MainLoopWait:
    ; === during vblank ===
    jsr RenderMap
    ; jsr RenderSprites
    jsr RenderSceneTransition
    ; jsr RenderHud

    ; === during screen time ===
    jsr UpdateInput
    ; jsr UpdateSpritesBeforeCam
    jsr DebugCamera
    jsr UpdateCamera
    ; jsr UpdateSpritesAfterCam

    ; wait for next frame
    stz VFrameReady
    :
        lda VFrameReady
    beq :-

    jmp ModePfMainLoop
.endproc