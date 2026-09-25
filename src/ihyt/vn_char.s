.p816
.i16
.a8

.include "vn_char.inc"

.include "variables.inc"

.include "wf_input.inc"
.include "wf_macros.inc"
.include "wf_regs.inc"
.include "wf_video.inc"

.include "all_assets.inc"

.segment "MODEVN_CODE"

VnCharResetWord:
    .word $E0E0

.proc VnCharReset
    ; TCharData is 22 bytes which is only 11 stzs
    ; I don't think we need to bother with DMA here
    A16
    .repeat 11, I
        stz VCharData + (I << 1)
    .endrep
    A8

    ; clear OAM
    stz WMADDH
    ldx #.loword(VSprLo)
    stx WMADDL
    WfvDmaMemsetOneReg WMDATA, VnCharResetWord, $220

    rts
.endproc

;; [input] A: char_idx
.proc VnCharAdd
    ; todo: while this function is currently used for testing,
    ; it really should show a single, specific character on screen
    WfvScreenHide ; obviously this takes too long to do in a single vblank, but this is just a test

    WfvPal16Addr 8
    WfvPalLoad AChrLucy_Palette_P, 16*2

    ; char 1 test
    WfvBgAddr $4200
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $4800
    WfvBgLoad AChrLucy_SmileTL_T, (AChrLucy_SmileTL_TE - AChrLucy_SmileTL_T)
    WfvBgAddr $4C00
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)
    ;
    WfvBgAddr $6200
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $6800
    WfvBgLoad AChrLucy_SmileBL_T, (AChrLucy_SmileBL_TE - AChrLucy_SmileBL_T)
    WfvBgAddr $6C00
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)

    ; char 2 test
    WfvBgAddr $4400
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $5000
    WfvBgLoad AChrLucy_SmileTL_T, (AChrLucy_SmileTL_TE - AChrLucy_SmileTL_T)
    WfvBgAddr $5400
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)
    ;
    WfvBgAddr $6400
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $7000
    WfvBgLoad AChrLucy_SmileBL_T, (AChrLucy_SmileBL_TE - AChrLucy_SmileBL_T)
    WfvBgAddr $7400
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)

    ; char 3 test
    WfvBgAddr $4600
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $5800
    WfvBgLoad AChrLucy_SmileTL_T, (AChrLucy_SmileTL_TE - AChrLucy_SmileTL_T)
    WfvBgAddr $5C00
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)
    ;
    WfvBgAddr $6600
    WfvBgLoad AChrLucy_SmileAS_T, (AChrLucy_SmileAS_TE - AChrLucy_SmileAS_T)
    WfvBgAddr $7800
    WfvBgLoad AChrLucy_SmileBL_T, (AChrLucy_SmileBL_TE - AChrLucy_SmileBL_T)
    WfvBgAddr $7C00
    WfvBgLoad AChrLucy_SmileML_T, (AChrLucy_SmileML_TE - AChrLucy_SmileML_T)

    ; set char 1 data
    A16
    stz VCharData + TCharData::cx + 0
    lda #40
    sta VCharData + TCharData::cy + 0
    A8Zero
    ;
    stz VCharData + TCharData::cgram_pal + 0
    lda #%11000000
    sta VCharData + TCharData::var_flags + 0
    stz VCharData + TCharData::vram_idx + 0
    stz VCharData + TCharData::tab_off_div8 + 0

    ; set char 2 data
    A16
    stz VCharData + TCharData::cx + 2
    lda #40
    sta VCharData + TCharData::cy + 2
    A8Zero
    ;
    stz VCharData + TCharData::cgram_pal + 1
    lda #%11000000
    sta VCharData + TCharData::var_flags + 1
    lda #1
    sta VCharData + TCharData::vram_idx + 1
    stz VCharData + TCharData::tab_off_div8 + 1

    ; set char 3 data
    A16
    lda #160
    sta VCharData + TCharData::cx + 4
    lda #40
    sta VCharData + TCharData::cy + 4
    A8Zero
    ;
    stz VCharData + TCharData::cgram_pal + 2
    lda #%11000000
    sta VCharData + TCharData::var_flags + 2
    lda #1
    sta VCharData + TCharData::vram_idx + 2
    stz VCharData + TCharData::tab_off_div8 + 2
    
    WfvScreenShow
    rts
.endproc

;; [assume] A8, XY16, DPNZ
.proc VnPushSpriteLarge
    .import VnPushSpriteLargeRet
    baseX = VScw0
    baseY = VScw1
    savedSp = VScw2
    spriteTableIdx = VScw3
    charIdx = VScw4
    spriteIdx = VScb0
    spriteTileOff = VScb1
    spriteLargeTileIdx = VScb2
    spriteLargeProps = VScb3

    A16
    ; push X + baseX to XXXX-XXXX
    txa
    add a:baseX
    A8
    pha

    ; add X high bit and size (fixed as sec) to high oam
    xba
    lsr
    ror z:$00
    sec
    ror z:$00

    ; A16
    ; push Y + baseY to YYYY-YYYY
    tya
    add a:baseY
    ; A8
    pha

    ; push spriteTileIdx to TTTT-TTTT
    lda a:spriteLargeTileIdx
    add a:spriteTileOff
    pha

    ; push spriteProps to VHPP-CCCt
    lda a:spriteLargeProps
    pha

    ; check if ((spriteIdx++) & 3) == 0
    lda a:spriteIdx
    inc
    sta a:spriteIdx
    and #3
    bne NotEqThree
        ; DP++
        tdc
        inc
        tcd
    NotEqThree:

    AZeroUpperSafe
    jmp VnPushSpriteLargeRet
.endproc

;; [assume] A8, XY16, DPNZ
.proc VnPushSpriteSmall
    .import VnPushSpriteSmallRet
    baseX = VScw0
    baseY = VScw1
    savedSp = VScw2
    spriteTableIdx = VScw3
    charIdx = VScw4
    spriteIdx = VScb0
    spriteTileOff = VScb1
    spriteSmallTileIdx = VScb4
    spriteSmallProps = VScb5

    A16
    ; push X + baseX to XXXX-XXXX
    txa
    add a:baseX
    A8
    pha

    ; add X high bit and size (fixed as clc) to high oam
    xba
    lsr
    ror z:$00
    clc
    ror z:$00

    ; A16
    ; push Y + baseY to YYYY-YYYY
    tya
    add a:baseY
    ; A8
    pha

    ; push spriteTileIdx to TTTT-TTTT
    lda a:spriteSmallTileIdx
    add a:spriteTileOff
    pha

    ; push spriteProps to VHPP-CCCt
    lda a:spriteSmallProps
    pha

    ; check if ((spriteIdx++) & 3) == 0
    lda a:spriteIdx
    inc
    sta a:spriteIdx
    and #3
    bne NotEqThree
        ; DP++
        tdc
        inc
        tcd
    NotEqThree:

    AZeroUpperSafe
    jmp VnPushSpriteSmallRet
.endproc

; I'm not convinced using DP/SP like this saves us any time
; but... it works right now. maybe let's not touch it until
; performance is actually a problem.
.proc VnCharUpdate
    .export VnPushSpriteLargeRet
    .export VnPushSpriteSmallRet
    baseX = VScw0
    baseY = VScw1
    savedSp = VScw2
    spriteTableIdx = VScw3
    charIdx = VScw4
    spriteIdx = VScb0
    spriteTileOff = VScb1
    spriteLargeTileIdx = VScb2
    spriteLargeProps = VScb3
    spriteSmallTileIdx = VScb4
    spriteSmallProps = VScb5

    ; clear high oam
    A16
    
    ; DP = VSprHi
    lda #.loword(VSprHi)
    tcd

    ;; [assume] DPNZ

    ; savedSp = SP
    sei ; disable interrupts (since we're touching SP)
    tsc
    sta a:savedSp
    
    ; SP = VSprLo + (TCharDataMax * 4) - 1
    lda #(.loword(VSprLo) + 511)
    tcs

    stz a:charIdx

    stz a:spriteIdx ; a:spriteTileOff
    A8ZeroSafe

    LoopSpriteIterate:
        ; === character sprite setup ===

        ldx a:charIdx
    
        ; if (VCharData[charIdx].var_flags & TCharDataFlActive) == 0
        bit a:VCharData + TCharData::var_flags, X
        bvs NotLoopSpriteIterateCont
            ; needed because one byte signed jump too far
            ; probably could be inlined
            jmp LoopSpriteIterateCont
        NotLoopSpriteIterateCont:

        ; X <<= 1 (for cx/cy indexing)
        txa
        asl
        tax

        ; baseX = VCharData[charIdx].cx
        ; baseY = VCharData[charIdx].cy
        ldy a:VCharData + TCharData::cx, X
        sty a:baseX
        ldy a:VCharData + TCharData::cy, X
        sty a:baseY

        ; restore X
        ldx a:charIdx

        ; spriteLargeTileIdx = [0x80, 0x00, 0x80][vram_idx]
        ; doing the bit magic instead of a lookup table because
        ; it takes too much time to drop the upper part of the
        ; vram_idx from Y
        lda a:VCharData + TCharData::vram_idx, X
        inc
        lsr
        ror
        sta a:spriteLargeTileIdx

        ; spriteSmallTileIdx = [0x20, 0x40, 0x60][vram_idx]
        lda a:VCharData + TCharData::vram_idx, X
        inc
        shl5
        sta a:spriteSmallTileIdx

        lda a:VCharData + TCharData::vram_idx, X
        cmp #0
        bne NotVramIdxZero
            ; here, vram_idx == 0
            ; spriteLargeProps = (0b00100000 | (cgram_pal << 1) | 0)
            ; spriteSmallProps = (0b00100000 | (cgram_pal << 1) | 0)
            lda a:VCharData + TCharData::cgram_pal, X
            asl
            eor #%00100000
            sta a:spriteLargeProps
            sta a:spriteSmallProps
            bra EndVramIdxZero
        NotVramIdxZero:
            ; here, vram_idx == 1 || vram_idx == 2
            ; spriteLargeProps = (0b00100000 | (cgram_pal << 1) | 1)
            ; spriteSmallProps = (0b00100000 | (cgram_pal << 1) | 1)
            lda a:VCharData + TCharData::cgram_pal, X
            asl
            eor #%00100001
            sta a:spriteLargeProps
            and #%11111110
            sta a:spriteSmallProps
        EndVramIdxZero:

        ; === 16x16/32x32 sprite setup ===

        ; spriteTableIdx = VCharData[spriteIdx].tab_off_div8 << 3
        lda a:VCharData + TCharData::tab_off_div8, X
        A16
        shl3
        sta a:spriteTableIdx
        tax
        A8ZeroSafe

        ; === 16x16/32x32 sprite loop ===
        SpritePushLoop:
            lda a:AChrAll_MetaTable + 2, X

            ; if AChrAll_MetaTable[spriteTableIdx].2 == 0xff, break
            cmp #$FF
            beq SpritePushLoopBreak

            ; if (AChrAll_MetaTable[spriteTableIdx].2 & 0x80) == 0
            bit #$80
            bne SpritePushLarge
                ; spriteTileOff &= 0x7f
                and #$7F
                sta a:spriteTileOff

                ; todo: we have baseX/baseY here. can we just add them
                ; while we have it loaded?

                ; Y = AChrAll_MetaTable[spriteTableIdx].1
                lda a:AChrAll_MetaTable + 1, X
                tay

                ; X = AChrAll_MetaTable[spriteTableIdx].0
                lda a:AChrAll_MetaTable + 0, X
                tax

                ; VnPushSpriteSmall(X, Y, spriteTileOff)
                jmp VnPushSpriteSmall
            SpritePushLarge:
                ; spriteTileOff &= 0x7f
                and #$7F
                sta a:spriteTileOff

                ; Y = AChrAll_MetaTable[spriteTableIdx].1
                lda a:AChrAll_MetaTable + 1, X
                tay

                ; X = AChrAll_MetaTable[spriteTableIdx].0
                lda a:AChrAll_MetaTable + 0, X
                tax

                ; VnPushSpriteLarge(X, Y, spriteTileOff)
                jmp VnPushSpriteLarge
            EndSpritePushLarge:
            VnPushSpriteSmallRet:
            VnPushSpriteLargeRet:
            
            ; spriteTableIdx += 3
            ldx a:spriteTableIdx
            inx
            inx
            inx
            stx a:spriteTableIdx
        bra SpritePushLoop
        SpritePushLoopBreak:

    LoopSpriteIterateCont:
        stz a:spriteTileOff

        ; charIdx++
        lda a:charIdx
        inc
        sta a:charIdx

        ; break after 3 characters
        cmp #TCharDataMax
    beq LoopSpriteIterateBreak
    jmp LoopSpriteIterate
    LoopSpriteIterateBreak:

    ; pad out the remaining sprites at ZP
    lda a:spriteIdx
    LoopPadHighOam:
        and #3
        beq EndLoopPadHighOam

        clc
        ror z:$00
        clc
        ror z:$00

        inc
        bra LoopPadHighOam
    EndLoopPadHighOam:

    ; DP = 0 (still in A8, but assuming B is clear)
    lda #0
    tcd

    ;; [assume] DPZ

    A16
    ; SP = savedSp
    lda z:savedSp
    tcs
    cli
    A8Zero
    
    rts
.endproc