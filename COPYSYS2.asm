;	COPYSYS CPM3 Plus for MSX
;	Adapted for MSX Format
;	caro - 26.10.2022
; ============================================================
	OUTPUT	"copysys2.com"
; ============================================================
BIOS:	equ	00001h
BDOS:	equ	00005h
TPA:	equ	00100h
LF:	equ	0Ah
CR:	equ	0Dh
ESC:	equ	1Bh
; ============================================================
		org	TPA
;
start:		ld	a, (BDOS+2)	; High Adress BDOS
		cp	080h		; BDOS >= 8000h	?
		jr	nc, loc_10E	; YES
; 
		ld	de, NotEnoughMem ; "Not enough memory!"
		call	prn_DE
		rst	0		; EXIT
;==============================================================
loc_10E:	ld	sp, Stack
		ld	de, Copysys1_2	; ENTER	SOURCE DRIVE
		call	sub_240
		ld	(SOURCE), a
		ld	de, EnterTargetDrv ; ENTER TARGET DRIVE
		call	sub_240
		ld	(TARGET), a
		ld	de, InsertDisk	; "Insert disks and press any key!"
		call	prn_DE
		call	Control_Abort	; CONIN	Console	input
		ld	de, Copying	; "Copying ..."
		call	prn_DE
; SOURCE DISK
		ld	a, (SOURCE)
		call	res_disk	; Reset	and Active Disk	(a)
;	Read 18*512 = 2400h byte (BOOT and Loader)
		ld	c, 39		; Read Sectors
		call	sub_28A		; B=18, DMA = bufer
; Здесь надо вставить инициализацию каталога - 2400h...3400h = 0E5h
init_dir:	ld	hl, bufer_dir
		ld	de, bufer_dir+1
		ld	(hl), 0E5h
		ld	bc, 1000h-1
		ldir			;init bufer
; TARGET DISK
		ld	a, (TARGET)
		call	res_disk
;	Read 2*512 = 400h byte
		ld	b, 2		; #Sectors (512 byte)
		ld	c, 39		; Read (b) sectors
		ld	de, bufer_targ	; adress DMA
		call	sub_28F
;
		ld	hl, bufer_targ+0Bh ; from Target
		ld	de, bufer+0Bh  ; to Source
		ld	bc, 19		  ; 19 byte
		ldir
		ld	a, (bufer_targ+200h)	;=F9h or F8h
		ld	(bufer+200h), a 
;  Write BOOT and Loader 18*512 = 2400h byte and dir 1000h
		ld	c, 42		; Write	a sector (512 byte)
		ld	b, 18+8		; 26 sectors
		call	sub_28C		; DMA = bufer
; =================================================================
; SOURCE DISK
		ld	a, (SOURCE)
		call	res_disk	; Reset	and Active Disk	(a)
; READ CPM3.SYS from SOURCE disk
		ld	c, 44		; Set Multi-Sector Count
		ld	e, 128		; # Sectors
		call	BDOS
		ld	c, 15		; OPEN FILE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		inc	a
		jp	z, Error_dsk
;
		ld	de, bufer_sys
		ld	c, 26		; SET DMA
		call	BDOS
		ld	c, 20		; READ
		ld	de,FCB_CPM3_SYS
		call	BDOS
		and	a
		jp	nz, Error_dsk
;
		ld	de, bufer2sys
		ld	c, 26		; SET DMA
		call	BDOS
		ld	c, 20		; READ
		ld	de, FCB_CPM3_SYS
		call	BDOS
		cp	2
		jp	nc, Error_dsk	; Disk Error
;
		push	hl		; save h = #Sectors
;
		ld	c, 16		; CLOSE	FILE
		ld	de,FCB_CPM3_SYS	; CPM3.SYS
		call	BDOS
; TARGET DISK
		ld	a, (TARGET)
		call	res_disk
; WRITE CPM3.SYS to TARGET DISK
		ld	c, 15		; OPEN FILE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		inc	a
		jr	z, loc_1CB
;
		ld	c, 19		; ERASE	FILE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		inc	a
		jp	z, Error_dsk
;
		jr	loc_1D0		; CREATE FILE
; ------------
loc_1CB:	ld	a, h
		and	a
		jp	nz, Error_dsk
; WRITE CPM3.SYS
loc_1D0:	ld	c, 22		; CREATE FILE
		ld	de,FCB_CPM3_SYS
		call	BDOS		; A=0FFh - признак ошибки
		ld	(byte_3A9), a
		ld	(byte_3BD), a
		inc	a
		jp	z, Error_dsk	; Выходим с ошибкой
;
		ld	de, bufer_sys
		ld	c, 26		; SET DMA
		call	BDOS
		ld	c, 21		; WRITE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		and	a
		jp	nz, Error_dsk
;
		pop	hl		; h = #Sectors
		ld	c, 44		; Set Multi-Sector Count
		ld	e, h		; # Sectors
		call	BDOS
		ld	de, bufer2sys
		ld	c, 26		; SET DMA
		call	BDOS
		ld	c, 21		; WRITE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		and	a
		jp	nz, Error_dsk
;
		ld	c, 16		; CLOSE	FILE
		ld	de, FCB_CPM3_SYS
		call	BDOS
		ld	de, aSystemCopied ; "System copied!"
;
loc_21C:	call	prn_DE
		ld	c, 25		; GET ACTIV DSK
		call	BDOS
		ld	c, a
		ld	e, 1
		ld	a, 27		; Select disk drive
		call	BIOS_A
		rst	0		; EXIT
; *****************************************************************
; CONIN	Console	input
Control_Abort:	ld	a, 9
		call	BIOS_A
		cp	3		; Ctrl/C
		ld	de, Aborted	; "Aborted!"
		jp	z, loc_21C
		ret
; *****************************************************************
prn_DE:		ld	c, 9
		jp	BDOS
; *****************************************************************
sub_240:	call	prn_DE
loc_243:	call	Control_Abort	; CONIN	Console	input
		and	0DFh
		ld	c, a
		sub	41h ; 'A'
		ld	b, a
		cp	0Ch		; 41h+0Ch=4Dh -> "M"
		jr	z, loc_243	; = "M"
		cp	10h		; 41h+10h = 51h	-> "Q"
		jr	nc, loc_243	; >= "Q"
		push	bc
		ld	c, a		; C=0->(A),1->(B)...
		ld	e, 1
		ld	a, 27		; Select disk drive
		call	BIOS_A		; HL=DPH
		pop	bc
		ld	a, h
		or	l
		jr	z, loc_243	; DPH=0
		push	bc
		ld	a, 12		; Console output
		call	BIOS_A
		pop	af
		ret
; ******************************************************************
; input: A = disk
res_disk:	inc	a
		ld	(FCB_CPM3_SYS),	a
		dec	a
sub_26A:	push	af
		ld	hl, 1
loc_26E:	sub	1
		jr	c, loc_275	; RESET	and ACTIV DISK
		add	hl, hl
		jr	loc_26E
; -----------------------------------------------------------------
loc_275:	ld	c, 37		; RESET	DISK
		ex	de, hl
		call	BDOS
		pop	af
		ld	c, 14		; ACTIV	DISK (E)
		ld	e, a
		call	BDOS
		inc	a
		ret	nz
Error_dsk:	ld	de, DiskIOError	; "Disk I/O Error!"
		jp	loc_21C
; ******************************************************************
sub_28A:
;		ld	b, 16		;16 sectors
		ld	b, 18		;18 sectors
sub_28C:	ld	de, bufer
; ******************************************************************
sub_28F:	push	bc
		push	de
		ld	c, b
		ld	a, 69		; Read/write multiple sectors
		call	BIOS_A
		ld	a, 24		; Move disk head to track 0
		call	BIOS_A
		ld	bc, 0
		ld	a, 33		; Set sector number
		call	BIOS_A
		pop	bc
		ld	a, 36		; Set DMA address
		call	BIOS_A
		ld	a, 1
		ex	af, af'
		ld	a, 84		; Select bank for DMA operation
		call	BIOS_A
		pop	bc
;
loc_2B3:	push	bc
		ld	a, c		; Read OR Write
		call	BIOS_A
		pop	bc
		djnz	loc_2B3
		ret
; ******************************************************************
BIOS_A:		push	hl
		ld	hl, (BIOS)	;
		ld	l, a
		ex	(sp), hl
		ex	af, af'
		ret
; ******************************************************************
Copysys1_2:	db CR,LF
		db "COPYSYS 1.3",CR,LF
		db "(c) 1987 RVS Datentechnik",CR,LF
		db " 2022 Adapted for MSX format",CR,LF
		db CR,LF
		db "Enter source drive: $"
EnterTargetDrv:	db CR,LF
		db "Enter target drive: $"
InsertDisk:	db CR,LF
		db CR,LF
		db "Insert disks and press any key! $"
aSystemCopied:	db CR,"System copied!",CR,LF,"$"
DiskIOError:	db CR,"Disk I/O Error!",CR,LF,"$"
Copying:	db CR,"Copying ... ",ESC,"K","$"
Aborted:	db CR,"Aborted!",ESC,"K",CR,LF,"$"
NotEnoughMem:	db CR,LF
		db "Not enough memory!",CR,LF,"$"
SOURCE:		db 0
TARGET:		db 0
FCB_CPM3_SYS:	db 0
		db "CPM3    SYS"
byte_3A9:	db 0, 0, 0, 0, 0, 0, 0, 0
		db 0, 0, 0, 0, 0, 0, 0,	0
		db 0, 0, 0, 0
byte_3BD:	db 0, 0, 0, 0
; =================================================
		ds	500h-$
; ================================================
; Bufers
Stack		equ	$
bufer		equ	$		;size = 2400h
bufer_dir	equ	bufer+2400h	;size = 1000h
bufer_targ	equ	bufer_dir+1000h	;size = 400h
;
bufer_sys	equ	$		;size = 4000h
bufer2sys	equ	bufer_sys+4000h	;
; ================================================
		end
