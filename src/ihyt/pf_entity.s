.p816
.i16
.a8

.include "pf_entity.inc"

.include "variables.inc"

.include "wf_input.inc"
.include "wf_macros.inc"
.include "wf_regs.inc"
.include "wf_video.inc"

.include "main_pf.inc"

.segment "MODEPF_CODE"

;

; SPRITE UPDATE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

UpdatePlayer_GrabJumpTableVx:
    .byte $FF, $01
    .byte $FF, $01
    .byte $FF, $01
    .byte $FE, $02
    .byte $FE, $02
    .byte $FE, $02
    .byte $FE, $02
    .byte $FE, $02
    .byte $FE, $02
    .byte $FD, $03
    .byte $FD, $03
UpdatePlayer_GrabJumpTableVy:
    .byte $FF, $FF
    .byte $FF, $FF
    .byte $FF, $FF
    .byte $FE, $FE
    .byte $FE, $FE
    .byte $FE, $FE
    .byte $FE, $FE
    .byte $FE, $FE
    .byte $FE, $FE
    .byte $FD, $FD
    .byte $FD, $FD

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [inlined]
.proc UpdatePlayer
    tmp = VScw0
    allowHMove = VScb0

    MoveSpeed = 400
    FrictionSpeed = 25
    GravitySpeed = 25
    JumpSpeed = 600
    TerminalSpeed = 800
    MaxJumpTime = 20
    MaxHopTime = 20

    UpdatePlayerInput:

        ; disable input when pri flag set
        lda VPlyData + TPlyData::fl_pri
        beq PriSetFalse
            jmp HorizontalMovement
        PriSetFalse:

        ; handle hop velocity
        lda VPlyData + TPlyData::hoptime
        beq IsHoppingFalse
            dec
            sta VPlyData + TPlyData::hoptime
            div2
            mul2

            add VPlyData + TPlyData::hopdir
            ldx #0
            tax

            ; pv# = UpdatePlayer_GrabJumpTableV#[(hoptime << 1) | hopdir] << 8

            lda UpdatePlayer_GrabJumpTableVx, X
            sta VPlyData + TPlyData::pvx+1
            stz VPlyData + TPlyData::pvx
            
            lda UpdatePlayer_GrabJumpTableVy, X
            sta VPlyData + TPlyData::pvy+1
            stz VPlyData + TPlyData::pvy
            
            ; lda VPad1Val+1
            ; bit #(JOY_RIGHT>>8)
            ; beq IsRightHopFalse
            ;     A16
            ;     lda VPlyData + TPlyData::pvx
            ;     add #(MoveSpeed*3)
            ;     sta VPlyData + TPlyData::pvx
            ;     A8
            ; IsRightHopFalse:
            
            ; lda VPad1Val+1
            ; bit #(JOY_LEFT>>8)
            ; beq IsLeftHopFalse
            ;     A16
            ;     lda VPlyData + TPlyData::pvx
            ;     sub #(MoveSpeed*3)
            ;     sta VPlyData + TPlyData::pvx
            ;     A8
            ; IsLeftHopFalse:

            ; skip all other inputs
            jmp LeftRightMovement
        IsHoppingFalse:

        ; note: we punish player for holding R by disabling left/right movement
        ; however, we give the player a window while hop is happening
        lda #1
        sta allowHMove
        ;
        lda VPad1Val
        bit #JOY_R
        beq IsRFalse
            stz allowHMove
        IsRFalse:

        lda VPlyData + TPlyData::grab
        beq IsGrabFalse
        ;
        lda VPad1Val
        bit #JOY_R
        beq IsRGrabFalse
            ldx VPlyData + TPlyData::stamina
            beq IsRGrabFalse ; drop character if we're out of stamina
            dex
            stx VPlyData + TPlyData::stamina

            ldx #($10000-GravitySpeed)
            stx VPlyData + TPlyData::pvy

            lda VPlyData + TPlyData::grab
            sta VPlyData + TPlyData::oldgrab

            ; OK to move if we're grabbing + on wall
            lda #1
            sta allowHMove

            ; skip jumping if we're holding
            jmp LeftRightMovement
        IsGrabFalse:
            ; hop player if we just let go of grab
            lda VPlyData + TPlyData::oldgrab
            beq IsRGrabFalse

            dec
            sta VPlyData + TPlyData::hopdir

            lda #MaxHopTime
            sta VPlyData + TPlyData::hoptime

            stz VPlyData + TPlyData::jmptime
            stz VPlyData + TPlyData::jmpcnt

            stz VPlyData + TPlyData::oldgrab

            A16
            lda VPlyData + TPlyData::stamina
            
            sub #32
            cmp #($FFFF-32)
            blt HopStaminaCapZeroFalse
                lda #0
            HopStaminaCapZeroFalse:

            sta VPlyData + TPlyData::stamina
            A8

            jmp LeftRightMovement
        IsRGrabFalse:
        
        stz VPlyData + TPlyData::oldgrab

        lda VPad1Val
        bit #JOY_A
        beq IsAFalse
        ; must have started a jump
        lda VPlyData + TPlyData::jmpcnt
        ;
        ; to only allow larger jumps on first jump:
        cmp #1
        bne IsAFalse
        ; to allow larger jumps on any jump: (currently broken due to this allowing 3rd hops)
        ; beq IsAFalse
        ;
        ; must still have jump time left
        lda VPlyData + TPlyData::jmptime
        cmp #MaxJumpTime
        bge IsAFalse
            inc
            sta VPlyData + TPlyData::jmptime

            ldx #($10000-JumpSpeed)
            stx VPlyData + TPlyData::pvy
        IsAFalse:

        ; initial jump handling
        lda VPad1Fir
        bit #JOY_A
        beq IsFirstAFalse
        ;
        lda VPlyData + TPlyData::jmpcnt
        cmp #2
        bge IsFirstAFalse
            inc
            sta VPlyData + TPlyData::jmpcnt
            stz VPlyData + TPlyData::jmptime

            ldx #($10000-JumpSpeed)
            stx VPlyData + TPlyData::pvy
        IsFirstAFalse:

    LeftRightMovement:
        ; move player left/right
        lda VPad1Val+1
        bit #(JOY_RIGHT>>8)
        beq IsRightFalse
            ldx #MoveSpeed
            stx VPlyData + TPlyData::pvx

            lda #1
            sta VPlyData + TPlyData::dir
        IsRightFalse:

        lda VPad1Val+1
        bit #(JOY_LEFT>>8)
        beq IsLeftFalse
            ldx #($10000-MoveSpeed)
            stx VPlyData + TPlyData::pvx

            lda #0 ; not using stz for consistency
            sta VPlyData + TPlyData::dir
        IsLeftFalse:

        lda allowHMove
        bne AllowedHMove
            A16
            lda VPlyData + TPlyData::pvx
            div2signed
            sta VPlyData + TPlyData::pvx
            A8
        AllowedHMove:

    HorizontalMovement:
        A16

        lda VPlyData + TPlyData::pvx
        beq XFrictionFinish

        cmp #$8000
        blt IsXNegativeFalse
            ; A = (A < -FrictionSpeed) ? (A + FrictionSpeed) ? 0
            cmp #($10000-FrictionSpeed)
            blt :+
                lda #0
                bra :++
            :
                add #FrictionSpeed
            :
            bra XFrictionFinish
        IsXNegativeFalse:
            ; A = (A > FrictionSpeed) ? (A - FrictionSpeed) ? 0
            cmp #(FrictionSpeed+1)
            bge :+
                lda #0
                bra :++
            :
                sub #FrictionSpeed
            :
        XFrictionFinish:
        sta VPlyData + TPlyData::pvx

        ; VPlyData.px += VPlyData.pvx.hibyte
        add VPlyData + TPlyData::pfx
        sta VPlyData + TPlyData::pfx
        ;
        A8
        lda VPlyData + TPlyData::pvx+1
        bpl XVelocityPositive
            lda VPlyData + TPlyData::px+1
            adc #$FF
            sta VPlyData + TPlyData::px+1
            bra XVelocityPositiveEnd
        XVelocityPositive:
            lda VPlyData + TPlyData::px+1
            adc #0
            sta VPlyData + TPlyData::px+1
        XVelocityPositiveEnd:
        A16

    VerticalMovement:
        lda VPlyData + TPlyData::pvy

        ; add #TerminalSpeed
        ; cmp #(TerminalSpeed * 2)
        ; bge IsYTerminalTwiceFalse
        add #GravitySpeed
        ; IsYTerminalTwiceFalse:
        ; sub #TerminalSpeed

        sta VPlyData + TPlyData::pvy

        ; VPlyData.py += VPlyData.pvy.hibyte
        add VPlyData + TPlyData::pfy
        sta VPlyData + TPlyData::pfy
        ;
        A8
        lda VPlyData + TPlyData::pvy+1
        bpl YVelocityPositive
            lda VPlyData + TPlyData::py+1
            adc #$FF
            sta VPlyData + TPlyData::py+1
            bra YVelocityPositiveEnd
        YVelocityPositive:
            lda VPlyData + TPlyData::py+1
            adc #0
            sta VPlyData + TPlyData::py+1
        YVelocityPositiveEnd:
        A16

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
    
    ; clear grabbing wall flag
    stz VPlyData + TPlyData::grab

    rts
.endproc

; background/empty => 00
; foreground/empty => 01
; foreground/solid => 80
; foreground/spiku => 81
; foreground/spikd => 82
; foreground/spikl => 83
; foreground/spikr => 84
; slope rsll/solid => C0
; slope rslh/solid => C1
; slope rsrh/solid => C2
; slope rsrl/solid => C3
; slope fslh/solid => C4
; slope fsll/solid => C5
; slope fsrl/solid => C6
; slope fsrh/solid => C7

;; [assume] A16, XY16
;; [inputs] X: tx, Y: ty
;; [outputs] none
;; [kills] A, X, Y
;; [desc] get the tile collision types at a tile coordinate
;;        VColTiles will contain:
;;          top left, top right, bottom right, bottom left
.a16
.proc GetTileCollisionsAt
    tmp = VScw2
    tmp2 = VScw3

    GetTileCollisByteCoord:
        ; a = (y * VWrdBoundW * 2) + (x * 2)
        A8Zero
        tya
        sta WRMPYA
        
        lda VWrdBoundW
        sta WRMPYB
        A16 

        txa
        add RDMPYL
        mul2
        tax

        ; for top to bottom transition
        ; tmp = VWrdBoundW * 2
        lda VWrdBoundW
        and #$FF
        mul2
        sta tmp

        A8Zero
    GetTileCollisTopLeft:
        lda f:VMapData0, X
        div2
        tay
        lda VTileMetaTable, Y
        sta VColTiles

    GetTileCollisTopRight:
        lda f:VMapData0+2, X
        div2
        tay
        lda VTileMetaTable, Y
        sta VColTiles+1

    GetTileCollisBottomRight:
        ; move down a line
        A16
        txa
        add tmp
        tax
        A8Zero

        lda f:VMapData0+2, X
        div2
        tay
        lda VTileMetaTable, Y
        sta VColTiles+2

    GetTileCollisBottomLeft:
        lda f:VMapData0, X
        div2
        tay
        lda VTileMetaTable, Y
        sta VColTiles+3

    A16
    rts
.endproc
.a8

.a16
.macro ResetJumpOnGround
    stz VPlyData + TPlyData::jmptime ; + TPlyData::jmpcnt
    lda #704
    sta VPlyData + TPlyData::stamina
.endmacro
.a8

.a16
.macro ResetJumpOnGroundNoA
    stz VPlyData + TPlyData::jmptime ; + TPlyData::jmpcnt
    ldx #704
    stx VPlyData + TPlyData::stamina
.endmacro
.a8

; ##...
; ###..
; #####
;; [notafunc]
;; [assume] A8, XY16
;; [inputs] X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] see MovePlayerCollisionByTile
.proc MovePlayerFloorSlopeLeftHigh
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left Y pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    tmp = VScw4
    Checklist:
        AZero

        ; check if X or Y is at or less than -16, an edge case where we don't touch this tile at all
        cpx #($FFF0+1)
        bmi NoMovement
        cpy #($FFF0+1)
        bmi NoMovement

        ; if y >= 12 (at or lower than the center of the tile), push the player down
        cpy #12
        bcc :+
            cpy #$8000
            bcc SetPlayerYBelow
        :

        ; if x < 0 (right side of player always clips top of slope), push the player up
        cpx #$8000
        bcs SetPlayerYAbove

        ; tmp = x >> 1
        ; if (y + 15 > tmp), set y offset to top + tmp
        ; we're ok to use A8 since our X and Y ranges are [-16, 15]
        txa
        div2
        sta tmp
        stz tmp+1
        ;
        tya
        add #15
        cmp tmp
        ;
        bpl SetPlayerY

        ; we're in the open top left corner, so do nothing
        ;; [fallthrough]
    
    NoMovement:
        rts

    SetPlayerYAbove:
        A16
        lda inro_plyTileWy
        sbc #8
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerYBelow:
        A16
        lda inro_plyTileWy
        add #24
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerY:
        A16
        lda inro_plyTileWy
        add tmp
        sub #8
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
.endproc

; .....
; ##...
; ####.
;; [notafunc]
;; [assume] A8, XY16
;; [inputs] X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] see MovePlayerCollisionByTile
.proc MovePlayerFloorSlopeLeftLow
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left Y pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    tmp = VScw4
    Checklist:
        AZero

        ; check if X is -16 or 16, an edge case where we don't touch this tile at all
        ; also check if Y is less than -8, where we don't touch the
        ; bottom half of this tile at all
        cpx #($FFF0+1)
        bmi NoMovement
        cpx #$10
        beq NoMovement
        cpy #$FFF8
        bcs :+
            cpy #$8000
            bcs NoMovement
        :

        ; if x < 0 (right side of player always clips top of slope), push the player up
        cpx #$8000
        bcs SetPlayerYAbove

        ; tmp = x >> 1
        ; if (y + 8 > tmp), set y offset to top + tmp + 8
        ; we're ok to use A8 since our X and Y ranges are [-16, 15]
        txa
        div2
        sta tmp
        stz tmp+1
        ;
        tya
        add #8
        cmp tmp
        ;
        bpl SetPlayerY

        ; we're in the open top left corner, so do nothing
        ;; [fallthrough]
    
    NoMovement:
        rts

    SetPlayerYAbove:
        A16
        lda inro_plyTileWy
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerYBelow:
        A16
        lda inro_plyTileWy
        add #24
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerY:
        A16
        lda inro_plyTileWy
        add tmp
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
.endproc

; ...##
; ..###
; #####
;; [notafunc]
;; [assume] A8, XY16
;; [inputs] X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] see MovePlayerCollisionByTile
.proc MovePlayerFloorSlopeRightHigh
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left Y pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    tmp = VScw4
    Checklist:
        AZero

        ; check if X or Y is at or less than -16, an edge case where we don't touch this tile at all
        cpx #($FFF0+1)
        bmi NoMovement
        cpy #($FFF0+1)
        bmi NoMovement

        ; if y >= 12 (at or lower than the center of the tile), push the player down
        cpy #12
        bcc :+
            cpy #$8000
            bcc SetPlayerYBelow
        :

        ; if x >= 0 (left side of player always clips top of slope), push the player up
        cpx #$8000
        bcc SetPlayerYAbove

        ; tmp = (-x) >> 1
        ; if (y + 16 > tmp), set y offset to top + tmp
        ; we're ok to use A8 since our X and Y ranges are [-16, 15]
        txa
        eor #$FF
        inc
        ;
        div2
        sta tmp
        stz tmp+1
        ;
        tya
        add #16
        cmp tmp
        ;
        bpl SetPlayerY

        ; we're in the open top left corner, so do nothing
        ;; [fallthrough]
    
    NoMovement:
        rts

    SetPlayerYAbove:
        A16
        lda inro_plyTileWy
        sub #8
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerYBelow:
        A16
        lda inro_plyTileWy
        add #24
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerY:
        A16
        lda inro_plyTileWy
        add tmp
        sub #8
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
.endproc

; .....
; ...##
; .####
;; [notafunc]
;; [assume] A8, XY16
;; [inputs] X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] see MovePlayerCollisionByTile
.proc MovePlayerFloorSlopeRightLow
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left Y pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    tmp = VScw4
    Checklist:
        AZero

        ; check if X is -16 or 16, an edge case where we don't touch this tile at all
        ; also check if Y is less than -8, where we don't touch the
        ; bottom half of this tile at all
        cpx #($FFF0+1)
        bmi NoMovement
        cpx #$10
        beq NoMovement
        cpy #$FFF8
        bcs :+
            cpy #$8000
            bcs NoMovement
        :

        ; if x >= 0 (left side of player always clips top of slope), push the player up
        cpx #$8000
        bcc SetPlayerYAbove

        ; tmp = (-x) >> 1
        ; if (y + 7 > tmp), set y offset to top + tmp + 7
        ; we're ok to use A8 since our X and Y ranges are [-16, 15]
        txa
        eor #$FF
        inc
        ;
        div2
        sta tmp
        stz tmp+1
        ;
        tya
        add #7
        cmp tmp
        ;
        bpl SetPlayerY

        ; we're in the open top left corner, so do nothing
        ;; [fallthrough]
    
    NoMovement:
        rts

    SetPlayerYAbove:
        A16
        lda inro_plyTileWy
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerYBelow:
        A16
        lda inro_plyTileWy
        add #24
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
    SetPlayerY:
        A16
        lda inro_plyTileWy
        add tmp
        sta VPlyData + TPlyData::py
        lda #800
        sta VPlyData + TPlyData::pvy

        ResetJumpOnGround
        A8
        rts
.endproc

; spike (any direction)
;; [notafunc]
;; [assume] A8, XY16
;; [inputs] X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] see MovePlayerCollisionByTile
.proc MovePlayerSpike
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left Y pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    Checklist:
        AZero

        ; check if X/Y between 12 and -12
        cpx #($FFF4+1)
        bmi NoMovement
        cpx #$0C
        bge NoMovement
        cpy #($FFF4+1)
        bmi NoMovement
        cpy #$0C
        bge NoMovement

    SpikeDie:
        ; hack so we don't keep setting it in a loop
        lda VWrdCamTime
        bne NoMovement

        lda VWrdCurLvl
        sta VWrdNextLvl
        lda #1
        sta VWrdCamTime

    NoMovement:
        rts
.endproc

;; [assume] A8, XY16
;; [inputs] A: tiletype, X: pxoff, Y: pyoff, VScw0: inro_plyTileWx, VScw1: inro_plyTileWy
;; [outputs] none
;; [kills] A, X, Y
;; [desc] move the player due to collision with a single tile
.proc MovePlayerCollisionByTile
    ; a = type of tile
    ; x = player top left X pixel offset from tile top left pixel
    ; y = player top left X pixel offset from tile top left pixel
    inro_plyTileWx = VScw0 ; tile top left X world offset
    inro_plyTileWy = VScw1 ; tile top left Y world offset
    tmp = VScw4

    ; only tiles with meta value >= 0x80 have collision
    cmp #$80
    bcs EmptyTileFalse
        rts
    EmptyTileFalse:

    cmp #$C4
    bne :+
        jmp MovePlayerFloorSlopeLeftHigh
    :
    cmp #$C5
    bne :+
        jmp MovePlayerFloorSlopeLeftLow
    :
    cmp #$C6
    bne :+
        jmp MovePlayerFloorSlopeRightLow
    :
    cmp #$C7
    bne :+
        jmp MovePlayerFloorSlopeRightHigh
    :
    cmp #$81
    blt :+
    cmp #($84+1)
    bge :+
        sub #$81
        jmp MovePlayerSpike
    :
    ;; [fallthrough]

HandleSolidTile:
    CheckNoTouch:
    ; check if X or Y is at or less than -16, an edge case where we don't touch this tile at all
    cpx #($FFF0+1)
    bpl :+
        NoTouchReturn:
        rts
    :
    cpy #($FFF0+1)
    bmi NoTouchReturn

    HandleTileDown:
        ; check if going into tile down (and needs to be pushed up)
        ; IsColliding = (y > -16 && y <= -8) && (x < 12 && x >= -12)
        ; IsColliding = (y > 0xEA && y <= 0xF8) && (x > 0xF4 || x < 0x0C)
        tya
        sub #($F0+1)
        cmp #($F8-($F0+1)+1)
        bcs HandleTileDownDone

        txa
        sub #$0C
        cmp #($F4-$0C+1)
        bcc HandleTileUpDone ; skip Y opto
            ; push player up
            A16
            lda inro_plyTileWy
            sub #8
            sta VPlyData + TPlyData::py

            ResetJumpOnGroundNoA

            lda #200
            sta VPlyData + TPlyData::pvy
            A8
            stz VPlyData + TPlyData::pfy
            rts
        HandleTileDownDone:

    HandleTileUp:
        ; check if going into tile up (and needs to be pushed down)
        ; IsColliding = (y >= 8 && y < 16) && (x < 12 && x >= -12)
        ; IsColliding = (y >= 0x08 && y < 0x10) && (x > 0xF4 || x < 0x0C)
        tya
        sub #8
        cmp #(16-8)
        bcs HandleTileUpDone

        txa
        sub #$0C
        cmp #($F4-$0C+1)
        bcc HandleTileUpDone
            ; push player down
            A16
            lda inro_plyTileWy
            add #(16+8)
            sta VPlyData + TPlyData::py
            A8

            lda #0 ; ...
            sta VPlyData + TPlyData::pvy
            rts
        HandleTileUpDone:

    HandleTileRight:
        ; check if going into tile right (and needs to be pushed left)
        ; IsColliding = (x > -16 && x <= -8) && (y < 12 && y >= -12)
        ; IsColliding = (x > 0xEA && x <= 0xF8) && (y > 0xF4 || y < 0x0C)
        txa
        sub #($F0+1)
        cmp #($F8-($F0+1)+1)
        bcs HandleTileRightDone

        tya
        sub #$0C
        cmp #($F4-$0C+1)
        bcc HandleTileLeftDone ; skip X opto
            ; push player right
            A16
            lda inro_plyTileWx
            sub #8
            sta VPlyData + TPlyData::px
            A8
            stz VPlyData + TPlyData::pfx

            lda #1
            sta VPlyData + TPlyData::grab

            stz VPlyData + TPlyData::pvx
            stz VPlyData + TPlyData::pvx+1
            rts
        HandleTileRightDone:

    HandleTileLeft:
        ; check if going into tile left (and needs to be pushed right)
        ; IsColliding = (x >= 8 && x < 16) && (y < 12 && y >= -12)
        ; IsColliding = (x >= 0x08 && x < 0x10) && (y > 0xF4 || y < 0x0C)
        txa
        sub #8
        cmp #(16-8)
        bcs HandleTileLeftDone

        tya
        sub #$0C
        cmp #($F4-$0C+1)
        bcc HandleTileLeftDone
            ; push player left
            A16
            lda inro_plyTileWx
            add #(16+8)
            sta VPlyData + TPlyData::px
            A8
            stz VPlyData + TPlyData::pfx

            lda #2
            sta VPlyData + TPlyData::grab

            stz VPlyData + TPlyData::pvx
            stz VPlyData + TPlyData::pvx+1
        HandleTileLeftDone:
    rts
.endproc

;; [assume] A8, XY16
;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] move the player due to collision with world tiles
.proc PfUpdatePlayerCollision
    plyTileWx = VScw0
    plyTileWy = VScw1
    plyPxOffx = VScw2
    plyPxOffy = VScw3

    A16
    ; GetTileCollisionsAt takes top left tile coordinate as input
    ; x = (VPlyData.x - 8) / 16
    ; plyTileWx = x * 16
    lda VPlyData + TPlyData::px
    sub #8
    and #$FFF0
    sta plyTileWx
    div16
    tax
    ; y = (VPlyData.y - 8) / 16
    ; plyTileWy = y * 16
    lda VPlyData + TPlyData::py
    sub #8
    and #$FFF0
    sta plyTileWy
    div16
    tay

    jsr GetTileCollisionsAt ;; [takes] SCRW2, SCRW3

    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A8
    bit VColTiles+0
    bpl TopLeftTileFalse
        ; move based on collision on top left tile
        
        A16
        ; find offset from top left pixel of top left tile
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        lda VColTiles+0
        jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    TopLeftTileFalse:

    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A16
    ; find offset from top left pixel of top right tile
    ; plyTileWx += 16
    lda plyTileWx
    add #16
    sta plyTileWx
    
    A8
    bit VColTiles+1
    bpl TopRightTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+1
        jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    TopRightTileFalse:
    
    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A16
    ; find offset from top left pixel of bottom right tile
    ; plyTileWy += 16
    lda plyTileWy
    add #16
    sta plyTileWy

    A8
    bit VColTiles+2
    bpl BottomRightTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx
        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+2
        jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    BottomRightTileFalse:
    
    ; ;;;;;;;;;;;;;;;;;;;;;;;;

    A16
    ; find offset from top left pixel of bottom left tile
    ; plyTileWx -= 16
    lda plyTileWx
    sub #16
    sta plyTileWx
    
    A8
    bit VColTiles+3
    bpl BottomLeftTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+3
        jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    BottomLeftTileFalse:

    rts
.endproc

;; [assume] A8, XY16
;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
;; [desc] move the npc due to collision with world tiles (TODO: actually do this)
.proc UpdateNpcCollision
    plyTileWx = VScw0
    plyTileWy = VScw1
    plyPxOffx = VScw2
    plyPxOffy = VScw3

    A16
    ; GetTileCollisionsAt takes top left tile coordinate as input
    ; x = (VPlyData.x - 8) / 16
    ; plyTileWx = x * 16
    lda VPlyData + TPlyData::px
    sub #8
    and #$FFF0
    sta plyTileWx
    div16
    tax
    ; y = (VPlyData.y - 8) / 16
    ; plyTileWy = y * 16
    lda VPlyData + TPlyData::py
    sub #8
    and #$FFF0
    sta plyTileWy
    div16
    tay

    jsr GetTileCollisionsAt ;; [takes] SCRW2, SCRW3

    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A8
    bit VColTiles+0
    bpl TopLeftTileFalse
        ; move based on collision on top left tile
        
        A16
        ; find offset from top left pixel of top left tile
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        lda VColTiles+0
        ; jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    TopLeftTileFalse:

    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A16
    ; find offset from top left pixel of top right tile
    ; plyTileWx += 16
    lda plyTileWx
    add #16
    sta plyTileWx
    
    A8
    bit VColTiles+1
    bpl TopRightTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+1
        ; jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    TopRightTileFalse:
    
    ; ;;;;;;;;;;;;;;;;;;;;;;;;
    
    A16
    ; find offset from top left pixel of bottom right tile
    ; plyTileWy += 16
    lda plyTileWy
    add #16
    sta plyTileWy

    A8
    bit VColTiles+2
    bpl BottomRightTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx
        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+2
        ; jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    BottomRightTileFalse:
    
    ; ;;;;;;;;;;;;;;;;;;;;;;;;

    A16
    ; find offset from top left pixel of bottom left tile
    ; plyTileWx -= 16
    lda plyTileWx
    sub #16
    sta plyTileWx
    
    A8
    bit VColTiles+3
    bpl BottomLeftTileFalse
        A16
        ; plyPxOffx = (VPlyData.x - 8) - plyTileWx
        lda VPlyData + TPlyData::px
        sub plyTileWx
        sub #8
        tax ; plyPxOffx

        ; plyPxOffy = (VPlyData.y - 8) - plyTileWy
        lda VPlyData + TPlyData::py
        sub plyTileWy
        sub #8
        tay ; plyPxOffy
        A8Zero

        ; move based on collision on top left tile
        lda VColTiles+3
        ; jsr MovePlayerCollisionByTile ;; [takes] SCRW4
    BottomLeftTileFalse:

    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;

; SPRITE RENDER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; [assume] A8, XY16
;; [inputs] X: wx, Y: wy
;; [outputs] X: sx, Y: sy
;; [kills] A, X, Y
;; [desc] convert world coordinate to screen coordinate for sprite
.proc PfToPointOnScreen
    ctxOff = VScw0
    ctyOff = VScw1

    ; check X for being on screen
    ; ctxOff = VWrdCamTX + 8
    lda VWrdCamTX
    add #8
    sta ctxOff
    
    ; sprtx = spr.x >> 4
    A16
    txa
    div16
    A8
    
    ; check sprtx < ctxOff
    sub ctxOff
    bcc OutOfScreenSpace

    ; check sprtx >= ctxOff + 16
    cmp #(16+8)
    bcs OutOfScreenSpace
    
    ; check Y for being on screen
    ; ctyOff = VWrdCamTY + 8
    lda VWrdCamTY
    add #8
    sta ctyOff
    
    ; sprty = spr.y >> 4
    A16
    tya
    div16
    A8
    
    ; check sprty < ctyOff
    sub ctyOff
    bcc OutOfScreenSpace

    ; check sprty >= ctyOff + 16
    cmp #16
    bcs OutOfScreenSpace

    ; we checked we're on screen
    A16

    ; return (x - VWrdCamX - 8, y - VWrdCamY - 8)
    txa
    sub VWrdCamX
    sub #8
    tax

    tya
    sub VWrdCamY
    sub #8
    tay

    A8
    rts

OutOfScreenSpace:
    A8
    lda #240
    tax
    tay
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] A, X, Y
.proc PfUpdatePlayerOam
    ldx VPlyData + TPlyData::px
    ldy VPlyData + TPlyData::py
    jsr PfToPointOnScreen ;; [takes] SCRW0, SCRW1, SCRW2, SCRW3

    ; set high X flag
    A16
    txa
    and #$FF00
    beq SetXFlagFalse
        A8
        lda VSprHi+$00
        ora #%00000011
        sta VSprHi+$00
        bra EndSetXFlagFalse
    SetXFlagFalse:
        .a16
        A8
        lda VSprHi+$00
        ora #%00000010
        sta VSprHi+$00
    EndSetXFlagFalse:

    ; set low data
    XY8
    stx VSprLo+$00 ; x pos
    sty VSprLo+$01 ; y pos
    XY16
    
    stz VSprLo+$02 ; tile number
    
    lda VPlyData + TPlyData::dir
    beq PlayerFacingLeft
        lda #%00100000 ; attributes (palette 0, priority 1, no flip)
        bra EndPlayerFacingLeft
    PlayerFacingLeft:
        lda #%01100000 ; attributes (palette 0, priority 1, flip)
    EndPlayerFacingLeft:
    ;
    sta VSprLo+$03

    rts
.endproc

PfUpdateNpcOam_SetScr:
    .byte %00000010
    .byte %00001000
    .byte %00100000
    .byte %10000000

PfUpdateNpcOam_SetOff:
    .byte %00000011
    .byte %00001100
    .byte %00110000
    .byte %11000000

;; [inputs] X: sprite x offset, Y: sprite y offset, SCRB0: attrBits, SCRB1: npcIdx, SCRB2: tileIdx
;; [outputs] none
;; [kills] axy
.proc PfUpdateNpcOam
    inro_attrBits = VScb0
    inro_npcIdx = VScb1
    inro_tileIdx = VScb2
    highBitsSet = VScb3
    scrPtX = VScw0

    jsr PfToPointOnScreen ;; [takes] SCRW0, SCRW1, SCRW2, SCRW3
    stx scrPtX

    ; get low data address
    AZeroSafe
    lda inro_npcIdx
    mul4
    tax

    ; set low data
    lda scrPtX
    sta VSprLo+($00+8*4), X ; x pos
    tya
    sta VSprLo+($01+8*4), X ; y pos

    ; exit early if X and Y are 240 (putting this offscreen means the rest doesn't matter)
    cpy #240
    beq ExitEarly

    lda inro_tileIdx
    sta VSprLo+($02+8*4), X ; tile idx

    lda inro_attrBits
    sta VSprLo+($03+8*4), X ; attributes

    ; set high X flag
    lda inro_npcIdx
    div4
    tay
    
    A16
    lda scrPtX
    and #$FF00
    bne SetXFlagTrue
        A8ZeroSafe

        lda inro_npcIdx
        and #3
        tax
        lda PfUpdateNpcOam_SetScr, X

        ora VSprHi+(8/4), Y
        sta VSprHi+(8/4), Y
        rts
    SetXFlagTrue:
        .a16
        A8ZeroSafe

        lda inro_npcIdx
        and #3
        tax
        lda PfUpdateNpcOam_SetOff, X
        
        ora VSprHi+(8/4), Y
        sta VSprHi+(8/4), Y
        rts
    EndSetXFlagTrue:

ExitEarly:
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] ax
;; [inlined]
.macro UpdateSpritePositions
    ; doesn't seem necessary to set OAMADDX here?
    WfvDmaCopyOneReg OAMDATA, VSprLo, 512 + 32
.endmacro

;; [inputs] none
;; [outputs] none
;; [kills] axy
;; [desc] using push/pull since DP could move + more temp vars available
.proc PfUpdateSpritesLogic
    A16
    ; clear high oam
    stz VSprHi+(8/4)+0 ; npcs 0-7
    stz VSprHi+(8/4)+2 ; npcs 8-15
    stz VSprHi+(8/4)+4 ; npcs 16-23
    stz VSprHi+(8/4)+6 ; npcs 24-31

    A8
    ; lda #32
    ; LoopTop:
    ;     dec
    ;     pha ; i

    ;     ; byte address
    ;     tay

    ;     tyx
    ;     bit VNpcData + TNpcData::flags, X ; no Y variant :(
    ;     bvc NotRunningScript ; test bit at 0x40 (TNpcData_FL_EXECUTE)
    ;         ; word address
    ;         txa
    ;         asl
    ;         tax
            
    ;         AZeroSafe ; necessary?
    ;         jsr (VNpcData + TNpcData::nascptr, X)
        
    ;         ; restore Y
    ;         AZeroUpperSafe
    ;         lda 1, S ; i (we will pull later)
    ;         tay
    ;     NotRunningScript:

    ;     lda VNpcData + TNpcData::nidx, Y
    ;     beq IsNullNpc
    ;         jsr ProcessSprite
            
    ;         AZeroUpperSafe
    ;         lda 1, S ; i (we will pull later)
    ;         ;
    ;         A16
    ;         mul4
    ;         tax
    ;         A8

    ;         lda VSprLo + 1, X ; get calculated Y position
    ;         cmp #240 ; check if offscreen
    ;         beq SkipNpcCollision
    ;             jsr UpdateNpcCollision
    ;         SkipNpcCollision:

    ;         ;; [fallthrough]
    ;     IsNullNpc:
    ;         AZeroUpperSafe
    ;         pla ; i
    ;         bne LoopTop
    ;         rts
    ;     EndIsNullNpc:
    ; LoopEnd:
    rts
.endproc

; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;

; TOP LEVEL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; code before camera moves
;; [inputs] none
;; [outputs] none
;; [kills] axy
.proc PfUpdateSpritesBeforeCam
    ; if we are transitioning, disable all sprite handling
    lda VWrdCamTime
    beq CamtimeRunning
        rts
    CamtimeRunning:

    jmp UpdatePlayer
.endproc

; code after camera moves
;; [inputs] none
;; [outputs] none
;; [kills] axy
.proc PfUpdateSpritesAfterCam
    jsr PfUpdatePlayerCollision
    jsr PfUpdatePlayerOam

    ; if we are transitioning, disable sprite updating
    lda VWrdNextLvl
    beq CamtimeRunning
        rts
    CamtimeRunning:

    ; jsr PfUpdateSpritesLogic
    rts
.endproc

;; [inputs] none
;; [outputs] none
;; [kills] axy
.proc PfRenderSprites
    inlinedcall UpdateSpritePositions
    rts
.endproc
