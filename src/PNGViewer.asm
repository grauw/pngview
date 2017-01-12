;
; PNG viewer
;
PNGViewer_READER_BASE_ADDRESS: equ 8000H

PNGViewer: MACRO
	ShowScanline:
		jp System_ThrowException
	showScanline: equ $ - 2
	png:
		dw 0
	palette:
		dw PNGViewer_palette
	transferPort:
		db 0
	vdpCommand:
		VDPCommand 0, 0, 0, 0, 0, 0, 0, 0, VDPCommand_LMMC
	width: equ vdpCommand + VDPCommand.nx
	height: equ vdpCommand + VDPCommand.ny
	scanner:
		PNGScanner
	ENDM

; de = PNG image
; ix = this
PNGViewer_Construct: PROC
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
	push ix
	call PNGViewer_GetVDPCommandIY
	call PNGViewer_GetPNG
	ld a,(ix + PNG.interlace)
	and a
	jp nz,PNG_TerminateWithUnsupportedError
	ld c,(ix + PNG.width)
	ld b,(ix + PNG.width + 1)
	ld hl,-256
	add hl,bc
	jr nc,NoCropWidth
	ld bc,256
NoCropWidth:
	ld (iy + VDPCommand.nx),c
	ld (iy + VDPCommand.nx + 1),b
	ld c,(ix + PNG.height)
	ld b,(ix + PNG.height + 1)
	ld hl,-212
	add hl,bc
	jr nc,NoCropHeight
	ld bc,212
NoCropHeight:
	ld (iy + VDPCommand.ny),c
	ld (iy + VDPCommand.ny + 1),b
	ld b,(ix + PNG.colorType)
	ld c,(ix + PNG.bitDepth)
	call PNG_HasPalette
	pop ix
	push bc
	call nz,PNGViewer_InitializePalette
	pop bc
	ld a,b
	cp 0
	jr z,ColorType0
	cp 2
	jr z,ColorType2
	cp 3
	jr z,ColorType3
	cp 4
	jr z,ColorType4
	jp PNG_TerminateWithUnsupportedError
ColorType0:
	call ColorType3
	call PNGViewer_InitializePaletteGrayscale
	ret
ColorType2:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlineRGB & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlineRGB >> 8
	ret
ColorType4:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlineGrayscaleAlpha & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlineGrayscaleAlpha >> 8
	call PNGViewer_InitializePaletteGrayscale
	ret
ColorType3:
	ld a,c
	cp 2
	jr c,BitDepth1
	jr z,BitDepth2
	cp 4
	jr z,BitDepth4
BitDepth8:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlinePalette8Bpp & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlinePalette8Bpp >> 8
	ret
BitDepth4:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlinePalette4Bpp & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlinePalette4Bpp >> 8
	ret
BitDepth2:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlinePalette2Bpp & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlinePalette2Bpp >> 8
	ret
BitDepth1:
	ld (ix + PNGViewer.showScanline),PNGViewer_ShowScanlinePalette1Bpp & 0FFH
	ld (ix + PNGViewer.showScanline + 1),PNGViewer_ShowScanlinePalette1Bpp >> 8
	ret
	ENDP

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
PNGViewer_InitializePalette: PROC
	push ix
	call PNGViewer_GetPNG
	call PNG_GetPalette
	pop ix
	ex de,hl
	ld c,(ix + PNGViewer.palette)
	ld b,(ix + PNGViewer.palette + 1)
	xor a
Loop:
	push af
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
	ld (bc),a
	inc bc
	pop af
	dec a
	jr nz,Loop
	call PNGViewer_MirrorPalette
	ret
	ENDP

; ix = this
PNGViewer_InitializePaletteGrayscale: PROC
	push ix
	call PNGViewer_GetPNG
	ld a,(ix + PNG.bitDepth)
	pop ix
	ld e,(ix + PNGViewer.palette)
	ld d,(ix + PNGViewer.palette + 1)
	cp 2
	jr c,BitDepth1
	jr z,BitDepth2
	cp 8
	jr c,BitDepth4
BitDepth8:
	ld l,0
BitDepth8Loop:
	ld h,PNGViewer_rgbLUTs >> 8
	ld a,(hl)
	inc h
	or (hl)
	inc h
	or (hl)
	ld (de),a
	inc de
	inc l
	jr nz,BitDepth8Loop
	ret
BitDepth4:
	ld hl,PNGViewer_grayscaleLUT4Bpp
	ld bc,16
	ldir
	call PNGViewer_MirrorPalette
BitDepth2:
	ld hl,PNGViewer_grayscaleLUT2Bpp
	ld bc,4
	ldir
	call PNGViewer_MirrorPalette
BitDepth1:
	ex de,hl
	ld (hl),0
	inc hl
	ld (hl),255
	call PNGViewer_MirrorPalette
	ret
	ENDP

; ix = this
PNGViewer_MirrorPalette: PROC
	push ix
	call PNGViewer_GetPNG
	call PNG_GetPalette
	ld a,(ix + PNG.bitDepth)
	pop ix
	cp 8
	ret nc
	ld e,(ix + PNGViewer.palette)
	ld d,(ix + PNGViewer.palette + 1)
	cp 2
	jr c,BitDepth1
	jr z,BitDepth2
BitDepth4:
	ld hl,16
	add hl,de
	ex de,hl
	ld bc,256 - 16
	ldir
	ret
BitDepth2:
	ld hl,4
	add hl,de
	ex de,hl
	ld bc,256 - 4
	ldir
	ret
BitDepth1:
	ld hl,2
	add hl,de
	ex de,hl
	ld bc,256 - 2
	ldir
	ret
	ENDP

; ix = this
PNGViewer_Show: PROC
	ld a,0
	ld (BAKCLR),a
	ld (BDRCLR),a
	ld a,8
	call VDP_InitScreen
	ld b,(ix + PNGViewer.width)
	ld c,(ix + PNGViewer.height)
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
PNGViewer_ShowScanline:
	jp ix

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlineRGB: PROC
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

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlinePalette8Bpp: PROC
	ld c,(ix + PNGViewer.transferPort)
	ld d,(ix + PNGViewer.palette + 1)
Loop:
	ld e,(hl)
	ld a,(de)
	inc hl
	call PNGViewer_Transfer
	djnz Loop
	ret
	ENDP

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlinePalette4Bpp: PROC
	ld c,(ix + PNGViewer.transferPort)
	ld d,(ix + PNGViewer.palette + 1)
Loop:
	ld a,(hl)
	rrca
	rrca
	rrca
	rrca
	ld e,a
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	ld e,(hl)
	ld a,(de)
	call PNGViewer_Transfer
	inc hl
	djnz Loop
	ret
	ENDP

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlinePalette2Bpp: PROC
	ld c,(ix + PNGViewer.transferPort)
	ld d,(ix + PNGViewer.palette + 1)
Loop:
	ld e,(hl)
	rlc e
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	inc hl
	djnz Loop
	ret
	ENDP

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlinePalette1Bpp: PROC
	ld c,(ix + PNGViewer.transferPort)
	ld d,(ix + PNGViewer.palette + 1)
Loop:
	ld e,(hl)
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	dec b
	ret z
	rlc e
	ld a,(de)
	call PNGViewer_Transfer
	inc hl
	djnz Loop
	ret
	ENDP

; b = width
; hl = scanline
; ix = this
PNGViewer_ShowScanlineGrayscaleAlpha: PROC
	ld c,(ix + PNGViewer.transferPort)
	ld d,(ix + PNGViewer.palette + 1)
Loop:
	ld e,(hl)
	ld a,(de)
	inc hl
	ld e,a
	ld a,(hl)
	inc hl
	and a
	jr z,Transparent
	ld a,e
Transparent:
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
; ix = this
; c <- transfer port
; Modifies: af
PNGViewer_ExecuteVDPCommand:
	push de
	push hl
	push iy
	push bc
	call PNGViewer_GetVDPCommandIY
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
PNGViewer_grayscaleLUT2Bpp:
	db 00000000B, 01001001B, 10010010B, 11111111B

PNGViewer_grayscaleLUT4Bpp:
	REPT 16, ?value
	db ?value >> 1 << 2 | ?value >> 1 << 5 | (?value < 3 ? 0 : ?value < 7 ? 1 : ?value < 12 ? 2 : 3)
	ENDM

	ALIGN 100H
PNGViewer_rgbLUTs:
	REPT 256, ?value
	db (?value * 7 + 127) / 255 << 2
	ENDM
	REPT 256, ?value
	db (?value * 7 + 127) / 255 << 5
	ENDM
	REPT 256, ?value
	db ?value < 37 ? 0 : ?value < 110 ? 1 : ?value < 201 ? 2 : 3
	ENDM

	SECTION RAM

	ALIGN 100H
PNGViewer_palette:
	ds 256

	ENDS
