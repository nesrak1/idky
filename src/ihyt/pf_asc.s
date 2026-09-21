.p816
.i16
.a8

.include "pf_asc.inc"
.include "pf_asc_macros.inc"
.include "variables.inc"

.proc Asc_None
    AscAddr .set 0
    AscInit

    AscReset
.endproc