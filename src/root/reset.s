.import ModeVnReset
.import ModePfReset

Reset:
    A8
    lda #1
    sta $420d ; MEMSEL

    ; jml ModeVnReset ; VN mode
    jml ModePfReset ; platformer mode