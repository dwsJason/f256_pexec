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

	dum $60
temp7 ds 4
temp8 ds 4
temp9 ds 4
temp10 ds 4

progress ds 2     ; progress counter
show_prompt ds 1  ; picture viewer can hide the press key prompt

pArg ds 2
pExt ds 2		  ; used by the alternate_open
	dend


	dum $400
scratch_path ds 256
try_count ds 1
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
		beq :zero_args				; validation, this should not be zero, but we'll accept it
		dec
		dec 						; subtract 2 - we get rid of "pexec" from the args list
		bmi :zero_args              ; this is supposed to be positive
		bit #1  		
		bne :zero_args				; this is expected to be even

		sta	args_buflen 			; we've done some reasonable validation here
		bra :seems_good_args

:zero_args
		stz args_buflen
		stz kernel_args_extlen

:seems_good_args

		; Some variable initialization
		stz progress
		stz progress+1
		stz show_prompt  ; default to show the press key prompt

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

		; load stuff banner
		ldx #16
		ldy #8
		jsr TermSetXY

		lda #<txt_load_stuff
		ldx #>txt_load_stuff
		jsr TermPUTS


		; Display what we're trying to do
		ldx #0
		ldy #10
		jsr TermSetXY

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
		stz file_open_drive

		; Set the Filename
		lda	#1
		jsr	get_arg

		; we have a chance here to change the drive
		sta pArg
		stx pArg+1

		ldy #1
		lda (pArg),y
		cmp #':'
		bne :no_device_passed_in

		; OMG there's a device!
		; if it's valid, maybe it can overide the device 0

		lda <pArg
		pha
		clc
		adc #2
		sta <pArg 		; fuck you if we need to wrap a page

		pla
		sec
		sbc #'0'
		cmp #10
		bcs :no_device_passed_in ; fucked up, so just use device 0

		sta file_open_drive

:no_device_passed_in
		lda pArg
		ldx pArg+1

		jsr fopen
		bcc :opened
		; failed

		; Micah suggested we make life easier, so we don't require the extension
		; sounds good to me
		jsr alternate_open
		bcc :opened

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

		pla

		jsr TermPrintAH
		jsr TermCR

		bra wait_for_key
:got4
		jsr execute_file

wait_for_key

		lda show_prompt
		bne :skip_prompt

		lda #<txt_press_key
		ldx #>txt_press_key
		jsr TermPUTS

:skip_prompt

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
		jmp mmu_lock   ; jsr+rts

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

		inc show_prompt   ; don't show prompt

		jmp TermClearTextBuffer  ; jsr+rts
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

		inc show_prompt   ; don't show prompt

		jmp TermClearTextBuffer  ; jsr+rts
;-----------------------------------------------------------------------------
LoadPGX
		lda #<temp0
		ldx #>temp0
		ldy #^temp0
		jsr set_write_address
		
		lda	pArg
		ldx pArg+1

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
		ldx #mmu_lock_end-mmu_lock
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

		lda pArg
		ldx pArg+1

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

		lda pArg
		ldx pArg+1

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

		lda pArg
		ldx pArg+1

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

		lda pArg
		ldx pArg+1

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
		lda #%01001111	; gamma + bitmap + graphics + overlay + text
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
;
;
ProgressIndicator 

		lda #'.'
		jsr TermCOUT

		dec progress+1
		bpl :return

		lda #16
		sta progress+1

		ldx term_x
		phx
		ldy term_y
		phy

		clc
		lda progress
		inc
		cmp #64
		bcc :no_wrap

		dec
		adc #4
		tax

		ldy #51
		jsr TermSetXY

		lda #G_SPACE 	 ; erase the dude
		jsr glyph_draw
		
		clc
		lda #0     		 ; wrap to left
:no_wrap
		sta progress
		adc #5
		tax

		ldy #51
		jsr TermSetXY

		clc
		lda progress
		and #$3
		adc #GRUN0

		jsr glyph_draw   	; running man

		ply
		plx
		jsr TermSetXY

:return
		rts

;------------------------------------------------------------------------------
;
; We get here, because we got a kernel error when trying to open
; this could mean file is not found, so let's try to find the file
; to make life easier
;
; return c=0 if no error
;
alternate_open
		pha				; preserve the initial error
		stz try_count
]try
		jsr :copy_to_scratch
		jsr :append_ext

		lda #<scratch_path
		ldx #>scratch_path
		jsr fopen
		bcc :opened

		; this path didn't work
		inc try_count
		lda try_count
		cmp #5 				; there are 5 extensions
		bcc ]try
; we failed 4 more times :-(
		pla
		rts

:opened
		lda #<scratch_path
		ldx #>scratch_path
		sta pArg  			; make sure when the file is re-opened it uses this working path
		stx pArg+1

		pla				; restore original error
:rts
		rts

:append_ext
		; at this point y points at the 0 terminator in the scratch path
		lda try_count
		asl
		asl
		tax
]ext_loop
		lda |ext_table,x
		sta |scratch_path,y
		beq :rts
		inx
		iny
		bra ]ext_loop

:copy_to_scratch
		ldy #0
]lp		lda (pArg),y
		sta |scratch_path,y
		beq :done_copy
		iny
		bne ]lp
		; if we get here, things are fubar
		dey
		lda #0
		sta |scratch_path,y
		rts

:done_copy
		lda #'.'
		sta |scratch_path,y  ; replace the 0 terminator
		iny

		lda #0
		sta |scratch_path,y  ; zero terminate
		rts


;------------------------------------------------------------------------------
; Strings and other includes
txt_version asc 'Pexec 0.64'
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
;------------------------------
ext_table
txt_pgz asc 'pgz',00
txt_pgx asc 'pgx',00
txt_kup asc 'kup',00
txt_256 asc '256',00
txt_lbm asc 'lbm',00
;------------------------------

txt_load_stuff asc 'Load your stuff: .pgx, .pgz, .kup, .lbm, .256',00


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
		put logo.s

; pad to the end
		ds $C000-*,$EA
; really pad to end, because merlin is buggy
		ds \,$EA
