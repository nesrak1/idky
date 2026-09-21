.ifndef PF_ASC_MACROS_INC
PF_ASC_MACROS_INC = 1

.p816
.i16
.a8

.include "wf_macros.inc"

; see https://archive.cavestory.org/basicmodding/guide/tsc.txt
; note: arguments are in BL order (WWWW:XXXX:YYYY:ZZZZ), whereas the
;   above doc is not (XXXX:YYYY:ZZZZ:WWWW)
; note: not all TSC is completely the same (for obvious reasons)
;   see comments below for more details

; FAde In [WWWW direction (ignored)]
.macro AscFAI rel, aw
    nop
.endmacro

; FAde Out [WWWW direction (ignored)]
.macro AscFAO rel, aw
    nop
.endmacro

; MOVe player [WWWW X pos:XXXX Y pos]
.macro AscMOV rel, aw, ax
    .local AscMovProc
    .proc AscMovProc
        ldx #((aw*16)+8)
        stx VPlyData + TPlyData::px
        ldx #((ax*16)+8)
        stx VPlyData + TPlyData::py
    .endproc
    AscAddr .set AscAddr + .sizeof(AscMovProc)
.endmacro

; Player Restrict Input
.macro AscPRI rel
    .local AscPriProc
    .proc AscPriProc
        lda #1
        sta VPlyData + TPlyData::fl_pri
        stz VPlyData + TPlyData::grab
    .endproc
    AscAddr .set AscAddr + .sizeof(AscPriProc)
.endmacro

; TRAvel to level [WWWW map:XXXX run event (ignored):YYYY X pos:ZZZZ Y pos]
; note: no travel will occur until FAO completes
.macro AscTRA rel, aw, ax, ay, az
    .local AscTraProc
    .proc AscTraProc
        lda #(aw-94) ; because too lazy to delete all other maps
        sta VWrdNextLvl
        ldx #((ay*16)+8)
        stx VWrdNextX
        ldx #((az*16)+8)
        stx VWrdNextY
        lda #1
        sta VWrdCamTime
    .endproc
    AscAddr .set AscAddr + .sizeof(AscTraProc)
.endmacro

; WAIt time [WWWW frames]
; note: wait time is stored in ndata1, so for NPCs that use <WAI,
; they should not use ndata1 for their main (non-asc) code
.macro AscWAI rel, aw
    .local AscWaiProc
    .local AscWaiSleepA16
    .local AscWaiEnd
    .proc AscWaiProc
        A16

        ; word addressing
        tya
        asl
        tax

        lda VNpcData + TNpcData::ndata1, X
        beq FirstTimeWait
            dec VNpcData + TNpcData::ndata1, X
            beq FirstTimeWaitEnd ; if counter is 0, go to end
            ; counter is not 0, so return back and wait for next frame
            jmp AscWaiSleepA16
        FirstTimeWait:
            .a16
            lda #aw
            sta VNpcData + TNpcData::ndata1, X

            jmp AscWaiSleepA16
        FirstTimeWaitEnd:
        A8
        jmp AscWaiEnd
    .endproc
    
    ; returns must be outside of the proc because ca65 will only assemble
    ; the proc's assembly after the pass that sets AscAddr has finished.
    ; if we put this code in the proc, every instruction using AscAddr
    ; would be set to the ending address, not the address at the time
    ; of encounter. so this is a bit of a workaround.
    AscWaiSleepA16:
        .a16
        lda #(rel+AscAddr)
        sta VNpcData + TNpcData::nascptr, Y
        A8
        rts
    AscWaiEnd:

    AscAddr .set AscAddr + .sizeof(AscWaiProc) + (AscWaiEnd - AscWaiSleepA16)
.endmacro

; MeSsaGe box {text len (not in TSC)}
; note: you must call AscMSGChar for each pair of characters
; todo: use the string table method later
.macro AscMSG rel, text_len
    .local AscMsgProc
    .proc AscMsgProc
        ; lda #$FE
        ; sta VTxtAt
        ; lda #text_len
        ; sta VTxtLimit
        nop
    .endproc
    AscAddr .set AscAddr + .sizeof(AscMsgProc)
.endmacro

.macro AscMSGChar rel, char1, char2, idx
    .local AscMsgProc
    .proc AscMsgProc
        ldx #(char1 + (char2<<8))
        stx VTxtLines + idx
    .endproc
    AscAddr .set AscAddr + .sizeof(AscMsgProc)
.endmacro

; NOD to message (sleep until X pressed)
.macro AscNOD rel
    .local AscNodProc
    .local AscNodSleepA16
    .local AscNodEnd
    .proc AscNodProc
        A16
        lda #JOY_X
        trb VPad1Fir
        beq AscNodSleepA16
            A8
            jmp AscNodEnd
        NodAPressedFalse:
    .endproc
    
    AscNodSleepA16:
        .a16

        ; word addressing
        tya
        asl
        tax

        lda #(rel+AscAddr)
        sta VNpcData + TNpcData::nascptr, X
        A8
        rts
    AscNodEnd:

    AscAddr .set AscAddr + .sizeof(AscNodProc) + (AscNodEnd - AscNodSleepA16)
.endmacro

; END scripted event (close message box, re-enable input)
.macro AscEND rel
    .local AscEndProc
    .proc AscEndProc
        ; lda #$FF
        ; sta VTxtAt
        ; lda #0
        ; sta VPlyData + TPlyData::fl_pri
        nop
    .endproc
    AscAddr .set AscAddr + .sizeof(AscEndProc)
.endmacro

; STC (used for a different purpose, reenables interactive flag)
.macro AscSTC rel
    .local AscStcProc
    .proc AscStcProc
        lda VNpcData + TNpcData::flags, Y
        ora #$20
        sta VNpcData + TNpcData::flags, Y
    .endproc
    AscAddr .set AscAddr + .sizeof(AscStcProc)
.endmacro

; FLag Jump
.macro AscFLJ rel, index, event
    .local AscFljProc
    .proc AscFljProc
        lda VFlags + (index >> 3)
        bit #(1 << (index & 7))
        beq SkipFlagJump
            jmp event
        SkipFlagJump:
    .endproc
    AscAddr .set AscAddr + .sizeof(AscFljProc)
.endmacro

; FLag Add(+)
.macro AscFLP rel, index
    .local AscFlpProc
    .proc AscFlpProc
        lda #(1 << (index & 7))
        tsb VFlags + (index >> 3)
    .endproc
    AscAddr .set AscAddr + .sizeof(AscFlpProc)
.endmacro

.macro AscInit
    ; npc.flags.execute = true
    .local AscInitProc
    .proc AscInitProc
        lda #TNpcDataFlExecute
        ora VNpcData + TNpcData::flags, Y
        sta VNpcData + TNpcData::flags, Y
    .endproc
    AscAddr .set AscAddr + .sizeof(AscInitProc)
.endmacro

.macro AscReset
    ; npc.flags.execute = false
    lda #(TNpcDataFlExecute ^ $FF)
    and VNpcData + TNpcData::flags, Y
    sta VNpcData + TNpcData::flags, Y
    
    A16

    ; word addressing
    tya
    asl
    tax

    ; npc.nascptr = start of original function
    lda VNpcData + TNpcData::nascptrs, X
    sta VNpcData + TNpcData::nascptr, X
    A8

    rts
.endmacro

.endif ; PF_ASC_MACROS_INC