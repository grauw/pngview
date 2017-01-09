;
; PNG viewer
;
PNGViewer_READER_BASE_ADDRESS: equ 8000H

PNGViewer: MACRO
	png:
		dw 0
	commandActive:
		db 0
	reader:
		MappedReader
	vdpCommand:
		VDPCommand 0, 0, 0, 0, 32, 32, 0, 0, VDPCommand_LMMC
	ENDM

; de = PNG image
; ix = this
PNGViewer_Construct:
	ld (ix + PNGViewer.png),e
	ld (ix + PNGViewer.png + 1),d
	push ix
	ld ixl,e
	ld ixh,d
	call PNG_GetRawDataBuffer
	pop ix
	push ix
	ld bc,PNGViewer.reader
	add ix,bc
	ld hl,PNGViewer_READER_BASE_ADDRESS
	call MappedReader_Construct
	pop ix
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
; iy <- reader
PNGViewer_GetReaderIY:
	push ix
	pop iy
	ld de,PNGViewer.reader
	add iy,de
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
	ld hl,PNGViewer_scanline
	call PNGViewer_ReadScanline
	pop bc
	push bc
	ld hl,PNGViewer_scanline
	call PNGViewer_ShowScanline
	pop bc
	dec c
	jr nz,Loop
	call DOS_ConsoleInputWithoutEcho
	call VDP_InitText
	ret
	ENDP

; b = width
; ix = this
PNGViewer_ReadScanline: PROC
	call PNGViewer_GetReaderIY
	call Reader_Read_IY
	and a
	jp nz,PNG_TerminateWithUnsupportedError
Loop:
	push hl
	call Reader_Read_IY
	ld h,PNGViewer_rgbLUTs >> 8
	ld l,a
	ld d,(hl)
	call Reader_Read_IY
	inc h
	ld l,a
	ld e,(hl)
	call Reader_Read_IY
	inc h
	ld l,a
	ld a,(hl)
	or d
	or e
	pop hl
	ld (hl),a
	inc hl
	djnz Loop
	ret
	ENDP

; b = width
; ix = this
PNGViewer_ShowScanline:
	call PNGViewer_GetVDPCommandIY
	ld a,(ix + PNGViewer.commandActive)
	and a
	call z,PNGViewer_ExecuteVDPCommand
	ld c,b
	ld b,0
	ld a,b
	or c
	call nz,VDPCommand_Transfer_IY
	ret

; b = width
; hl = color data
; iy = VDP command
; ix = this
; hl <- updated
; b < updated
PNGViewer_ExecuteVDPCommand:
	ld a,(hl)
	push bc
	push hl
	ld (iy + VDPCommand.color),a
	call VDPCommand_Execute_IY
	ld (ix + PNGViewer.commandActive),-1
	pop hl
	pop bc
	inc hl
	dec b
	ret

;
	SECTION RAM

PNGViewer_scanline:
	ds 256 * 3,255

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
