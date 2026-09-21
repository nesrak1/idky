.p816
.i16
.a8

.include "wf_macros.inc"
.include "reset.s"

.importzp VFrameReady

.segment "CODE"
ThNmi:
    sei ; disable interrupts

    ; save regs
    phb
    pha
    php
    
    ; set frame ready flag
    A8
    lda #1
    sta VFrameReady
    
    ; restore regs
    plp
    pla
    plb

    cli ; reenable interrupts
    rti

ThReset:
    sei ; disable interrupts
    
    clc ; set native mode
    xce

    XY16
    A8

    jsr Reset

ThIrq:
    rti

.segment "HEADER"
    .byte "-I LL HOLD YOU TIGHT-"

.segment "ROMINFO"
    .byte $30          ; LoRom
    .byte 0            ; no ram
    .byte $08          ; 256 KiB (we should update to 512!)
    .byte 0,0,0,0
    .word $AAAA,$5555  ; blah checksum

.segment "VECTORS"
    ; ---, ---, COP, BRK, ABORT, NMI, RESET, IRQ
    .addr 0, 0, 0, 0, 0, ThNmi, ThReset, ThIrq
    .addr 0, 0, 0, 0, 0, 0, ThReset, 0