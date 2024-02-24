# pexec
Firmware module for the F256Jr and F256K

pgz - launcher

pgx - launcher

kup - launcher (EXPERIMENTAL)

lbm - image viewer (8bit 256 color only)

256 - image viewer (320x200 or 320x240)

Written by dwsJason and csoren
Foenix Retro Systems logo by econtrerasd

Do not load data in these memory address ranges:

$0-$1FF       ; Direct page an Stack

$C000->$FFFF  ; memory used by the micro kernel, and it used to read the 
              ; files that are being loaded.

MMU at program start
	- Physical Memory Block 0 in Slot 0   
	- Physical Memory Block 1 in Slot 1
	- Physical Memory Block 2 in Slot 2
	- Physical Memory Block 3 in Slot 3
	- Physical Memory Block 4 in Slot 4
	- Physical Memory Block 5 in Slot 5
	- Block 6 mapped to IO
	- Block 7 mapped to kernel firmware

KUP programs limited to start addresses in Slot 1-5, and a maximum size of 40k

Why aren't we at 1.0, we are missing these features, if anyone wants to
contribute.

     - friendlier exe name support (if file doesn't exist, try some extenstions
     - like .pgz, or .pgx to see if they exist)

     - PATH support

     - File Chooser (if no args passed, or file not found this would be
       really nice.  Something like Bitsy Bye for those familiar)

     - Image viewer needs error checking

     - get the filesize (direntry), for an accurate loading bar

     - better file validation 
    
