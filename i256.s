;
; 65c02 Foenix I256 file format parser utils
; for F256 Jr
;
; https://docs.google.com/document/d/10ovgMClDAJVgbW0sOhUsBkVABKWhOPM5Au7vbHJymoA/edit?usp=sharing
;
		mx %11


DEBUG_F256 = 0

; error codes
		dum $0
i256_no_error         ds 1   ; 0 = no error
i256_error_badheader  ds 1   ; 1 = something is not good with the header
i256_error_noclut     ds 1   ; 2 = There's no CLUT in this file
i256_error_nopixels   ds 1   ; 3 = There are no PIXL in this file
		dend

		dum $F0
i256_FileLength ds 0
i256_pChunk     ds 0
i256_temp0      ds 4

i256_blobCount  ds 0
i256_colorCount ds 0
i256_temp1      ds 2

i256_FileStart  ds 3
i256_Width      ds 2
i256_Height     ds 2
i256_EOF        ds 3
		dend

;
; This works with the mmu utils, and the lzsa2 decompressor
; Addresses are in System Memory BUS space
;
; set_read_address  - the source address for the image.256 file
; set_write_address - the destination address of the clut data
;
; if c=0, then operation success
; if c=1, then operation fail, error code in A
;
decompress_clut
		jsr c256init
		bcs :error

		do DEBUG_F256
		lda #<decompress_clut
		ldx #>decompress_clut
		jsr FindChunk

		sta i256_pChunk
		stx i256_pChunk+1
		sty i256_pChunk+2

		ora i256_pChunk+1
		ora i256_pChunk+2
		beq :pass
		lda #4
		sec
		rts
:pass
		fin

		lda #<CHNK_CLUT
		ldx #>CHNK_CLUT
		jsr FindChunk

		sta i256_pChunk
		stx i256_pChunk+1
		sty i256_pChunk+2

		ora i256_pChunk+1
		ora i256_pChunk+2
		bne :hasClut

		lda #i256_error_noclut
		sec
:error
		rts

:hasClut
		; add 8 bytes, to skip up to color count
		clc
		lda i256_pChunk
		adc #8
		sta i256_pChunk
		lda i256_pChunk+1
		adc #0
		sta i256_pChunk+1
		lda i256_pChunk+2
		adc #0
		sta i256_pChunk+2

		lda i256_pChunk
		ldx i256_pChunk+1
		ldy i256_pChunk+2
		jsr set_read_address

		jsr readbyte
		sta i256_colorCount
		jsr readbyte
		sta i256_colorCount+1
		bit #$80
		bne :compressed

		ldx i256_colorCount
		tay  ; colorCount+1
]raw
		; copy 1 color
		jsr readbyte
		jsr writebyte
		jsr readbyte
		jsr writebyte
		jsr readbyte
		jsr writebyte
		jsr readbyte
		jsr writebyte
		txa
		bne :lo
		dey
		bmi :done
:lo 	dex
		bra ]raw
:compressed
		and #$7F
		sta i256_colorCount+1

		jsr lzsa2_unpack
:done
		clc
		lda #0
		rts

;------------------------------------------------------------------------------
;
; This works with the mmu utils, and the lzsa2 decompressor
; Addresses are in System Memory BUS space
;
; set_read_address  - the source address for the image.256 file
; set_write_address - the destination address of the pixels data
;
; if c=0, then operation success
; if c=1, then operation fail, error code in A
;
decompress_pixels
		jsr c256init
		bcs :error
:error
		lda #<CHNK_PIXL
		ldx #>CHNK_PIXL
		jsr FindChunk

		sta i256_pChunk
		stx i256_pChunk+1
		sty i256_pChunk+2

		ora i256_pChunk+1
		ora i256_pChunk+2
		bne :hasPixel

		lda #i256_error_nopixels
		sec
:error
		rts
:hasPixel
		; add 8 bytes, to skip up to color count
		clc
		lda i256_pChunk
		adc #8
		sta i256_pChunk
		lda i256_pChunk+1
		adc #0
		sta i256_pChunk+1
		lda i256_pChunk+2
		adc #0
		sta i256_pChunk+2

		lda i256_pChunk
		ldx i256_pChunk+1
		ldy i256_pChunk+2
		jsr set_read_address

		; realistically, blob count can't be bigger than 255
		jsr readbyte
		sta i256_blobCount
		jsr readbyte  	 		; really don't care about the high byte, it's there for 816
		sta i256_blobCount+1

:size = i256_temp0
]loop
		jsr readbyte
		sta :size
		jsr readbyte
		sta :size+1
		ora :size
		bne :compressed

		; Raw 64k Blob
		ldx #0
		ldy #0
]lp
		jsr readbyte
		jsr writebyte
		dex
		bne ]lp
		dey
		bne ]lp
		bra :blob

:compressed
		jsr lzsa2_unpack

:blob
		dec i256_blobCount
		bne ]loop

		clc
		lda #0	; return no error

		rts

;
; set_read_address - the source address for the image.256 file
;
; Output in the Kernel Args at $F0
;
; $F0,$F1 - width     - 2 bytes
; $F2,$F3 - height    - 2 bytes
; $F4,$F5 - numcolors - 2 bytes
;
; if c=0, then operation success
; if c=1, then operation fail, error code in A
;
image_info
		rts

;------------------------------------------------------------------------------
;
; This verifies that the image is looking like it should
; c=0 all good
; c=1 not good, error code in A
;
c256init
		;jsr get_read_address

		jsr c256ParseHeader
		bcc :isGood

		sec
		lda #i256_error_badheader
		rts

:isGood
		lda #<CHNK_CLUT
		ldx #>CHNK_CLUT
		jsr FindChunk

		sta i256_pChunk
		stx i256_pChunk+1
		sty i256_pChunk+2

		ora i256_pChunk+1
		ora i256_pChunk+2
		bne :hasClut

		lda #i256_error_noclut
		sec
		rts

:hasClut
		lda #<CHNK_PIXL
		ldx #>CHNK_PIXL
		jsr FindChunk

		sta i256_pChunk
		stx i256_pChunk+1
		sty i256_pChunk+2

		ora i256_pChunk+1
		ora i256_pChunk+2
		bne :hasPixels

		lda #i256_error_nopixels
		sec
		rts

:hasPixels
		clc
		lda #i256_no_error
		rts

;------------------------------------------------------------------------------
;
; FindChunk
; mmu read address as the pointer to where to start searching
;
;  AX = pointer to the chunk name to be searching for
;
;  Return: AXY pointer to chunk on memory bus
;
FindChunk
:pTag = i256_temp1
:temp = i256_temp0
		sta :pTag
		stx :pTag+1
		do DEBUG_F256
		lda #<txt_FindChunk
		ldx #>txt_FindChunk
		jsr TermPUTS
		fin
		jsr get_read_address

		phy
		phx
		pha
]loop
		do DEBUG_F256
		jsr DebugTag
		jsr DebugAXY
		fin

		phy
		phx
		pha

		cpy i256_EOF+2
		bcc :continue
		bne :nullptr
        cpx i256_EOF+1
		bcc :continue
		bne :nullptr
        cmp i256_EOF
		bcs :nullptr

:continue
		jsr set_read_address

		jsr readbyte
		sta :temp
		jsr readbyte
		sta :temp+1
		jsr readbyte
		sta :temp+2
		jsr readbyte
		sta :temp+3

		ldy #3
]lp     lda (:pTag),y
		cmp :temp,y
		bne :nextChunk
		dey
		bpl ]lp
		
		pla
		plx
		ply
		sta :temp
		stx :temp+1
		sty :temp+2

		pla
		plx
		ply
		jsr set_read_address

		lda :temp
		ldx :temp+1
		ldy :temp+2

		rts
:nextChunk

		pla
		plx
		ply
		sta :temp
		stx :temp+1
		sty :temp+2

		jsr readbyte
		clc
		adc :temp
		sta :temp
		php
		jsr readbyte
		plp
		adc :temp+1
		sta :temp+1
		php
		jsr readbyte
		plp
		adc :temp+2
		sta :temp+2
		jsr readbyte  ; if throw away 4th byte

		lda :temp
		ldx :temp+1
		ldy :temp+2
		;jsr set_read_address
		bra ]loop


:nullptr
		pla
		plx
		ply

		pla
		plx
		ply

		jsr set_read_address

		lda #0
		tax
		tay

		rts

;------------------------------------------------------------------------------
;
;  mmu read address, should be set point at the header
;
;	char 			i,2,5,6;  // 'I','2','5','6'
;
;	unsigned int 	file_length;  // In bytes, including the 16 byte header
;
;	short			version;  // 0x0000 for now
;	short			width;	  // In pixels
;	short			height;	  // In pixels
;   short           reserved;
;
c256ParseHeader
		jsr get_read_address
		sta i256_FileStart
		stx i256_FileStart+1
		sty i256_FileStart+2

        ; Check for 'I256'
		lda #<CHNK_I256
		ldx #>CHNK_I256
		jsr IFF_Verify
		bcs :BadHeader

        ; Copy out FileLength
		ldx #0
]lp		jsr readbyte
		sta i256_FileLength,x
		inx
		cpx #4
		bcc ]lp

        ; Compute the end of file address
        clc
        lda <i256_FileStart
        adc <i256_FileLength
        sta <i256_EOF

        lda <i256_FileStart+1
        adc <i256_FileLength+1
        sta <i256_EOF+1

        lda <i256_FileStart+2
        adc <i256_FileLength+2
        sta <i256_EOF+2
        bcs :BadHeader          ; overflow on memory address

		lda <i256_FileLength+3
		bne :BadHeader

        ; Look at the File Version
		jsr readbyte
		cmp #0  	    ; current
		bne :BadHeader
		jsr readbyte
		cmp #0
		bne :BadHeader  ; currently only supports version 0

        ; Get the width and height
		jsr readbyte
		sta i256_Width
		jsr readbyte
		sta i256_Width+1

		jsr readbyte
		sta i256_Height
		jsr readbyte
		sta i256_Height+1

        ; Reserved
        jsr readbyte
        jsr readbyte

        ; c=0 mean's there's no error
		clc
        rts

:BadHeader
		lda i256_FileStart
		ldx i256_FileStart+1
		ldy i256_FileStart+2
		jsr set_read_address

        sec     ; c=1 means there's an error
        rts

;------------------------------------------------------------------------------
; mmu read address is pointer to the source
;
; AX is pointer the IFF tag we want to compare
; Y is not preserved
IFF_Verify
:pIFF = i256_temp1
		ldy #0
		sta :pIFF
		stx :pIFF+1
]lp		jsr readbyte
		cmp (:pIFF),y
		bne :fail
		iny
		cpy #4
		bcc ]lp
		clc
		rts

:fail	
		sec
		rts

;------------------------------------------------------------------------------
		do DEBUG_F256
DebugAXY
		pha
		phx
		phy

		phx
		pha
		tya
		jsr TermPrintAH
		pla
		plx
		jsr TermPrintAXH
		jsr TermCR

		ply
		plx
		pla

		rts
		fin
;------------------------------------------------------------------------------
		do DEBUG_F256
DebugTag
:pTag = i256_temp1
		pha
		phx
		phy
		lda #<txt_tag
		ldx #>txt_tag
		jsr TermPUTS
		lda :pTag
		ldx :pTag+1
		jsr TermPrintAXH
		jsr TermCR

		lda #<txt_eof
		ldx #>txt_eof
		jsr TermPUTS

		lda i256_EOF+2
		jsr TermPrintAH
		lda i256_EOF
		ldx i256_EOF+1
		jsr TermPrintAXH
		jsr TermCR

		ply
		plx
		pla
		rts
		fin

;------------------------------------------------------------------------------


CHNK_CLUT asc 'CLUT'
CHNK_PIXL asc 'PIXL'
CHNK_I256 asc 'I256'


		do DEBUG_F256

txt_tag asc 'tag='
			db 0
txt_FindChunk asc 'FindChunk - '
			db 0

txt_eof asc 'EOF='
			db 0
		fin
