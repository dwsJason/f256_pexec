;------------------------------------------------------------------------------
;
; Colors - Predefined Color Tables, and helper functions for dealing with color
;
;------------------------------------------------------------------------------

VKY_BKG_COL_B = $D00D           ; Vicky Graphics Background Color Blue Component
VKY_BRDR_COL_B = $D005          ; Vicky Border Color -- Blue

VKY_TXT_FGLUT = $D800           ; Text foreground CLUT
VKY_TXT_BGLUT = $D840           ; Text background CLUT

initColors
		php
		sei
		lda io_ctrl
		pha

		; Copy the colors up into the text luts

		stz io_ctrl

		ldx #{16*4}-1       ; 16 colors
]lp
		lda |gs_colors,x
		sta |VKY_TXT_FGLUT,x
		sta |VKY_TXT_BGLUT,x
		dex
		bpl ]lp

		; Set the background color, and the border color

		ldx #2
]lp
		lda |gs_colors+{4*2},x ; Dark Blue index 2
		sta |VKY_BKG_COL_B,x
		sta |VKY_BRDR_COL_B,x
		dex
		bpl ]lp

		pla
		sta io_ctrl
		plp
		rts
;------------------------------------------------------------------------------
gs_colors
	adrl $ff000000  ;0 Black
	adrl $ffdd0033	;1 Deep Red
	adrl $ff000099	;2 Dark Blue
	adrl $ffdd22dd	;3 Purple
	adrl $ff007722	;4 Dark Green
	adrl $ff555555	;5 Dark Gray
	adrl $ff2222ff	;6 Medium Blue
	adrl $ff66aaff	;7 Light Blue
	adrl $ff885500	;8 Brown
	adrl $ffff6600	;9 Orange
	adrl $ffaaaaaa	;A Light Gray
	adrl $ffff9988	;B Pink
	adrl $ff00dd00	;C Light Green
	adrl $ffffff00	;D Yellow
	adrl $ff55ff99	;E Aquamarine
	adrl $ffffffff	;F White

;------------------------------------------------------------------------------
;
; Micro Kernel uses these colors, but Super BASIC does not, and the
; DOS shell does not, so I'm not going to either
;
			do 0
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
			fin

;------------------------------------------------------------------------------

