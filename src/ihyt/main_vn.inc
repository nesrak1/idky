.ifndef MAIN_VN_INC
MAIN_VN_INC = 1

.global ModeVnReset

.global VnZero

CVramBg1Map   = $0400
CVramBg2Map   = $0800
CVramBg3Map   = $0C00
CVramBg1Tiles = $1000
CVramBg2Tiles = $0000
CVramBg3Tiles = $0000
CVramSpritesA = $4000
CVramSpritesB = $6000

.endif ; MAIN_VN_INC