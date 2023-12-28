;
; Glyphs, custom glphs to make pexec pretty
;

;------------------------------------------------------------------------------

	dum 0
GC ds 1
GE ds 1
GO ds 1
GP ds 1
GR ds 1
GX ds 1

GRUN0 ds 1
GRUN1 ds 1
GRUN2 ds 1
GRUN3 ds 1
	dend

;------------------------------------------------------------------------------

glyph_draw
	ldx term_x
	phx
	ldx term_y
	phx

	asl
	asl
	asl
	tax

	; c = 0
]lp lda glyphs,x
	jsr :emit_line

	lda term_ptr
	adc #80
	sta term_ptr
	lda term_ptr+1
	adc #0
	sta term_ptr+1

	inx
	cpx #8     	; for size we could make this 7
	bcc ]lp

	rts 		; then remove this rts

:emit_line
	ldy #0
]lp
	asl
	tax
	lda #' '    ; space
	bcc :write

	lda #$B5    ; square 

:write
	sta (term_ptr),y
	iny
	cpy #8
	txa
	bcc ]lp

	rts

;------------------------------------------------------------------------------

glyphs


c_glyph
	db %01111100
	db %11000110
	db %11000000
	db %11000000
	db %11000000
	db %11000110
	db %01111100
	db %00000000


e_glyph
	db %11111110
	db %11000000
	db %11000000
	db %11111000
	db %11000000
	db %11000000
	db %11111110
	db %00000000

o_glyph
	db %01111100
	db %11000110
	db %11000110
	db %11000110
	db %11000110
	db %11000110
	db %01111100
	db %00000000


p_glyph
	db %11111100
	db %11000110
	db %11000110
	db %11111100
	db %11000000
	db %11000000
	db %11000000
	db %00000000

r_glyph
	db %11111100
	db %11000110
	db %11000110
	db %11111100
	db %11011000
	db %11001100
	db %11000110
	db %00000000


x_glyph
	db %11000110
	db %01101100
	db %00111000
	db %00010000
	db %00111000
	db %01101100
	db %11000110
	db %00000000


run0
	db %00110000
	db %00110000
	db %01100000
	db %01100000
	db %01110000
	db %11100000
	db %01100000
	db %01000000

run1
	db %00110000
	db %00110000
	db %01100000
	db %01100000
	db %01100000
	db %01100000
	db %01100000
	db %01000000

run2
	db %00011000
	db %00011000
	db %00110000
	db %01110000
	db %01111000
	db %00111000
	db %01001000
	db %01000000

run3
	db %00001100
	db %00001100
	db %00111000
	db %01011110
	db %00011000
	db %00100100
	db %01000100
	db %00000100


;------------------------------------------------------------------------------
; put the super basic colors into the text buffer
; so it's consistent
_palette
            adrl  $ff000000
			adrl  $ffffffff
			adrl  $ff880000
			adrl  $ffaaffee
			adrl  $ffcc44cc
			adrl  $ff00cc55
			adrl  $ff0000aa
			adrl  $ffdddd77
			adrl  $ffdd8855
			adrl  $ff664400
			adrl  $ffff7777
			adrl  $ff333333
			adrl  $ff777777
			adrl  $ffaaff66
			adrl  $ff0088ff
			adrl  $ffbbbbbb

;------------------------------------------------------------------------------

