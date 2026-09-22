.ifndef IHYT_VARS_INC
IHYT_VARS_INC = 1

; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; platformer player data
.struct TPlyData
    px .word         ; x position
    py .word         ; y position
    pvx .byte        ; x velocity
    pvy .byte        ; y velocity
    pvya .word       ; alternating y velocity (if 0, inc y once. if 1, inc y twice.)
    
    jmptime .byte    ; frames left that jump can be held
    jmpcnt  .byte    ; initial jumps used (reset to 0 when landing on ground)
    ;
    grab .byte       ; player is wall grab dir (0 not touching wall, 1 left, 2 right)
    oldgrab .byte    ; old grab direction
    ;
    hoptime .byte    ; frames left that grab hop lasts
    hopdir .byte     ; dir for grab hop
    
    stamina .word    ; stamina amount (0-255)
    health .byte     ; health amount (0-15)
    
    fl_pri .byte     ; non-zero if <PRI has disabled player input
.endstruct

; platformer npc data
.define TNpcDataMax 32  ; max 32 npcs (aka entities)
;
TNpcDataFlAltdir  = $80 ; face alternate direction flag
                        ; if unselected, point left, otherwise point right
                        ; for H/V collision, unselected is horiz, selected is vertical
TNpcDataFlExecute = $40 ; script is executing
TNpcDataFlInter   = $20 ; sprite is interactable (X will start script)
;
.struct TNpcData ; todo: apparently I should be using .byte/.word instead of .res
    nx .res (TNpcDataMax*2)
    ny .res (TNpcDataMax*2)
    nframe .res (TNpcDataMax*2)   ; increments once every frame, 0 at npc spawn
    nidx .res (TNpcDataMax*1)     ; npc index
    flags .res (TNpcDataMax*1)    ; see TNpcDataFl###
    nascptr .res (TNpcDataMax*2)  ; npc current asm address
    nascptrs .res (TNpcDataMax*2) ; npc start asm address
    ndata0 .res (TNpcDataMax*2)   ; free data space (for npc or asc code)
    ndata1 .res (TNpcDataMax*2)   ; ...
    ndata2 .res (TNpcDataMax*1)   ; ...
    ndata3 .res (TNpcDataMax*1)   ; ...
.endstruct

; VISUAL NOVEL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.define TCharDataMax 3 ; max 3 vn characters
;
TCharDataFlAltdir  = $80 ; face alternate direction flag
                         ; if unselected, point right, otherwise point left
TCharDataFlActive  = $40 ; sprite is being used
;
.struct TCharData
    cx .res (TCharDataMax*2)           ; x position
    cy .res (TCharDataMax*2)           ; y position

    cgram_pal .res (TCharDataMax*1)    ; which cgram palette is being used (0-7)
    var_flags .res (TCharDataMax*1)    ; which character variant is being used (& $3F) + flags
    vram_idx .res (TCharDataMax*1)     ; initial sprite index for VRAM
    tab_off_div8 .res (TCharDataMax*1) ; the meta table offset divided by 8
.endstruct

; GLOBAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VZero, VSceneIndex, VFrameReady
; INPUT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VPad1Val, VPad1Fir
; SCRATCH (16 bytes) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VScw0, VScw1, VScw2, VScw3
.globalzp VScw4, VScw5
.globalzp VScb0, VScb1, VScb2, VScb3
.globalzp VScb4, VScb5
; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VWrdBoundW, VWrdBoundH
.globalzp VWrdBoundmskW, VWrdBoundmskH, VWrdBoundmskF
.globalzp VWrdCamX, VWrdCamY, VWrdCamPX, VWrdCamPY
.globalzp VWrdCamTX, VWrdCamTY, VWrdCamOX, VWrdCamOY
.globalzp VWrdCamVsX, VWrdCamVsY, VWrdCamVRdy
.globalzp VWrdCamTime, VWrdNextLvl, VWrdCurLvl
.globalzp VWrdNextX, VWrdNextY
; PLAYER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VPlyData
; VISUAL NOVEL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VCharData
; COLLISION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VColTiles
; FLAGS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VFlags
; TEXT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.globalzp VMsgWords
.globalzp VMsgTileByteOff, VMsgBitOff, VMsgTilesReady
.globalzp VMsgTileMode
;
.global VStackSpace
; NPCS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.global VNpcData
; SPRITES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.global VSprLo, VSprHi
; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.global VWrdStripCpyX, VWrdStripCpyY, VTileMetaTable
; TEXT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.global VMsgBuffer
;
; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.global VMapData0, VMapTiles0

.endif ; IHYT_VARS_INC