;
; 65c02 Foenix LBM file format parser utils
; for F256 Jr
;
		mx %11

; error codes
		dum $0
lbm_no_error         ds 1   ; 0 = no error
lbm_error_notlbm     ds 1   ; 1 = not an LBM file
lbm_error_notpbm     ds 1   ; 2 = not an LBM with 8 bit packed pixels
lbm_error_noclut     ds 1   ; 3 = There's no CLUT in this file
lbm_error_nopixels   ds 1   ; 4 = There are no PIXL in this file
		dend


		dum $F0
lbm_ChunkLength ds 0
lbm_FileLength ds 0
lbm_pChunk     ds 0
lbm_temp0      ds 4

lbm_pTag       ds 0
lbm_temp1      ds 2

lbm_FileStart  ds 3
lbm_Width      ds 2
lbm_Height     ds 2
lbm_EOF        ds 3
		dend

;------------------------------------------------------------------------------
;
; This works with the mmu utils
; Addresses are in System Memory BUS space
;
; set_read_address  - the source address for the image.lbm
; set_write_address - the destination address of the clut data
;
;  This will massage the LBM clut data into something that works on Jr
;
; if c=0, then operation success
; if c=1, then operation fail, error code in A
;
lbm_decompress_clut
		jsr lbm_init
		bcc :good
		rts				; error, error code in A
:good
		lda #<CHNK_CMAP
		ldx #>CHNK_CMAP
		jsr lbm_FindChunk

		sta lbm_pChunk
		stx lbm_pChunk+1
		sty lbm_pChunk+2

		; Check for nullptr
		ora lbm_pChunk+1
		ora lbm_pChunk+2
		bne :got_pal

		sec
		lda #lbm_error_noclut
		rts

:got_pal

		ldx #0
]lp		jsr readbyte  ; r
		sta lbm_temp0
		jsr readbyte  ; g
		sta lbm_temp0+1
		jsr readbyte  ; b
		sta lbm_temp0+2

		jsr writebyte  ; b
		lda lbm_temp0+1
		jsr writebyte  ; g
		lda lbm_temp0
		jsr writebyte  ; r
		lda #$FF
		jsr writebyte  ; a
		dex
		bne ]lp

		clc
		lda #lbm_no_error
		rts

;------------------------------------------------------------------------------
;
; This works with the mmu utils
; Addresses are in System Memory BUS space
;
; set_read_address  - the source address for the image.lbm
; set_write_address - the destination address of the pixel data
;
; if c=0, then operation success
; if c=1, then operation fail, error code in A
;
lbm_decompress_pixels
		jsr lbm_init
		bcc :good
		rts				; error, error code in A
:good
		lda #<CHNK_BODY
		ldx #>CHNK_BODY
		jsr lbm_FindChunk

		sta lbm_pChunk
		stx lbm_pChunk+1
		sty lbm_pChunk+2

		; Check for nullptr
		ora lbm_pChunk+1
		ora lbm_pChunk+2
		bne :got_body

		sec
		lda #lbm_error_nopixels
		rts

:got_body

:width = lbm_temp0
:height = lbm_temp0+2

		stz :height
		stz :height+1

]height_loop
		stz :width
		stz :width+1

]width_loop

		jsr readbyte
		tax
		bpl :copy
		; rle
		eor #$FF
		inc
		tax
		jsr readbyte
]rle	jsr writebyte
		inc :width
		bne :nx
		inc :width+1
:nx
		dex
		bpl ]rle

:wid_height
		lda :width+1
		cmp lbm_Width+1
		bne ]width_loop
		lda :width
		cmp lbm_Width
		bne ]width_loop

		inc :height
		bne :nh
		inc :height+1
:nh


		lda :height+1
		cmp lbm_Height+1
		bne ]height_loop
		lda :height
		cmp lbm_Height
		bne ]height_loop

		clc
		lda #0
		rts

:copy
		jsr readbyte
		jsr writebyte

		inc :width
		bne :nx2
		inc :width+1
:nx2
		dex
		bpl :copy

		bra :wid_height

;------------------------------------------------------------------------------


CHNK_FORM asc 'FORM'
CHNK_PBM  asc 'PBM '
CHNK_BMHD asc 'BMHD'
CHNK_CMAP asc 'CMAP'
CHNK_BODY asc 'BODY'

;------------------------------------------------------------------------------

;
; This works with the mmu utils
; Addresses are in System Memory BUS space
;
; set_read_address  - the source address for the image.lbm
; set_write_address - the destination address of the pixel data
;
lbm_init
		lda #<CHNK_FORM
		ldx #>CHNK_FORM
		jsr lbm_CheckTag
		bcc :good
		lda #lbm_error_notlbm
		rts
:good
		jsr lbm_chnklen

		jsr get_read_address

		; Need to set EOF, so FindChunk knows where to stop
		clc
		adc lbm_ChunkLength
		sta lbm_EOF+0
		txa
		adc lbm_ChunkLength+1
		sta lbm_EOF+1
		tya
		adc lbm_ChunkLength+2
		sta lbm_EOF+2

		lda #<CHNK_PBM
		ldx #>CHNK_PBM
		jsr lbm_CheckTag
		bcc :pbm
:not_pbm
		lda #lbm_error_notpbm
		rts
:pbm
		lda #<CHNK_BMHD
		ldx #>CHNK_BMHD
		jsr lbm_CheckTag
		bcs :not_pbm

		jsr lbm_chnklen
		jsr lbm_nextchunk_address ; pChunk will hold next chunk address


		; Width
		jsr readbyte
		sta lbm_Width+1
		jsr readbyte
		sta lbm_Width

		;Height
		jsr readbyte
		sta lbm_Height+1
		jsr readbyte
		sta lbm_Height


		lda lbm_pChunk
		ldx lbm_pChunk+1
		ldy lbm_pChunk+2

		jsr set_read_address

		clc
		rts
;------------------------------------------------------------------------------
;
; AX = address of tag to check
;
; c=0 match
; c=1 does not match
;
lbm_CheckTag
		sta lbm_pTag
		stx lbm_pTag+1
lbm_CheckTag2
		jsr readbyte
		sta lbm_temp0

;		jsr TermCOUT

		jsr readbyte
		sta lbm_temp0+1

;		jsr TermCOUT

		jsr readbyte
		sta lbm_temp0+2

;		jsr TermCOUT

		jsr readbyte
		sta lbm_temp0+3

;		jsr TermCOUT
;		jsr TermCR

		ldy #3
]lp		lda (lbm_pTag),y
		cmp lbm_temp0,y
		bne :error
		dey
		bpl ]lp
		clc
		rts

:error
		sec
		rts

;------------------------------------------------------------------------------
lbm_chnklen
		jsr readbyte
		sta lbm_ChunkLength+3
		jsr readbyte
		sta lbm_ChunkLength+2
		jsr readbyte
		sta lbm_ChunkLength+1
		jsr readbyte
		sta lbm_ChunkLength+0

		bit #1
		beq :even

		; EA I hate you
		inc lbm_ChunkLength+0
		bne :done
		inc lbm_ChunkLength+1
		bne :done
		inc lbm_ChunkLength+2
:even
:done
		rts

;------------------------------------------------------------------------------
lbm_nextchunk_address
		jsr get_read_address
		clc
		adc lbm_pChunk
		sta lbm_pChunk
		txa
		adc lbm_pChunk+1
		sta lbm_pChunk+1
		tya
		adc lbm_pChunk+2
		sta lbm_pChunk+2

;		jsr TermPrintAH
;		lda lbm_pChunk+0
;		ldx lbm_pChunk+1
;		jsr TermPrintAXH
;		jsr TermCR

		rts
;------------------------------------------------------------------------------
lbm_FindChunk
		sta lbm_pTag
		stx lbm_pTag+1

]loop
		jsr get_read_address

		cpy lbm_EOF+2
		bcc :continue
		bne :nullptr
        cpx lbm_EOF+1
		bcc :continue
		bne :nullptr
        cmp lbm_EOF
		bcs :nullptr
:continue
		jsr lbm_CheckTag2
		php
		jsr lbm_chnklen
		plp
		bcs :not_found

		jsr get_read_address
		rts				 ; found it
:not_found
		jsr lbm_nextchunk_address

		;jsr get_read_address
		;clc
		;adc lbm_ChunkLength
		;sta lbm_ChunkLength

		;txa
		;adc lbm_ChunkLength+1
		;sta lbm_ChunkLength+1

		;tya
		;adc lbm_ChunkLength+2
		;sta lbm_ChunkLength+2

		lda lbm_ChunkLength
		ldx lbm_ChunkLength+1
		ldy lbm_ChunkLength+2

		jsr set_read_address

		bra ]loop

:nullptr
		lda #0
		tax
		tay
		rts
;------------------------------------------------------------------------------

