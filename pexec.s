;
; Merlin32 Cross Dev Stub for the Jr Micro Kernel
;
; To Assemble "merlin32 -v kexec.s"
;

; Platform-Exec
;
;         Load->Run PGX files
;         Load->Run PGZ files
;         Load->Run KUP files
;         Load-Display 256 Picture files
;         Load-Display LBM Picture files
;  

		mx %11

; some Kernel Stuff
		put kernel_api.s

; Kernel uses MMU configurations 0 and 1
; User programs default to # 3
; I'm going to need 2 & 3, so that I can launch the PGX/PGZ with config #3
;
; and 0-BFFF mapped into 1:1
;

; Picture Viewer Stuff
PIXEL_DATA = $010000	; 320x240 pixels
CLUT_DATA  = $005C00	; 1k color buffer
IMAGE_FILE = $022C00	; try to allow for large files
VKY_GR_CLUT_0 = $D000
VKY_GR_CLUT_1 = $D400

; PGX/PGZ Loaders restrict memory usage to the DirectPage, and Stack
; It would be possible to stuff some code into text buffer, but unsure I need
; that

; Some Global Direct page stuff

; MMU modules needs 0-1F

	dum $20
temp0 ds 4
temp1 ds 4
temp2 ds 4
temp3 ds 4
	dend

	dum $20
PGz_z ds 1
PGz_addr ds 4
PGz_size ds 4
	dend

; Event Buffer at $30
event_type = $30
event_buf  = $31
event_ext  = $32

event_file_data_read  = event_type+kernel_event_event_t_file_data_read
event_file_data_wrote = event_type+kernel_event_event_t_file_wrote_wrote 

; arguments
args_buf = $40
args_buflen = $42

	dum $70
temp7 ds 4
temp8 ds 4
temp9 ds 4
temp10 ds 4
	dend


; copy of the mmu_lock function, down to zero page

mmu_lock_springboard = $80

; File uses $B0-$BF
; Term uses $C0-$CF
; LZSA uses $E0-$EF
; Kernel uses $F0-FF
; I256 uses $F0-FF
; LBM uses $F0-FF

; 8k Kernel Program, so it can live anywhere

		org $A000
		dsk pexec.bin
sig		db $f2,$56		; signature
		db 1            ; 1 8k block
		db 5            ; mount at $a000
		da start		; start here
		db 1			; version
		db 0			; reserved
		db 0			; reserved
		db 0			; reserved
		asc '-' 		; This will require some discussion with Gadget
		db 0
		asc '<file>'	; argument list
		db 0
		asc '"pexec", load and execute file.'	; description
		db 0

start
		; store argument list, but skip over first argument (us)
		lda	kernel_args_ext
		clc
		adc	#2
		sta	args_buf
		lda	kernel_args_ext+1
		adc #0
		sta	args_buf+1

		lda	kernel_args_extlen
		dec
		dec
		sta	args_buflen

		; Terminal Init
		jsr initColors	; default the color palette
		jsr TermInit

		; mmu help functions are alive
		jsr mmu_unlock

		; Program Version
		lda #<txt_version
		ldx #>txt_version
		jsr TermPUTS


		; giant text test

		ldx #16
		ldy #1
		jsr TermSetXY

		lda #<txt_glyph_pexec
		ldx #>txt_glyph_pexec
		jsr glyph_puts

		ldx #0
		ldy #10
		jsr TermSetXY

		; Display what we're trying to do
		lda #<txt_launch
		ldx #>txt_launch
		jsr TermPUTS

		lda	args_buflen
		bne	:has_argument

		lda #<txt_no_argument
		ldx #>txt_no_argument
		jsr TermPUTS

		jmp	wait_for_key

:has_argument		
		; Display the arguments, hopefully there are some
		lda	#'"'
		jsr	TermCOUT
		ldy	#3
		lda (kernel_args_ext),y
		tax
		dey
		lda (kernel_args_ext),y
		jsr TermPUTS
		lda	#'"'
		jsr	TermCOUT
		jsr TermCR

;------------------------------------------------------------------------------
		; Before receiving any Kernel events, we need to have a location
		; to receive them defined
		lda #<event_type
		sta kernel_args_events
		lda #>event_type
		sta kernel_args_events+1
				 
		; Set the drive
		; currently hard-coded to drive 0, since drive not passed
		; stz kernel_args_file_open_drive
		; Set the Filename
		lda	#1
		jsr	get_arg
		jsr fopen
		bcc :opened
		; failed

		pha
		lda #<txt_error_open
		ldx #>txt_error_open
		jsr TermPUTS
		pla

		jsr TermPrintAH
		jsr TermCR

		bra wait_for_key
:opened

		; set address, system memory, to read
		lda #<temp0
		ldx #>temp0
		ldy #0
		jsr set_write_address

		; request 4 bytes
		lda #4
		ldx #0
		ldy #0
		jsr fread

		pha

		jsr fclose

		pla

		cmp #4
		beq :got4

		pha

		lda #<txt_error_reading
		ldx #>txt_error_reading
		jsr TermPUTS

		jsr TermPrintAH
		jsr TermCR

		bra wait_for_key
:got4
		jsr execute_file

		; $$DO SOMETHING

wait_for_key
		lda #<txt_press_key
		ldx #>txt_press_key
		jsr TermPUTS

]loop
		lda #<event_type
		sta kernel_args_events
		lda #>event_type
		sta kernel_args_events+1
]wait
		jsr kernel_NextEvent
		bcs ]wait

		lda event_type
		cmp #kernel_event_key_PRESSED
		beq :done

		;jsr TermPrintAH
		bra ]loop
:done
		jmp mmu_lock
		rts

;------------------------------------------------------------------------------
;
execute_file

; we have the first 4 bytes, let's see if we can
; identify the file
		lda temp0
		cmp #'Z'
		beq :pgZ
		cmp #'z'
		beq :pgz
		cmp #'P'
		beq :pgx
		cmp #'I'
		beq :256
		cmp #'F'
		beq :lbm
		cmp #$F2
		beq :kup
:done
		lda #<txt_unknown
		ldx #>txt_unknown
		jsr TermPUTS

		rts

;------------------------------------------------------------------------------
; Load /run KUP (Kernel User Program)
:kup
		lda temp0+1
		cmp #$56
		bne :done
		lda temp0+2 	; size in blocks
		beq :done   	; size 0, invalid
		cmp #6
		bcs :done       ; size larger than 40k, invalid
		lda temp0+3		; address mapping of block
		beq	:done       ; can't map you in at block 0
		cmp #6
		bcs :done		; can't map you in at block 6 or higher
		jmp LoadKUP

;------------------------------------------------------------------------------
; Load / run pgZ Program
:pgZ
		jmp LoadPGZ
:pgz
		jmp LoadPGz
:pgx
		lda temp0+1
		cmp #'G'
		bne :done
		lda temp0+2
		cmp #'X'
		bne :done
		lda temp0+3
		cmp #3
		bne :done
;------------------------------------------------------------------------------
; Load / Run PGX Program
		jmp LoadPGX

:256
		lda temp0+1
		cmp #'2'
		bne :done
		lda temp0+2
		cmp #'5'
		bne :done
		lda temp0+3
		cmp #'6'
		bne :done
;------------------------------------------------------------------------------
; Load / Display 256 Image
		jsr load_image
		jsr set_srcdest_clut
		jsr decompress_clut
		jsr copy_clut
		jsr init320x240
		jsr set_srcdest_pixels
		jsr decompress_pixels
		rts
;
:lbm
		lda temp0+1
		cmp #'O'
		bne :done
		lda temp0+2
		cmp #'R'
		bne :done
		lda temp0+3
		cmp #'M'
		bne :done
;------------------------------------------------------------------------------
; Load / Display LBM Image

		; get the compressed binary into memory
		jsr load_image

		; Now the LBM is in memory, let's try to decode and show it
		; set src to loaded image file, and dest to clut
		jsr set_srcdest_clut

		jsr lbm_decompress_clut
		jsr copy_clut

		; turn on graphics mode, so we can see the glory
		jsr init320x240

		; get the pixels
		; set src to loaded image file, dest to output pixels
		jsr set_srcdest_pixels
		jsr lbm_decompress_pixels

		rts
;-----------------------------------------------------------------------------
LoadPGX
		lda #<temp0
		ldx #>temp0
		ldy #^temp0
		jsr set_write_address
		
		lda	#1
		jsr	get_arg
		jsr fopen

		lda #8
		ldx #0
		ldy #0
		jsr fread
		
		lda temp1
		ldx temp1+1
		ldy temp1+2
		jsr set_write_address
		
		; Try to read 64k, which should load the whole file
		lda #0
		tax
		ldy #1
		jsr fread

launchProgram
		jsr fclose	; close PGX or PGZ
		
		lda #5
		sta old_mmu0+5	; when lock is called it will map $A000 to physcial $A000

		; need to place a copy of mmu_lock, where it won't be unmapped
		ldx #mmu_lock_end-mmu_unlock
]lp		lda mmu_lock,x
		sta mmu_lock_springboard,x
		dex
		bpl ]lp

		; construct more stub code
		lda #$20   ; jsr mmu_lock_springboard
		sta temp0
		lda #<mmu_lock_springboard
		sta temp0+1
		lda #>mmu_lock_springboard
		sta temp0+2 

		lda #$4c
		sta temp1-1  ; same as temp0+3

		; temp1, and temp1+1 contain the start address

		lda args_buf
		sta kernel_args_ext
		lda args_buf+1
		sta kernel_args_ext+1
		lda args_buflen
		sta kernel_args_extlen
		
		jmp temp0	; will jsr mmu_lock, then jmp to the start

;-----------------------------------------------------------------------------
LoadPGz
		; Open the File again (seek back to 0)
		lda	#1
		jsr	get_arg
		jsr TermPUTS

		lda	#1
		jsr	get_arg
		jsr fopen
		
		lda #<PGz_z
		ldx #>PGz_z
		ldy #^PGz_z
		jsr set_write_address
		
		lda #9
]loop
		ldx #0
		ldy #0
		jsr fread
		
		lda PGz_size
		ora PGz_size+1
		ora PGz_size+2
		ora PGz_size+3
		beq pgzDoneLoad
		
		lda PGz_addr
		ldx PGz_addr+1
		ldy PGz_addr+2
		jsr set_write_address

		lda PGz_size
		ldx PGz_size+1
		ldy PGz_size+2
		jsr fread
		
		lda #<PGz_addr
		ldx #>PGz_addr
		ldy #^PGz_addr
		jsr set_write_address
		lda #8
		bra ]loop

;-----------------------------------------------------------------------------
LoadPGZ
		; Open the File again (seek back to 0)
		lda	#1
		jsr	get_arg
		jsr TermPUTS

		lda	#1
		jsr	get_arg
		jsr fopen
		
		lda #<temp0
		ldx #>temp0
		ldy #^temp0
		jsr set_write_address
		
		lda #7
]loop
		ldx #0
		ldy #0
		jsr fread
		
		lda temp1
		ora temp1+1
		ora temp1+2
		beq pgzDoneLoad
		
		lda temp0+1
		ldx temp0+2
		ldy temp0+3
		jsr set_write_address

		lda temp1
		ldx temp1+1
		ldy temp1+2
		jsr fread
		
		lda #<temp0+1
		ldx #>temp0+1
		ldy #^temp0+1
		jsr set_write_address
		lda #6
		bra ]loop

pgzDoneLoad

		; copy the start location, for the launch code fragment 
		lda temp0+1
		sta temp1
		lda temp0+2
		sta temp1+1

		jmp launchProgram  ; share cleanup with PGX launcher

;-----------------------------------------------------------------------------
; Load /run KUP (Kernel User Program)
LoadKUP
		; Open the File again (seek back to 0)
		lda	#1
		jsr	get_arg
		jsr TermPUTS

		lda	#1
		jsr	get_arg
		jsr fopen 

; Set the address where we read data

		lda temp0+3 ; mount address
		clc
		ror
		ror
		ror
		ror
		tax
		lda #0
		tay

		sta temp0		; start address of where we're loading
		stx temp0+1

		jsr set_write_address

; Now ask for data from the file, let's be smart here, and ask for the
; max conceivable size that will fit.

		sec
		lda #$C0
		sbc temp0+1
		tax			; Should yield $A000 as largest possible address
		lda #0      ;
		tay
		jsr fread

		ldy #4
		lda (temp0),y
		sta temp1
		iny
		lda (temp0),y
		sta temp1+2

		jmp launchProgram	; close, fix mmu, start


;-----------------------------------------------------------------------------
load_image
; $10000, for the bitmap

		; Open the File again (seek back to 0)
		lda	#1
		jsr	get_arg
		jsr TermPUTS

		lda	#1
		jsr	get_arg
		jsr fopen

		; Address where we're going to load the file
		lda #<IMAGE_FILE
		ldx #>IMAGE_FILE
		ldy #^IMAGE_FILE
		jsr set_write_address

		; Request as many bytes as we can, and hope we hit the EOF
READ_BUFFER_SIZE = $080000-IMAGE_FILE

		lda #<READ_BUFFER_SIZE
		ldx #>READ_BUFFER_SIZE
		ldy #^READ_BUFFER_SIZE
		jsr fread
		; length read is in AXY, if we need it
		jsr fclose

		rts
;-----------------------------------------------------------------------------
set_srcdest_clut
		; Address where we're going to load the file
		lda #<IMAGE_FILE
		ldx #>IMAGE_FILE
		ldy #^IMAGE_FILE
		jsr set_read_address

		lda #<CLUT_DATA
		ldx #>CLUT_DATA
		ldy #^CLUT_DATA
		jsr set_write_address
		rts
;-----------------------------------------------------------------------------
set_srcdest_pixels
		lda #<IMAGE_FILE
		ldx #>IMAGE_FILE
		ldy #^IMAGE_FILE
		jsr set_read_address

		lda #<PIXEL_DATA
		ldx #>PIXEL_DATA
		ldy #^PIXEL_DATA
		jsr set_write_address
		rts
;-----------------------------------------------------------------------------

copy_clut
		php
		sei

		; set access to vicky CLUTs
		lda #1
		sta io_ctrl
		; copy the clut up there
		ldx #0
]lp		lda CLUT_DATA,x
		sta VKY_GR_CLUT_0,x
		lda CLUT_DATA+$100,x
		sta VKY_GR_CLUT_0+$100,x
		lda CLUT_DATA+$200,x
		sta VKY_GR_CLUT_0+$200,x
		lda CLUT_DATA+$300,x
		sta VKY_GR_CLUT_0+$300,x
		dex
		bne ]lp

		; set access back to text buffer, for the text stuff
		lda #2
		sta io_ctrl

		plp
		rts

;-----------------------------------------------------------------------------
; Setup 320x240 mode
init320x240
		php
		sei

		; Access to vicky generate registers
		stz io_ctrl

		; enable the graphics mode
		lda #%00001111	; gamma + bitmap + graphics + overlay + text
;		lda #%00000001	; text
		sta $D000
		;lda #%110       ; text in 40 column when it's enabled
		;sta $D001
		stz $D001

		; layer stuff - take from Jr manual
		stz $D002  ; layer ctrl 0
		stz $D003  ; layer ctrl 3

		; set address of image, since image uncompressed, we just display it
		; where we loaded it.
		lda #<PIXEL_DATA
		sta $D101
		lda #>PIXEL_DATA
		sta $D102
		lda #^PIXEL_DATA
		sta $D103

		lda #1
		sta $D100  ; bitmap enable, use clut 0
		stz $D108  ; disable
		stz $D110  ; disable

		lda #2
		sta io_ctrl
		plp

		rts

;------------------------------------------------------------------------------
; Get argument
; A - argument number
;
; Returns string in AX

get_arg
		asl
		tay
		iny
		lda (kernel_args_ext),y
		tax
		dey
		lda (kernel_args_ext),y
		rts


;------------------------------------------------------------------------------
; Strings and other includes
txt_version asc 'Pexec 0.6'
		db 13,13,0

txt_press_key db 13
		asc '--- Press >ENTER< to continue ---'
		db 13,0
		
txt_unknown
		asc 'Unknown application type'
		db 13,13,0		

txt_launch asc 'launch: '
		db 0

txt_error_open asc 'ERROR: file open $'
		db 0
txt_error_notfound asc 'ERROR: file not found: '
		db 0
txt_error_reading asc 'ERROR: reading $'
		db 0
txt_error asc 'ERROR!'
		db 13
		db 0
txt_open asc 'Open Success!'
		db 13
		db 0
txt_no_argument asc 'Missing file argument'
		db 13
		db 0

txt_glyph_pexec
		db GP,GE,GX,GE,GC,0

;------------------------------------------------------------------------------
		put mmu.s
		put term.s
		put lbm.s
		put i256.s
		put lzsa2.s
		put file.s
		put glyphs.s
		put colors.s

; pad to the end
		ds $C000-*,$EA
; really pad to end, because merlin is buggy
		ds \,$EA
