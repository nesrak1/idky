.include "variables.inc"

.segment "ZEROPAGE"

    ; GLOBAL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VZero: .res 2 ; always $0000
    VSceneIndex: .res 1 ; 0 - world, 1 - ...
    VFrameReady: .res 1 ; set to 1 on vblank

    ; INPUT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VPad1Val: .res 2 ; input value
    VPad1Fir: .res 2 ; input first frame value (safe to modify)

    ; VISUAL NOVEL ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VCharData: .tag TCharData

    ; SCRATCH (20 bytes) ;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; scratch variables are either word-sized or byte-sized
    ; to prevent from us from making them accidentally step
    ; on each other.
    VScw0: .res 2
    VScw1: .res 2
    VScw2: .res 2
    VScw3: .res 2
    VScw4: .res 2
    VScw5: .res 2
    VScb0: .res 1
    VScb1: .res 1
    VScb2: .res 1
    VScb3: .res 1
    VScb4: .res 1
    VScb5: .res 1

    ; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; width and height of this level in tiles
    ; options: 16, 32, 64, 128
    VWrdBoundW: .res 1
    VWrdBoundH: .res 1

    ; used for tile coordinate wrapping
    ; 16 tiles = $0F, 32 tiles = $1F, 64 tiles = $3F, 128 tiles = $7F
    ; f (full) = (VWrdBoundW * VWrdBoundH * 2) - 1
    VWrdBoundmskW: .res 1
    VWrdBoundmskH: .res 1
    VWrdBoundmskF: .res 2

    ; world camera in pixels, starting at the top left
    VWrdCamX: .res 2
    VWrdCamY: .res 2
    ; the same as above but relative to the tile in pixels (i.e., 0-15)
    ; this is an optimization since (VWrdCam# & $0F) is often needed.
    VWrdCamPX: .res 2
    VWrdCamPY: .res 2
    ; world camera in tiles, starting at the top left
    ; used to determine if more tiles need to be loaded.
    VWrdCamTX: .res 1
    VWrdCamTY: .res 1
    ; bg scroll offset
    ; this differs based on the starting location of the
    ; loaded map. this is just added onto VWrdCam#
    ; and is for the bg only.
    VWrdCamOX: .res 2
    VWrdCamOY: .res 2
    ; vram scroll offset
    ; always 0-31 and specifies where the strip starts
    ; so it can wrap correctly.
    ; if moving right: edit the column (VsX++) & $1F
    ; if moving left: edit the column (--VsX) & $1F
    ; if moving down: edit the row (VsY++) & $1F
    ; if moving up: edit the row (--VsY) & $1F
    VWrdCamVsX: .res 1
    VWrdCamVsY: .res 1
    ; vram ready to copy
    ; %0000 = no copy,
    ; %1000 = copy vertical strip up,
    ; %0100 = copy vertical strip down,
    ; %0010 = copy horizontal strip left,
    ; %0001 = copy horizontal strip right
    VWrdCamVRdy: .res 1

    ; camera fade time, 0-31. start by setting to 1.
    ; it will animate from 1 to 31, start a level load
    ; if set, then animate back down to 0.
    ; the animation back is activated by VWrdNextLvl
    ; being set to 0 during load.
    ; note: nextx/nexty do not reset on map load. you
    ; can reuse these values to respawn at the last
    ; load coordinates. good for death events.
    VWrdCamTime: .res 1
    VWrdNextLvl: .res 1
    VWrdCurLvl: .res 1
    VWrdNextX: .res 2
    VWrdNextY: .res 2

    ; PLAYER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VPlyData: .tag TPlyData

    ; COLLISION ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; the collision tiles at the top left point given to GetTileCollisionsAt.
    ; for example, if the tile coord given to the function is at the @,
    ; then the returned tile types in this array are at indices 0-3
    ; .....    .....
    ; .@... -> .01..
    ; .....    .32..
    VColTiles: .res 4

    ; UI ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; ; temporary storage for building the UI bars
    ; ; this can move out of DP if needed (probably not,
    ; ; we seem to be fine on DP space so far)
    ; VUiBarTiles: .res 44

    ; FLAGS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VFlags: .res 10

    ; TEXT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VMsgWords: .res (2*16) ; row 0 to row 10 (+shadow)
    VMsgTileByteOff: .res 2
    VMsgBitOff: .res 1
    VMsgTilesReady: .res 1
    ; 0-2: full chatbox on visual novel mode
    ;   0: first row
    ;   1: second row
    ;   2: third row
    ; 3+: todo: would be used on menu screens
    VMsgTileMode: .res 1

    VZpPadding: .res 1 ; remove when padded

.segment "BSSLO"

    ; stack (code should not directly use this)
    VStackSpace: .res $100

    ; NPCS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    VNpcData: .tag TNpcData

    ; SPRITES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; the wram copy of oam sprite data. you should edit this to
    ; add/move sprites and set the V_SPR_RDY flag to non-zero.
    ; == in vn mode ==
    ; allocated dynamically in this order:
    ;   1. character sprites
    ;   2. UI elements
    ; == in platformer mode ==
    ;   todo
    VSprLo: .res 512
    VSprHi: .res 32

    ; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; for horizontal strips, we copy from the map data here into
    ; one strip so we can do a single copy from here to VRAM.
    ; for vertical strips we do the same, although we could make
    ; it where it copies directly from VMapData0 directly. we
    ; just don't right now.
    VWrdStripCpyX: .res 64  ; horizontal strips (left/right)
    VWrdStripCpyY: .res 64  ; vertical strips (up/down)

    ; tileset's meta table (collision type, liquid, damage, etc.)
    VTileMetaTable: .res 256

    ; TEXT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; TODO: we are replacing a lot of this!!!!

    ; ; the character index to write this frame
    ; ; todo: remove this
    ; VTxtAt: .res 1

    ; ; the character index to end at (or 0 to hide HUD)
    ; ; todo: remove this
    ; VTxtLimit: .res 1

    ; ; a word of the last tile row (msb, or 0 if none) and the current tile row (lsb).
    ; ; we only work on 1bpp until the tile is written, in which the shadow bit plane
    ; ; will be calculated at that moment in time.
    ; ; lasttile   new tile
    ; ; AAAAAAAA - aaaaaaaa ; top row
    ; ; BBBBBBBB - bbbbbbbb
    ; ; CCCCCCCC - cccccccc
    ; ; ... same for d, e, f
    ; ; GGGGGGGG - gggggggg ; bottom row
    ; VTxtPieceBuffer: .res (2*7) ; 7 rows max (top row of 8x8 tile unused)

    VTxtLines: .res (70*3)

    ; 26 tiles wide, 2 tiles high, 8 rows (one byte per row) * 2 planes = 16 bytes per 8x8 tile
    ; is this a waste of space to store an entire line? yes. are we still doing it? yes.
    VMsgBuffer: .res (26 * 2) * 16 ; 832 bytes

.segment "BSSHI1"

    ; WORLD ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ; temporary storage for BG map data. this is built at load time
    ; from the "compressed" (not really compressed) waffle map data.
    ; this maxes out at 128x64 or 64x128.
    VMapData0: .res $4000

    ; temporary storage for BG tile data during initial load. the
    ; same as V_MAPDATAx but only the parts that are loaded at the
    ; initial camera location. this is the exact data that will be
    ; sent to VRAM. after initial load, VWrdStripCpy# will be
    ; used instead.
    VMapTiles0: .res $800