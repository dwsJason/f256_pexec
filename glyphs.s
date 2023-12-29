;
; Glyphs, custom glphs to make pexec pretty
;
;------------------------------------------------------------------------------

	mx %11

	dum 1

G_SPACE ds 1

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
glyph_puts

:pString = term_temp2

	sta :pString
	stx :pString+1

]lp	lda (:pString)
	beq :done
	jsr glyph_draw
	inc :pString
	bne ]lp
	inc :pString+1
	bra ]lp
:done
	rts

;------------------------------------------------------------------------------

glyph_draw
	ldx term_ptr
	phx
	ldx term_ptr+1
	phx

	ldx term_x
	phx
	ldx term_y
	phx

	asl
	asl
	asl
	tax

	; c = 0
	ldy #7

]lp lda glyphs-8,x ;-8 because 0 is terminator
	phy
	phx
	jsr :emit_line
	plx
	ply

	; c=1
	lda term_ptr
	adc #80-1
	sta term_ptr
	lda term_ptr+1
	adc #0
	sta term_ptr+1

	inx
	dey
	bpl ]lp

	plx
	stx term_y
	ply
	sty term_x

	pla
	sta term_ptr+1

	pla
	sta term_ptr

	lda term_ptr
	adc #9 			; c=0
	sta term_ptr
	lda term_ptr+1
	adc #0
	sta term_ptr+1

	rts

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

space_glyph			; useful for "erase"
	db %00000000
	db %00000000
	db %00000000
	db %00000000
	db %00000000
	db %00000000
	db %00000000
	db %00000000


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
	db %00011000
	db %00011000
	db %00110000
	db %00110000
	db %00111000
	db %01110000
	db %00110000
	db %00100000

run1
	db %00011000
	db %00011000
	db %00110000
	db %00110000
	db %00110000
	db %00110000
	db %00110000
	db %00100000

run2
	db %00001100
	db %00001100
	db %00011000
	db %00111000
	db %00111100
	db %00011100
	db %00100100
	db %00100000

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

