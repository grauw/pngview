;
; PNG scanline reader
;
PNGScanner_READER_BASE_ADDRESS: equ 8000H
PNGScanner_MAX_LINESIZE: equ 256 * 8

PNGScanner: MACRO
	png:
		dw 0
	reader:
		MappedReader
	currentScanline:
		db 0
	lineSize:
		dw 0
	bytesPerPixelNegated:
		db 0
	scanlineA:
		dw scanlineABuffer
	scanlineB:
		dw scanlineBBuffer

		ds 8
	scanlineABuffer:
		ds PNGScanner_MAX_LINESIZE
		ds 8
	scanlineBBuffer:
		ds PNGScanner_MAX_LINESIZE
	ENDM

; de = PNG image
; ix = this
; de <- this
PNGScanner_Construct:
	ld (ix + PNGScanner.png),e
	ld (ix + PNGScanner.png + 1),d
	push ix
	ld ixl,e
	ld ixh,d
	call PNG_GetRawDataBuffer
	pop ix
	push ix
	ld bc,PNGScanner.reader
	add ix,bc
	ld hl,PNGScanner_READER_BASE_ADDRESS
	call MappedReader_Construct
	pop ix
	push ix
	call PNGScanner_GetPNG
	call PNG_GetLineSize
	call PNG_GetBytesPerPixel
	pop ix
	ld (ix + PNGScanner.lineSize),l
	ld (ix + PNGScanner.lineSize + 1),h
	neg
	ld (ix + PNGScanner.bytesPerPixelNegated),a
	ld bc,PNGScanner_MAX_LINESIZE
	scf
	sbc hl,bc
	jp nc,PNG_TerminateWithUnsupportedError
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- png image
PNGScanner_GetPNG:
	ld e,(ix + PNGScanner.png)
	ld d,(ix + PNGScanner.png + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; iy <- reader
PNGScanner_GetReaderIY:
	push ix
	pop iy
	ld de,PNGScanner.reader
	add iy,de
	ret

; ix = this
; hl <- scanline
PNGScanner_ReadScanline:
	call PNGScanner_GetReaderIY
	call Reader_Read_IY
	cp 1
	jr c,PNGScanner_FilterNone
	jr z,PNGScanner_FilterSub
	cp 3
	jr c,PNGScanner_FilterUp
	jr z,PNGScanner_FilterAverage
	cp 4
	jp c,PNGScanner_FilterPaeth
	jp PNG_TerminateWithInvalidError

; ix = this
; hl <- scanline
PNGScanner_FilterNone:
	res 0,(ix + PNGScanner.currentScanline)
	ld e,(ix + PNGScanner.scanlineA)
	ld d,(ix + PNGScanner.scanlineA + 1)
	ld c,(ix + PNGScanner.lineSize)
	ld b,(ix + PNGScanner.lineSize + 1)
	push de
	call Reader_ReadBlock_IY
	pop hl
	ret

; ix = this
; hl <- scanline
PNGScanner_FilterSub: PROC
	res 0,(ix + PNGScanner.currentScanline)
	ld e,(ix + PNGScanner.scanlineA)
	ld d,(ix + PNGScanner.scanlineA + 1)
	ld c,(ix + PNGScanner.lineSize)
	ld b,(ix + PNGScanner.lineSize + 1)
	push de
	call Reader_ReadBlock_IY
	pop de
	push de
	ld l,(ix + PNGScanner.bytesPerPixelNegated)
	ld h,-1
	add hl,de
	; de = Raw(x), hl = Raw(x-bpp)
Loop:
	ld a,(de)
	add a,(hl)
	ld (de),a
	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jp nz,Loop
	pop hl
	ret
	ENDP

; ix = this
; hl <- scanline
PNGScanner_FilterUp: PROC
	ld l,(ix + PNGScanner.scanlineA)
	ld h,(ix + PNGScanner.scanlineA + 1)
	ld e,(ix + PNGScanner.scanlineB)
	ld d,(ix + PNGScanner.scanlineB + 1)
	ld c,(ix + PNGScanner.lineSize)
	ld b,(ix + PNGScanner.lineSize + 1)
	ld a,(ix + PNGScanner.currentScanline)
	xor 1
	ld (ix + PNGScanner.currentScanline),a
	jr nz,NoSwap
	ex de,hl
NoSwap:
	push de
	push hl
	call Reader_ReadBlock_IY
	pop de
	pop hl
	push hl
	; hl = Raw(x), de = Prior(x)
Loop:
	ld a,(de)
	add a,(hl)
	ld (hl),a
	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jp nz,Loop
	pop hl
	ret
	ENDP

; ix = this
; hl <- scanline
PNGScanner_FilterAverage: PROC
	ld l,(ix + PNGScanner.scanlineA)
	ld h,(ix + PNGScanner.scanlineA + 1)
	ld e,(ix + PNGScanner.scanlineB)
	ld d,(ix + PNGScanner.scanlineB + 1)
	ld c,(ix + PNGScanner.lineSize)
	ld b,(ix + PNGScanner.lineSize + 1)
	ld a,(ix + PNGScanner.currentScanline)
	xor 1
	ld (ix + PNGScanner.currentScanline),a
	jr nz,NoSwap
	ex de,hl
NoSwap:
	push de
	push hl
	call Reader_ReadBlock_IY
	exx
	pop hl
	exx
	pop de
	push de
	ld l,(ix + PNGScanner.bytesPerPixelNegated)
	ld h,-1
	add hl,de
	ex de,hl
	; hl = Raw(x), de = Raw(x-bpp), hl' = Prior(x)
Loop:
	ld a,(de)
	exx
	add a,(hl)
	inc hl
	exx
	rra
	add a,(hl)
	ld (hl),a
	inc hl
	inc de
	dec bc
	ld a,b
	or c
	jp nz,Loop
	pop hl
	ret
	ENDP

; ix = this
; hl <- scanline
PNGScanner_FilterPaeth: PROC
	jp PNG_TerminateWithUnsupportedError
	ret
	ENDP
