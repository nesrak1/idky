.ifndef WF_MACROS_INC
WF_MACROS_INC = 1

.p816
.macpack generic

.macro inlinedcall Arg
    Arg
.endmacro

; GPRs ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro AZero
    tdc
.endmacro

.macro AZeroSafe
    lda #0
    xba
    lda #0
.endmacro

; todo: handle when .a16
.macro AZeroUpperSafe
    lda #0
    xba
.endmacro

.macro A8Zero
    tdc
    .a8
    sep #$20
.endmacro

.macro A8ZeroSafe
    lda #0
    .a8
    sep #$20
.endmacro

.macro A8
    .a8
    sep #$20
.endmacro

.macro A16
    .a16
    rep #$20
.endmacro

.macro A16Clc
    .a16
    rep #$21
.endmacro

.macro AXY8
    .a8
    .i8
    sep #$30
.endmacro

.macro AXY16
    .a16
    .i16
    rep #$30
.endmacro

.macro XY8
    .i8
    sep #$10
.endmacro

.macro XY16
    .i16
    rep #$10
.endmacro

; Math ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro signext
    bit #$80
    beq :+
        ora #$FF00
    :
.endmacro

.macro negate8
    eor #$FF
    inc
.endmacro

.macro negate16
    eor #$FFFF
    inc
.endmacro

; Shift division ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.macro div2
    lsr
.endmacro

.macro div2signed8
    cmp #$80
    ror
.endmacro

.macro div2signed
    cmp #$8000
    ror
.endmacro

.macro div4
    lsr
    lsr
.endmacro

.macro div8
    lsr
    lsr
    lsr
.endmacro

.macro div16
    lsr
    lsr
    lsr
    lsr
.endmacro

.macro div32
    lsr
    lsr
    lsr
    lsr
    lsr
.endmacro

.macro div64
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
.endmacro

; Shift multiplication ;;;;;;;;;;;;;;;;;;;;;;;;;

.macro mul2
    asl
.endmacro

.macro mul4
    asl
    asl
.endmacro

.macro mul8
    asl
    asl
    asl
.endmacro

.macro mul16
    asl
    asl
    asl
    asl
.endmacro

.macro mul32
    asl
    asl
    asl
    asl
    asl
.endmacro

.macro mul64
    asl
    asl
    asl
    asl
    asl
    asl
.endmacro

; Same thing but regular shift names ;;;;;;;;;;;

.macro shr
    lsr
.endmacro

.macro shr2
    lsr
    lsr
.endmacro

.macro shr3
    lsr
    lsr
    lsr
.endmacro

.macro shr4
    lsr
    lsr
    lsr
    lsr
.endmacro

.macro shr5
    lsr
    lsr
    lsr
    lsr
    lsr
.endmacro

.macro shr6
    lsr
    lsr
    lsr
    lsr
    lsr
.endmacro

.macro shl
    asl
.endmacro

.macro shl2
    asl
    asl
.endmacro

.macro shl3
    asl
    asl
    asl
.endmacro

.macro shl4
    asl
    asl
    asl
    asl
.endmacro

.macro shl5
    asl
    asl
    asl
    asl
    asl
.endmacro

.macro shl6
    asl
    asl
    asl
    asl
    asl
    asl
.endmacro

.endif ; WF_MACROS_INC