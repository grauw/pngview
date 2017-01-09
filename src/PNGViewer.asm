;
; PNG viewer
;
PNGViewer_READER_BASE_ADDRESS: equ 8000H

PNGViewer: MACRO
	png:
		dw 0
	transferPort:
		db 0
	vdpCommand:
		VDPCommand 0, 0, 0, 0, 32, 32, 0, 0, VDPCommand_LMMC
	scanner:
		PNGScanner
	ENDM

; de = PNG image
; ix = this
PNGViewer_Construct:
	ld (ix + PNGViewer.png),e
	ld (ix + PNGViewer.png + 1),d
	push ix
	push de
	call PNGViewer_GetScanner
	pop de
	call PNGScanner_Construct
	pop ix
	ld (ix + PNGViewer.scanner),e
	ld (ix + PNGViewer.scanner + 1),d
	ret

; ix = this
; ix <- png image
PNGViewer_GetPNG:
	ld e,(ix + PNGViewer.png)
	ld d,(ix + PNGViewer.png + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; iy <- VDP command
PNGViewer_GetVDPCommandIY:
	push ix
	pop iy
	ld de,PNGViewer.vdpCommand
	add iy,de
	ret

; ix = this
; ix <- scanner
PNGViewer_GetScanner:
	ld de,PNGViewer.scanner
	add ix,de
	ret

; ix = this
PNGViewer_Show: PROC
	ld a,8
	call VDP_InitScreen
	push ix
	call PNGViewer_GetPNG
	ld a,(ix + PNG.colorType)
	cp 2
	jp nz,PNG_TerminateWithUnsupportedError
	ld a,(ix + PNG.bitDepth)
	cp 8
	jp nz,PNG_TerminateWithUnsupportedError
	ld a,(ix + PNG.interlace)
	and a
	jp nz,PNG_TerminateWithUnsupportedError
	ld b,(ix + PNG.width)
	ld c,(ix + PNG.height)
	pop ix
Loop:
	push bc
	push ix
	call PNGViewer_GetScanner
	call PNGScanner_ReadScanline
	pop ix
	pop bc
	push bc
	call PNGViewer_ShowScanline
	pop bc
	dec c
	jr nz,Loop
	call DOS_ConsoleInputWithoutEcho
	call VDP_InitText
	ret
	ENDP

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanline: PROC
	ld c,(ix + PNGViewer.transferPort)
Loop:
	ld d,PNGViewer_rgbLUTs >> 8
	ld e,(hl)
	ld a,(de)
	inc hl
	inc d
	ld e,(hl)
	ex de,hl
	or (hl)
	ex de,hl
	inc hl
	inc d
	ld e,(hl)
	ex de,hl
	or (hl)
	ex de,hl
	inc hl
	call PNGViewer_Transfer
	djnz Loop
	ret
	ENDP

; a = color
; c = transfer I/O port
; ix = this
PNGViewer_Transfer:
	inc c
	dec c
	jr z,PNGViewer_ExecuteVDPCommand
	out (c),a
	ret

; a = color
; b = width
; ix = this
; c <- transfer port
; Modifies: af
PNGViewer_ExecuteVDPCommand:
	push de
	push hl
	push iy
	push bc
	call PNGViewer_GetVDPCommandIY
	ld (iy + VDPCommand.nx),b
	ld (iy + VDPCommand.color),a
	call VDPCommand_Execute_IY
	pop bc
	call VDPCommand_PrepareTransfer
	pop iy
	pop hl
	pop de
	ld (ix + PNGViewer.transferPort),c
	ret

;
	SECTION RAM

	ALIGN 100H
PNGViewer_rgbLUTs:
	REPT 256, ?value
	db (?value * 7 + 128) / 255 << 2
	ENDM
	REPT 256, ?value
	db (?value * 7 + 128) / 255 << 5
	ENDM
	REPT 256, ?value
	db (?value * 3 + 128) / 255
	ENDM

	ENDS
