;
; Terminal Module for Jr
;
		mx %11

TextBuffer = $C000

; Terminal Variables
	dum $C0
term_width  ds 1
term_height ds 1
term_x      ds 1
term_y      ds 1
term_ptr    ds 2
term_temp0  ds 4
term_temp1  ds 4
term_temp2  ds 2
	dend

;TermCOUT       - COUT, prints character in A, right now only special character code #13 is supported <cr>
;TermPUTS       - AX is a pointer to a 0 terminated string, this function will send the characters into COUT  
;TermPrintAN    - print nybble value in A
;TermPrintAH    - print value in A, as HEX
;TermPrintAI    - print value in A, as DEC
;TermPrintAXH   - print value in AX, as HEX  (it will end up XA, because high, then low)
;TermPrintAXI   - print value in AX, as DEC
;TermPrintAXYH  - print values in AXY, as HEX
;TermSetXY      - cursor position X in X, Y in Y

;------------------------------------------------------------------------------
TermInit
		jsr TermClearTextBuffer

		stz term_x
		stz term_y
		lda #80
		sta term_width
		lda #60
		sta term_height

		lda #<TextBuffer
		sta term_ptr
		lda #>TextBuffer
		sta term_ptr+1

		rts

;------------------------------------------------------------------------------
; ldx #XX
; ldy #YY
TermSetXY
		stx term_x
		sty term_y

		txa
		clc
		adc Term80Table_lo,y
		sta term_ptr
		lda #0
		adc Term80Table_hi,y
		sta term_ptr+1
		rts

;------------------------------------------------------------------------------
TermCR  lda #13
;------------------------------------------------------------------------------
TermCOUT
		cmp #13
		beq :cr

		sta (term_ptr)
		inc term_ptr
		bne :skiphi
		inc term_ptr+1
:skiphi
		lda term_x
		inc
		cmp term_width
		bcc :x
:incy
		lda term_y
		inc
		cmp term_height
		bcs :scroll_savexy
:y      sta term_y

		lda #0
:x		sta term_x
		rts

:cr
		phy
		phx
		lda term_y
		inc
		cmp term_height
		bcs :scroll
		tay
		ldx #0
		jsr TermSetXY
		plx
		ply
		rts
:scroll_savexy
		phy
		phx
:scroll
:pSrc = term_temp0
:pDst = term_temp0+2

		stz :pDst
		lda #80
		sta :pSrc
		lda #>TextBuffer
		sta :pDst+1
		sta :pSrc+1

		ldx term_height
		dex
]lp
		ldy #0
]inlp
		lda (:pSrc),y
		sta (:pDst),y
		iny
		cpy term_width
		bcc ]inlp

		clc
		lda :pSrc
		sta :pDst
		adc term_width
		sta :pSrc
		lda :pSrc+1
		sta :pDst+1
		adc #0
		sta :pSrc+1

		dex
		bne ]lp

; clear line
		ldy #0
		lda #' '
]lclrp  sta (:pDst),y
		iny
		cpy term_width
		bcc ]lclrp

		ldx #0
		ldy term_height
		dey
		jsr TermSetXY
		plx
		ply
		rts

;------------------------------------------------------------------------------
; Fill Text Buffer with spaces

TermClearTextBuffer
		stz	io_ctrl
		stz	$D010			; disable cursor

		lda #3
		sta io_ctrl         ; swap in the color memory
		;lda $C000			; get current color attribute
		lda #$F2	; white on blue
		jsr	:clear

; We need a rainbow up top

		ldx #79
]cloop  lda #$12  			; red
		sta $C000+{80*1},x
		lda #$92			; orange
		sta $C000+{80*2},x
		lda #$D2			; yello
		sta $C000+{80*3},x
		lda #$C2			; green
		sta $C000+{80*4},x
		lda #$72			; bright blue
		sta $C000+{80*5},x
		lda #$32		   	; purple
		sta $C000+{80*6},x
		lda #$B2		  	; pink
		sta $C000+{80*7},x
		dex
		bpl ]cloop

		lda #2
		sta io_ctrl         ; swap in the text memory
		lda #' '

:clear
		ldx #0

]lp
		sta $C000,x
		sta $C100,x
		sta $C200,x
		sta $C300,x
		sta $C400,x
		sta $C500,x
		sta $C600,x
		sta $C700,x
		sta $C800,x
		sta $C900,x
		sta $CA00,x
		sta $CB00,x
		sta $CC00,x
		sta $CD00,x
		sta $CE00,x
		sta $CF00,x
		sta $D000,x
		sta $D100,x
		sta $D200,x
		dex
		bne ]lp

		rts

;------------------------------------------------------------------------------

Term80Table_lo
]var = TextBuffer
		lup 60
		db #<]var
]var = ]var+80
		--^

Term80Table_hi
]var = TextBuffer
		lup 60
		db #>]var
]var = ]var+80
		--^

;------------------------------------------------------------------------------
TermPUTS
:pString = term_temp2
		sta :pString
		stx :pString+1

]lp		lda (:pString)
		beq :done
		jsr TermCOUT
		inc :pString
		bne ]lp
		inc :pString+1
		bra ]lp
:done
		rts

;------------------------------------------------------------------------------
;TermPrintAXH   - print value in AX, as HEX  (it will end up XA, because high, then low)
TermPrintAXYH
		pha
		phx
		tya
		jsr TermPrintAH
		pla
		jsr TermPrintAH
		pla
;		bra TermPrintAH

;------------------------------------------------------------------------------
;TermPrintAH    - print value in A, as HEX
TermPrintAH
		pha
		lsr
		lsr
		lsr
		lsr
		tax
		lda Term_chars,x
		jsr TermCOUT
		pla
		and #$0F
		tax
		lda Term_chars,x
		jmp TermCOUT

Term_chars  ASC '0123456789ABCDEF'

;TermPrintAN    - print nybble value in A
TermPrintAN
		and #$0F
		tax
		lda Term_chars,x
		jmp TermCOUT

;------------------------------------------------------------------------------
;TermPrintAXH   - print value in AX, as HEX  (it will end up XA, because high, then low)
TermPrintAXH
		pha
		txa
		jsr TermPrintAH
		pla
		bra TermPrintAH

;------------------------------------------------------------------------------
;TermPrintAI    - print value in A, as DEC
TermPrintAI
:bcd = term_temp1
		jsr BINBCD8
		lda :bcd+1
		and #$0F
		beq :skip
		jsr TermPrintAN
		lda :bcd
		bra TermPrintAH
:skip
		lda :bcd
		and #$F0
		beq :single_digit
		lda :bcd
		bra TermPrintAH

:single_digit
		lda :bcd
		bra TermPrintAN
		rts
;------------------------------------------------------------------------------
;TermPrintAXI   - print value in AX, as DEC
TermPrintAXI
:bcd = term_temp1
		jsr BINBCD16

		lda :bcd+2
		and #$0F
		beq :skip1

		; 5 digits
		jsr TermPrintAN
:digit4
		lda :bcd
		ldx :bcd+1
		bra TermPrintAXH
:skip1
		lda :bcd+1
		beq :skip2

		and #$F0
		bne :digit4

		lda :bcd+1
		jsr TermPrintAN  ; just the nybble
		lda :bcd
		bra TermPrintAH

:skip2
		lda :bcd
		and #$F0
		beq :single_digit
		lda :bcd
		jmp TermPrintAH

:single_digit
		lda :bcd
		bra TermPrintAN
		rts
;------------------------------------------------------------------------------
; Andrew Jacobs, 28-Feb-2004
BINBCD8	
:bin = term_temp0
:bcd = term_temp1
		sta :bin
		SED		; Switch to decimal mode
		stz :bcd+0
		stz :bcd+1
		LDX #8		; The number of source bits

]CNVBIT	ASL :bin	; Shift out one bit
		LDA :bcd+0	; And add into result
		ADC :bcd+0
		STA :bcd+0
		LDA :bcd+1	; propagating any carry
		ADC :bcd+1
		STA :bcd+1
		DEX		; And repeat for next bit
		BNE ]CNVBIT
		CLD		; Back to binary
		rts

; Convert an 16 bit binary value to BCD
;
; This function converts a 16 bit binary value into a 24 bit BCD. It
; works by transferring one bit a time from the source and adding it
; into a BCD value that is being doubled on each iteration. As all the
; arithmetic is being done in BCD the result is a binary to decimal
; conversion. All conversions take 915 clock cycles.
;
; See BINBCD8 for more details of its operation.
;
; Andrew Jacobs, 28-Feb-2004

BINBCD16 
:bin = term_temp0
:bcd = term_temp1
		sta :bin
		stx :bin+1

		SED		; Switch to decimal mode
		stz :bcd+0
		stz :bcd+1
		stz :bcd+2
		LDX #16		; The number of source bits

]CNVBIT	ASL :bin+0	; Shift out one bit
		ROL :bin+1
		LDA :bcd+0	; And add into result
		ADC :bcd+0
		STA :bcd+0
		LDA :bcd+1	; propagating any carry
		ADC :bcd+1
		STA :bcd+1
		LDA :bcd+2	; ... thru whole result
		ADC :bcd+2
		STA :bcd+2
		DEX		; And repeat for next bit
		BNE ]CNVBIT
		CLD		; Back to binary

		rts

