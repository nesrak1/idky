.p816
.i16
.a8

.include "vn_text.inc"

.include "variables.inc"

.include "wf_input.inc"
.include "wf_macros.inc"
.include "wf_regs.inc"
.include "wf_video.inc"

.include "main_vn.inc"
.include "all_assets.inc"

.segment "MODEVN_CODE"

; 26 tiles wide, 6 tiles tall
; because we don't have enough contiguous memory remaining, we have to fit this into the unused tilemap data
; 
; row 1 vram tile addresses
; | 0060 | 0070 | 0080 | 0090 |   | 00A0 | 00B0 | 00C0 | 00D0 |   | 00E0 | 00F0 | 0100 | 0110 |   | 0120 | 0130 | 0140 | 0150 |   | 0160 | 0170 | 0180 | 0190 |   | 01A0 | 01B0 | 01C0 | 01D0 |   | 01E0 | 01F0 |
; | 0068 | 0078 | 0088 | 0098 |   | 00A8 | 00B8 | 00C8 | 00D8 |   | 00E8 | 00F8 | 0108 | 0118 |   | 0128 | 0138 | 0148 | 0158 |   | 0168 | 0178 | 0188 | 0198 |   | 01A8 | 01B8 | 01C8 | 01D8 |   | 01E8 | 01F8 |
; row 2 vram tile addresses
; | 0200 | 0210 | 0220 | 0230 |   | 0240 | 0250 | 0260 | 0270 |   | 0280 | 0290 | 02A0 | 02B0 |   | 02C0 | 02D0 | 02E0 | 02F0 |   | 0300 | 0310 | 0320 | 0330 |   | 0340 | 0350 | 0360 | 0370 |   | 0380 | 0390 |
; | 0208 | 0218 | 0228 | 0238 |   | 0248 | 0258 | 0268 | 0278 |   | 0288 | 0298 | 02A8 | 02B8 |   | 02C8 | 02D8 | 02E8 | 02F8 |   | 0308 | 0318 | 0328 | 0338 |   | 0348 | 0358 | 0368 | 0378 |   | 0388 | 0398 |
; row 3 vram tile addresses
; | 03A0 | 03B0 | 03C0 | 03D0 |   | 03E0 | 03F0 # 0780 | 0790 |   | 07A0 | 07B0 | 07C0 | 07D0 |   | 07E0 | 07F0 # 0B80 | 0B90 |   | 0BA0 | 0BB0 | 0BC0 | 0BD0 |   | 0BE0 | 0BF0 # 0F80 | 0F90 |   | 0FA0 | 0FB0 |
; | 03A8 | 03B8 | 03C8 | 03D8 |   | 03E8 | 03F8 | 0788 | 0798 |   | 07A8 | 07B8 | 07C8 | 07D8 |   | 07E8 | 07F8 | 0B88 | 0B98 |   | 0BA8 | 0BB8 | 0BC8 | 0BD8 |   | 0BE8 | 0BF8 | 0F88 | 0F98 |   | 0FA8 | 0FB8 |
; 
; row 1 vram tile indices
; | 0012 | 0014 | 0016 | 0018 |   | 0020 | 0022 | 0024 | 0026 |   | 0028 | 0030 | 0032 | 0034 |   | 0036 | 0038 | 0040 | 0042 |   | 0044 | 0046 | 0048 | 0050 |   | 0052 | 0054 | 0056 | 0058 |   | 0060 | 0062 |
; | 0013 | 0015 | 0017 | 0019 |   | 0021 | 0023 | 0025 | 0027 |   | 0029 | 0031 | 0033 | 0035 |   | 0037 | 0039 | 0041 | 0043 |   | 0045 | 0047 | 0049 | 0051 |   | 0053 | 0055 | 0057 | 0059 |   | 0061 | 0063 |
; row 2 vram tile indices
; | 0064 | 0066 | 0068 | 0070 |   | 0072 | 0074 | 0076 | 0078 |   | 0080 | 0082 | 0084 | 0086 |   | 0088 | 0090 | 0092 | 0094 |   | 0096 | 0098 | 0100 | 0102 |   | 0104 | 0106 | 0108 | 0110 |   | 0112 | 0114 |
; | 0065 | 0067 | 0069 | 0071 |   | 0073 | 0075 | 0077 | 0079 |   | 0081 | 0083 | 0085 | 0087 |   | 0089 | 0091 | 0093 | 0095 |   | 0097 | 0099 | 0101 | 0103 |   | 0105 | 0107 | 0109 | 0111 |   | 0113 | 0115 |
; row 3 vram tile indices
; | 0116 | 0118 | 0120 | 0122 |   | 0124 | 0126 # 0240 | 0242 |   | 0244 | 0246 | 0248 | 0250 |   | 0252 | 0254 # 0368 | 0370 |   | 0372 | 0374 | 0376 | 0378 |   | 0380 | 0382 # 0496 | 0498 |   | 0500 | 0502 |
; | 0117 | 0119 | 0121 | 0123 |   | 0125 | 0127 | 0241 | 0243 |   | 0245 | 0247 | 0249 | 0251 |   | 0253 | 0255 | 0369 | 0371 |   | 0373 | 0375 | 0377 | 0379 |   | 0381 | 0383 | 0497 | 0499 |   | 0501 | 0503 |

; please don't read further than this table!
; only use this in VN mode, for all other uses please see
; AltChatTopTileTable
VnChatTopTileTable:
    .word $340C, $340E, $3410, $3412, $3414, $3416, $3418, $341A
    .word $341C, $341E, $3420, $3422, $3424, $3426, $3428, $342A
    .word $342C, $342E, $3430, $3432, $3434, $3436, $3438, $343A
    .word $343C, $343E, $3440, $3442, $3444, $3446, $3448, $344A
    .word $344C, $344E, $3450, $3452, $3454, $3456, $3458, $345A
    .word $345C, $345E, $3460, $3462, $3464, $3466, $3468, $346A
    .word $346C, $346E, $3470, $3472, $3474, $3476, $3478, $347A
    .word $347C, $347E, $34F0, $34F2, $34F4, $34F6, $34F8, $34FA
    .word $34FC, $34FE, $3570, $3572, $3574, $3576, $3578, $357A
    .word $357C, $357E, $35F0, $35F2, $35F4, $35F6

AltChatTopTileTable:
    .word $0000
    ; todo: should be a linear list of tiles but we still need to decide
    ; what the memory maps of the other scenes/modes should look like

;; [inputs] ?
;; [outputs] ?
;; [kills] ?
.proc VnChatNextChar
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X
;; [desc] reset BG3 entirely
.proc VnChatResetBg3
    ; clear all tiles
    stz VMADDH
    ldx #CVramBg3Map
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $800

    ; copy bg palette data to palette 1, 1
    WfvPal4Addr 5
    WfvPalLoad AUiChatboxText_Palette_P, $08

    ; clear bg3 tiles
    stz VMADDH
    ldx #(CVramBg3Tiles + $60)
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $740
    ;
    ldx #(CVramBg3Tiles + $780)
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $100
    ;
    ldx #(CVramBg3Tiles + $B80)
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $100
    ;
    ldx #(CVramBg3Tiles + $F80)
    stx VMADDL
    WfvDmaMemsetTwoReg VMDATAL, VZero, $100

    ; move BG3 down one pixel
    lda #$FF
    sta BG3VOFS
    sta BG3VOFS

    rts
.endproc

.proc VnChatResetLine
    A16
        ; this is a lot of stzs ...
        .repeat 16, I
            stz VMsgWords + (I << 1)
        .endrep

        stz VMsgTileByteOff
        stz VMsgBitOff ; + VMsgTilesReady
    A8Zero

    stz WMADDH
    ldx #.loword(VMsgBuffer)
    stx WMADDL
    WfvDmaMemsetOneReg WMDATA, VnZero, 832

    rts
.endproc

;; [inputs] VScb0: tileStartX, VScb1: tileStartY, VScb2: tileWidthX, VScb3: tileWidthY
;; [outputs] none
;; [kills] A, X, Y, VScb2
;; [desc] setup text for drawing at location.
;;        VScb0 and VScb1 must be set to the starting tile position.
;;        VScb2 and VScb3 must be set to the tile width and (height / 2).
;;        it is suggested that you call this on one frame and ChatDraw on the next.
.proc VnChatDrawSetup
    curTileIdx = VScw0
    srcVramAddr = VScw1
    rowIdx = VScw2
    tableOff = VScw3
    tileWidthXWord = VScw4
    tileStartX = VScb0
    tileStartY = VScb1
    tileWidthX = VScb2
    tileWidthY = VScb3
    mustFinishNow = VScb4
    
MakeVramStartAddr:
    XY8
    A16

    ; a = (0xc00 + tileStartY * 0x20 + tileStartX)
    lda tileStartY
    and #$FF
    ; hack so we can have a read tileStartX as a 16-bit number
    ldx #0
    stx tileStartY
    ;
    mul32
    add #CVramBg3Map
    add tileStartX
    sta VMADDL
    sta srcVramAddr

    ; todo: should be configurable for other modes
    ; since we only have VN, we are only supporting starting at VnChatTopTileTable
    stz tableOff

    ; tableOff = (unsigned short)tileWidthY
    ldx tileWidthY
    txa
    sta rowIdx

    ; tileWidthXWord = (unsigned short)tileWidthX
    ldx tileWidthX
    txa
    sta tileWidthXWord

SetupTilemapIndices:
    XY16
    SetTileRowLoop:
        ; row of top tiles
        ldy tableOff
        ldx tileWidthXWord
        SetTileLoopTop:
            ; *VMDATA = VnChatTopTileTable[tableOff += 2]
            lda VnChatTopTileTable, Y
            sta VMDATAL

            iny
            iny
            dex
        bne SetTileLoopTop

        ; srcVramAddr += 0x20; VMADD = srcVramAddr
        lda srcVramAddr
        add #$20
        sta VMADDL
        sta srcVramAddr

        ; row of bottom tiles
        ldy tableOff
        ldx tileWidthXWord
        SetTileLoopBottom:
            ; *VMDATA = VnChatTopTileTable[tableOff += 2] + 1
            lda VnChatTopTileTable, Y
            inc
            sta VMDATAL

            iny
            iny
            dex
        bne SetTileLoopBottom

        ; srcVramAddr += 0x20; VMADD = srcVramAddr
        lda srcVramAddr
        add #$20
        sta VMADDL
        sta srcVramAddr

        tya
        sta tableOff

        dec rowIdx
    bne SetTileRowLoop

FinishUp:
    A8Zero

    stz VMsgTileMode
    jsr VnChatResetLine

    rts
.endproc

;; [inputs] A: chrIndex, VScb0: mustBeReady
;; [outputs] none
;; [kills] A, X, Y
;; [desc] draws single chatbox character. make sure B register is zero!
;;        if mustBeReady is set, this function temporarily "finishes" the last tile.
;;        use mustBeReady when writing a tile per frame or when writing a series
;;        of letters and this is the last one.
.proc VnChatDraw
    mustBeReady = VScb0
    charChrOffset = VScw0
    charChrIndex = VScw1

    sta charChrIndex
    stz charChrIndex+1

    ; charChrOffset = (charChrIndex * 11) + 7
    lda #11
    sta WRMPYA
    lda charChrIndex ; due to optos, 11 needs to be in WRMPYA
    sta WRMPYB
    ; to be continued ...

    ; continue charChrOffset = (charChrIndex * 11) + (11 - 1)
    A16
    lda #(11 - 1)
    add RDMPYL
    sta charChrOffset

    ldy #((11 - 1) * 2) ; row

    ldx charChrOffset
    LoopShiftInPixels:
        ; a = (AText_Strips[charChrOffset--] << 8) & 0xff00
        ldx charChrOffset
        lda AText_Strips-1, X
        and #$FF00

        dex
        stx charChrOffset

        XY8
        ; a >>= VMsgBitOff
        ;
        ldx VMsgBitOff
        LoopShiftCharBits:
            beq :+
            lsr
            dex
        bra LoopShiftCharBits
        :

        ; VMsgWords[row] |= a
        ora VMsgWords, Y
        sta VMsgWords, Y

        dey ; row
        dey
        XY16
    bpl LoopShiftInPixels

    A8Zero

    ; VMsgBitOff += AText_Widths[charChrIndex] + 1
    ldy charChrIndex
    lda AText_Widths, Y
    inc
    add VMsgBitOff
    sta VMsgBitOff

    ; write this tile (and the next if bitoff is > 0)
    jsr VnChatDrawWriteTile

    ; if (VMsgBitOff > 0 && mustBeReady)
    lda VMsgBitOff
    beq ChatDrawWriteNextTileFalse
        lda mustBeReady
        beq MustBeReadyFalse
            ; write next tile (otherwise the current working
            ; character will be unfinished)
            jsr VnChatDrawWriteTileNext
        MustBeReadyFalse:
    ChatDrawWriteNextTileFalse:

    ; finish current tile if it's ready
    ; todo: move check to this function?
    jsr VnChatDrawFinishTile

    XY16
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] copy tile data from VMsgWords to VMsgBuffer in the right spot
.proc VnChatDrawWriteTile
CopyNormalPixels:
    XY16
    ; offset because the most significant byte is the working byte
    ; the least significant byte has overflow (will shift into msb later)
    ldy #((11 - 1) * 2 + 1) ; row

    A16
        lda VMsgTileByteOff
        add #((11 - 1) * 2)
        tax ; nrmOff
    A8

    LoadNormalLoop:
        ; msg_buffer[nrmOff] = msg_words[row]
        lda VMsgWords, Y
        sta VMsgBuffer, X

        dex ; nrmOff
        dex
        dey ; row
        dey
    bpl LoadNormalLoop

CopyShadowPixels:
    ldy #((11 - 1) * 2 + 1) ; row

    A16
        ; +3 offset is the next row down (2 bytes) + the offset to shadow byte (1 byte)
        lda VMsgTileByteOff
        add #((3 + (11 - 1) * 2))
        tax ; shdOff
    A8Zero

    LoopLoadShadow:
        ; a = msg_words[row] >> 1, c = msg_words[row] & 1
        lda VMsgWords, Y
        lsr ; a stores tile, c stores shifted off bit (to copy to right neighbor tile)

        ; msg_buffer[shdOff] |= a
        ora VMsgBuffer, X
        sta VMsgBuffer, X

        ; store overflow shadow bit into tile to the right of us
        ; a = c << 7
        ; msg_buffer[32 + shdOff] = a
        lda #0
        ror
        sta VMsgBuffer+32, X

        dex ; shdOff
        dex
        dey ; row
        dey
    bpl LoopLoadShadow
    
ChatDrawWriteTileReady:
    lda #1
    sta VMsgTilesReady

    lda #0
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] same as VnChatDrawWriteTile, but for the next partial tile
;;        (this subtracts 1 from `row` and adds 32 to `nrmOff`)
.proc VnChatDrawWriteTileNext
CopyNormalPixels:
    XY16
    ldy #((11 - 1) * 2) ; row

    A16
        lda VMsgTileByteOff
        add #((11 - 1) * 2 + 32)
        tax ; nrmOff
    A8

    LoadNormalLoop:
        ; msg_buffer[nrmOff] = msg_words[row]
        lda VMsgWords, Y
        sta VMsgBuffer, X

        dex ; nrmOff
        dex
        dey ; row
        dey
    bpl LoadNormalLoop

CopyShadowPixels:
    ldy #((11 - 1) * 2) ; row

    A16
        ; +3 offset is the next row down (2 bytes) + the offset to shadow byte (1 byte)
        lda VMsgTileByteOff
        add #(3 + (11 - 1) * 2 + 32)
        tax ; shdOff
    A8Zero

    LoopLoadShadow:
        ; a = msg_words[row] >> 1, c = msg_words[row] & 1
        lda VMsgWords, Y
        lsr ; a stores tile, c stores shifted off bit (to copy to right neighbor tile)

        ; msg_buffer[shdOff] |= a
        ora VMsgBuffer, X
        sta VMsgBuffer, X

        ; store overflow shadow bit into tile to the right of us
        ; a = c << 7
        ; msg_buffer[32 + shdOff] = a
        lda #0
        ror
        sta VMsgBuffer+32, X

        dex ; shdOff
        dex
        dey ; row
        dey
    bpl LoopLoadShadow
    
ChatDrawWriteTileReady:
    lda #1
    sta VMsgTilesReady

    lda #0
    rts
.endproc

.proc VnChatDrawFinishTile
    XY8

ShiftWordBits:
    ; if (VMsgBitOff >= 8)
    lda VMsgBitOff
    cmp #8
    blt NotBitOffTooLarge
        A16
        
        ; VMsgTileByteOff += 32
        lda VMsgTileByteOff
        add #32
        sta VMsgTileByteOff

        A8Zero

        ; VMsgBitOff -= 8
        lda VMsgBitOff
        sub #8
        sta VMsgBitOff

        ldx #((11 - 1) * 2) ; row
        LoopShiftWord:
            lda VMsgWords, X
            sta VMsgWords+1, X
            stz VMsgWords, X

            dex ; row
            dex
        bpl LoopShiftWord
    NotBitOffTooLarge:

    lda #0
    XY16
    rts
.endproc

VnChatCopyTilesToVram_JT:
    .addr VnChatCopyTilesToVram_VnTop
    .addr VnChatCopyTilesToVram_VnMiddle
    .addr VnChatCopyTilesToVram_VnBottom

.proc VnChatCopyTilesToVram
    lda VMsgTileMode
    shl
    tax
    jmp (VnChatCopyTilesToVram_JT, X)
.endproc

.proc VnChatCopyTilesToVram_VnTop
    ldx #(CVramBg3Tiles + $60)
    stx VMADDL
    WfvDmaCopyTwoReg VMDATAL, VMsgBuffer, 832

    stz VMsgTilesReady
    rts
.endproc

.proc VnChatCopyTilesToVram_VnMiddle
    ldx #(CVramBg3Tiles + $200)
    stx VMADDL
    WfvDmaCopyTwoReg VMDATAL, VMsgBuffer, 832

    stz VMsgTilesReady
    rts
.endproc

.proc VnChatCopyTilesToVram_VnBottom
    ldx #(CVramBg3Tiles + $3A0)
    stx VMADDL
    WfvDmaCopyTwoReg VMDATAL, VMsgBuffer, 192

    ldx #(CVramBg3Tiles + $780)
    stx VMADDL
    WfvDmaCopyTwoReg VMDATAL, (VMsgBuffer + 192), 256

    ldx #(CVramBg3Tiles + $B80)
    stx VMADDL
    WfvDmaCopyTwoReg VMDATAL, (VMsgBuffer + 448), 256

    ; yoda: there is another
    ; me: ok, I don't care right now goodbye

    stz VMsgTilesReady
    rts
.endproc