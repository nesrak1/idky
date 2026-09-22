.ifndef MAIN_PF_INC
MAIN_PF_INC = 1

.global ModePfReset

.global PfZero

.global ClipCameraX
.global ClipCameraY

CVramBg1Map   = $5000
CVramBg2Map   = $5400
CVramBg3Map   = $5800
CVramBg1Tiles = $0000
CVramBg2Tiles = $2000
CVramBg3Tiles = $4000
CVramSprites  = $6000

.endif ; MAIN_PF_INC