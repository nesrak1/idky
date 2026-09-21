.ifndef WF_VIDEO_INC
WF_VIDEO_INC = 1

.include "wf_regs.inc"

; INTERRUPTS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
;; [desc] Setup interrupts & joystick auto-read
;;        I don't expect this config to change, so it is currently hardcoded
.macro WfvInterruptSetup
    lda #$81
    sta NMITIMEN
.endmacro

; SCREEN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
.macro WfvScreenHide
    lda #$8F
    sta INIDSP
.endmacro

;; [assume] A8, XY16
.macro WfvScreenShow
    lda #$0F
    sta INIDSP
.endmacro

;; [assume] A8, XY16
;; [desc] Control the screen brightness
;;        val - a brightness value from 0 to 15
.macro WfvScreenFade val
    lda #(val & $0F)
    sta INIDSP
.endmacro

; DMA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
;; [inputs] m0: dst, m1: src, m2: len
;; [outputs] none
;; [kills] A, X
;; [desc] Do a dma copy to one register:
;;          DMAP0 = 0
;;          DMADEST0 = dst & 0xff
;;          DMASRC0L = src & 0xffff
;;          DMASRC0B = (src >> 16) & 0xff
;;          DMALEN0L = len
;;          MDMAEN = (1 << 0)
.macro WfvDmaCopyOneReg dst, src, len
    ; transfer mode 0 = 1 register write once
    stz DMAP0

    lda #<dst
    sta DMADEST0

    ldx #.loword(src)
    stx DMASRC0L

    lda #^src
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN
.endmacro

;; [assume] A8, XY16
;; [inputs] m0: dst, m1: src_off, m2: len, Y: offset
;; [outputs] none
;; [kills] A, X
;; [desc] Do a dma copy to one register with src_off offset by Y (but not across banks)
.macro WfvDmaCopyOneRegOff dst, src_off, len
    ; transfer mode 0 = 1 register write once
    stz DMAP0

    lda #<dst
    sta DMADEST0

    A16
    lda src_off, Y
    sta DMASRC0L
    A8

    lda src_off + 2, Y
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN
.endmacro

;; [assume] A8, XY16
;; [inputs] m0: dst, m1: src, m2: len
;; [outputs] none
;; [kills] A, X
;; [desc] Do a dma copy to one register:
;;          DMAP0 = 0
;;          DMADEST0 = dst & 0xff
;;          DMASRC0L = src & 0xffff
;;          DMASRC0B = (src >> 16) & 0xff
;;          DMALEN0L = len
;;          MDMAEN = (1 << 0)
;;          todo: this should be an optional arg
.macro WfvDmaCopyOneRegRev dst, src, len
    ; transfer mode 0 = 1 register write once, decrement after copy
    lda #%00010000
    sta DMAP0

    lda #<dst
    sta DMADEST0

    ldx #.loword(src)
    stx DMASRC0L

    lda #^src
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN 
.endmacro

;; [assume] A8, XY16
;; [input] m0: dst, m1: src, m2: len
;; [kills] A, X
;; [desc] Do a dma copy to two registers:
;;          DMAP0 = 1
;;          DMADEST0 = dst & 0xff
;;          DMASRC0L = src & 0xffff
;;          DMASRC0B = (src >> 16) & 0xff
;;          DMALEN0L = len
;;          MDMAEN = (1 << 0)
;;        todo: needs extra macro to not set DMAP0 again
.macro WfvDmaCopyTwoReg dst, src, len
    ; transfer mode 1 = 2 registers write once
    lda #%00000001
    sta DMAP0

    lda #<dst
    sta DMADEST0

    ldx #.loword(src)
    stx DMASRC0L

    lda #^src
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN
.endmacro

;; [assume] A8, XY16
;; [input] m0: dst, m1: src, m2: len, Y: offset
;; [kills] A
;; [desc] Do a dma copy to two registers with src_off/len_off offset by Y (but not across banks)
.macro WfvDmaCopyTwoRegOff dst, src_off, len_off
    ; transfer mode 1 = 2 registers write once
    lda #%00000001
    sta DMAP0

    lda #<dst
    sta DMADEST0

    A16
    lda src_off, Y
    sta DMASRC0L

    lda len_off, Y
    sta DMALEN0L
    A8

    lda src_off + 2, Y
    sta DMASRC0B

    lda #%00000001
    sta MDMAEN
.endmacro


;; [assume] A8 XY16
;; [input] dst src len
;; [kills] ax
;; [desc] Do a dma set to one register:
;;          DMAP0 = 0b00001000
;;          DMADEST0 = dst & 0xff
;;          DMASRC0L = src & 0xffff
;;          DMASRC0B = (src >> 16) & 0xff
;;          DMALEN0L = len
;;          MDMAEN = (1 << 0)
;;        todo: needs extra macro to not set DMAP0 again
.macro WfvDmaMemsetOneReg dst, src, len
    ; transfer mode 0 = 1 register write once, don't move src pointer
    lda #%00001000
    sta DMAP0

    lda #<dst
    sta DMADEST0

    ldx #.loword(src)
    stx DMASRC0L

    lda #^src
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN
.endmacro

;; [assume] A8 XY16
;; [input] dst src len
;; [kills] ax
;; [desc] Do a dma set to two registers:
;;          DMAP0 = 0b00001001
;;          DMADEST0 = dst & 0xff
;;          DMASRC0L = src & 0xffff
;;          DMASRC0B = (src >> 16) & 0xff
;;          DMALEN0L = len
;;          MDMAEN = (1 << 0)
;;        todo: needs extra macro to not set DMAP0 again
.macro WfvDmaMemsetTwoReg dst, src, len
    ; transfer mode 0 = 2 register write once, don't move src pointer
    lda #%00001001
    sta DMAP0

    lda #<dst
    sta DMADEST0

    ldx #.loword(src)
    stx DMASRC0L

    lda #^src
    sta DMASRC0B

    ldx #len
    stx DMALEN0L

    lda #%00000001
    sta MDMAEN
.endmacro

; SPRITES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.scope SpriteCfgSize
    SZ_MASK        = %11100000
    SZ_8x8_16x16   = %00000000
    SZ_8x8_32x32   = %00100000
    SZ_8x8_64x64   = %01000000
    SZ_16x16_32x32 = %01100000
    SZ_16x16_64x64 = %10000000
    SZ_32x32_64x64 = %10100000
    SZ_16x32_32x64 = %11000000
    SZ_16x32_32x32 = %11100000
.endscope

.scope SpriteCfgGap
    NO_GAP = %00000000
    GP_256 = %00001000
    GP_512 = %00010000
    GP_768 = %00011000
.endscope

;; [assume] A8, XY16
.macro WfvSpriteConfig size, addr, gap
    lda #(size | gap | (addr >> 13))
    sta OBJSEL
.endmacro

; BG ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
.macro WfvBgMode mode, bg3pri, bg1_sz, bg2_sz, bg3_sz, bg4_sz
    lda #((mode & 7) | ((bg3pri & 1) << 3) | ((bg1_sz & 1) << 4) | ((bg2_sz & 1) << 5) | ((bg3_sz & 1) << 6) | ((bg4_sz & 1) << 7))
    sta BGMODE
.endmacro

;; [assume] A8, XY16
.macro WfvBgAddr addr
    ldx #addr
    stx VMADDL
.endmacro

;; [assume] A8, XY16
.macro WfvBgLoad data, size
    WfvDmaCopyTwoReg VMDATAL, data, size
.endmacro

;; [assume] A8, XY16
.macro WfvBgTilesetConfig bg1_addr, bg2_addr, bg3_addr, bg4_addr
    lda #(((bg2_addr >> 8) & %11110000) | ((bg1_addr >> 12) & %00001111))
    sta BG12NBA
    lda #(((bg4_addr >> 8) & %11110000) | ((bg3_addr >> 12) & %00001111))
    sta BG34NBA
.endmacro

;; [assume] A8, XY16
;; [input] m0: idx, m1: addr, m2: large_h, m3: large_v
;; [kills] A
;; [desc] BGnSC - BG1-4 tilemap address and size ($2107-$210A write)
;;        idx - a background index from 1 to 4
;;        addr - a VRAM (word) address with a multiple of $400
;;        large_h - 1 if two tilemaps wide, otherwise 0
;;        large_v - 1 if two tilemaps high, otherwise 0 
.macro WfvBgTilemapConfig idx, addr, large_h, large_v
    lda #(((addr >> 8) & %11111100) | (large_v << 1) | large_h)
    sta BG1SC + ((idx - 1) & 3)
.endmacro

; PALETTE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
;; [desc] Load a 16-color palette from ROM into VRAM
;;        pal - the palette data to use
;;        size - the size of the palette data
.macro WfvPalLoad pal, size
    WfvDmaCopyOneReg CGDATA, pal, size
.endmacro

;; [assume] A8, XY16
;; [desc] Set the palette index in multiples of 4 (for 4-color palettes)
;;        idx - a palette row from 0 to 3
.macro WfvPal4Addr idx
    lda #(idx << 2)
    sta CGADD
.endmacro

;; [assume] A8, XY16
;; [desc] Set the palette index in multiples of 16 (for 16-color palettes)
;;        idx - a palette row from 0 to 15
.macro WfvPal16Addr idx
    lda #(idx << 4)
    sta CGADD
.endmacro

.endif ; WF_VIDEO_INC
