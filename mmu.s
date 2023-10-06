;
; mmu helper module
;
		mx %11

; Don't try to use $E000, or $0000
; for either of these block ranges
; if you want to use $C000, you'll have
; to make sure to set the mmu up for this yourself

READ_BLOCK  = $8000
WRITE_BLOCK = $6000
READ_MMU  = mmu+{READ_BLOCK/8192}
WRITE_MMU = mmu+{WRITE_BLOCK/8192}


; Zero Page defines
mmu_ctrl equ 0
io_ctrl  equ 1
; reserved addresses 2-7 for future expansion, use at your own peril
mmu      equ 8
mmu0     equ 8
mmu1     equ 9
mmu2     equ 10
mmu3     equ 11
mmu4     equ 12
mmu5     equ 13
mmu6     equ 14
mmu7     equ 15

; System Bus Pointer's
pSource  equ $10
pDest    equ pSource+2
old_mmu_ctrl = pDest+2
old_io_ctrl = old_mmu_ctrl+1
old_mmu0 = old_io_ctrl+1


;
; Take the current mmu config, and allow write access
;
mmu_unlock
		lda mmu_ctrl
		sta old_mmu_ctrl

		lda io_ctrl
		sta old_io_ctrl

		lda mmu_ctrl
		and #$3
		sta temp0     ; active MLUT
		asl
		asl
		asl
		asl
		ora temp0     ; active MLUT, copied to the EDIT LUT
		ora #$80      ; Enable MMU edit - we are editing the active (spooky)
		sta mmu_ctrl

		ldx #7
]save	lda mmu0,x
		sta old_mmu0,x
		dex
		bpl ]save

		rts

;
; Restore mmu to it's previous state (prior to calling unlock)
;
mmu_lock
		ldx #7
]fix	lda old_mmu0,x
		sta mmu0,x
		dex
		bpl ]fix

		lda old_io_ctrl
		sta io_ctrl

		lda old_mmu_ctrl
		sta mmu_ctrl
		rts

; Set system bus address for reading
;
;  A = LOW
;  X = MED
;  Y = HIGH
;
set_read_address
		sta pSource		; System Bus Address
		;stx pSource+1
		sty READ_MMU

		; Convert BUS Address, into an 8k block number
		;lda pSource+1
		txa
		asl
		rol READ_MMU
		asl
		rol READ_MMU
		asl
		rol READ_MMU   	; READ_MMU contains the 8k block #

		;lda pSource+1     ; Adjust pSource, so it's pointing to CPU mapped
		txa
		and #$1F		  ; memory
		ora #>READ_BLOCK
		sta pSource+1

		rts

;------------------------------------------------------------------------------
; Return the current system bus reading address
;  A = LOW
;  X = MED
;  Y = HIGH
;
get_read_address
		stz temp0   	; convert from block+offset, to master bus address
		lda READ_MMU
		lsr
		ror temp0
		lsr
		ror temp0
		lsr
		ror temp0
		tay
		
		lda pSource+1
		and #$1F
		ora temp0
		
		tax
		
		lda pSource
		rts
		
;------------------------------------------------------------------------------
; Return the current system bus writing address
;  A = LOW
;  X = MED
;  Y = HIGH
;
get_write_address
		stz temp0		; convert from block+offset, to master bus address
		lda WRITE_MMU
		lsr
		ror temp0
		lsr
		ror temp0
		lsr
		ror temp0
		tay
		
		lda pDest+1
		and #$1F
		ora temp0
		
		tax
		
		lda pDest
		rts
		

; Set system bus address for writing
;
;  A = LOW
;  X = MED
;  Y = HIGH
;
set_write_address
		sta pDest		; System Bus Address
		;stx pDest+1
		sty WRITE_MMU

		; Convert BUS Address, into an 8k block number
		;lda pDest+1
		txa
		asl
		rol WRITE_MMU
		asl
		rol WRITE_MMU
		asl
		rol WRITE_MMU

		;lda pDest+1    ; Adjust pDest, so it's pointing to CPU mapped memory
		txa
		and #$1F
		ora #>WRITE_BLOCK
		sta pDest+1
		rts

;
; Read byte at the current read address
; and auto-increment
;
; only changes A
;
readbyte
		lda (pSource)
		inc pSource
		bne :done
		phx
		ldx pSource+1
		inx
		cpx #>READ_BLOCK+$2000
		bcc :no_wrap
		inc READ_MMU		; next mmu 8k block
		ldx #>READ_BLOCK	; next read needs to wrap to next block
:no_wrap
		stx pSource+1
		plx
:done
		rts

;
; Write byte at the current write address
; and auto-increment
;
writebyte
		sta (pDest)
		inc pDest
		bne :done
		phx
		ldx pDest+1
		inx
		cpx #>WRITE_BLOCK+$2000
		bcc :no_wrap
		inc WRITE_MMU  		; next mmu 8k block
		ldx #>WRITE_BLOCK   ; next write needs to wrap to next block
:no_wrap
		stx pDest+1
		plx
:done
		rts


; 
; Determine how many bytes it's possible to write into the write window, max 128
;
bytes_can_write
		lda	pDest+1
		cmp	#>WRITE_BLOCK+$1F00
		bne	:use_128
		lda	pDest
		bpl	:use_128	; A (pointer) is less than 128, there's room for yet another 128 bytes
		; Subtract A from 256, in 8 bit two's complement this is the same as negate
		eor	#$FF
		clc
		adc	#1
		rts
:use_128
		lda	#128
		rts

; 
; Increment pDest by A
;
increment_dest
		clc
		adc	pDest
		sta	pDest
		bcc	:done
		lda	pDest+1
		inc
		cmp #>WRITE_BLOCK+$2000
		bne	:no_wrap
		inc	WRITE_MMU
		lda	#>WRITE_BLOCK
:no_wrap
		sta	pDest+1
:done
		rts
