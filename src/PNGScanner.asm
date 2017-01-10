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
	jp z,PNGScanner_FilterPaeth
	jp PNG_TerminateWithInvalidError

; ix = this
; hl <- scanline
PNGScanner_FilterNone:
	res 0,(ix + PNGScanner.currentScanline)
	ld e,(ix + PNGScanner.scanlineA)
	ld d,(ix + PNGScanner.scanlineA + 1)
	push de
	call PNGScanner_ReadBlock
	pop hl
	ret

; ix = this
; hl <- scanline
PNGScanner_FilterSub: PROC
	res 0,(ix + PNGScanner.currentScanline)
	ld e,(ix + PNGScanner.scanlineA)
	ld d,(ix + PNGScanner.scanlineA + 1)
	push de
	call PNGScanner_ReadBlock
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
	ld a,(ix + PNGScanner.currentScanline)
	xor 1
	ld (ix + PNGScanner.currentScanline),a
	jr nz,NoSwap
	ex de,hl
NoSwap:
	push de
	push hl
	call PNGScanner_ReadBlock
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
	ld a,(ix + PNGScanner.currentScanline)
	xor 1
	ld (ix + PNGScanner.currentScanline),a
	jr nz,NoSwap
	ex de,hl
NoSwap:
	push de
	push hl
	call PNGScanner_ReadBlock
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
	ld l,(ix + PNGScanner.scanlineA)
	ld h,(ix + PNGScanner.scanlineA + 1)
	ld e,(ix + PNGScanner.scanlineB)
	ld d,(ix + PNGScanner.scanlineB + 1)
	ld a,(ix + PNGScanner.currentScanline)
	xor 1
	ld (ix + PNGScanner.currentScanline),a
	jr nz,NoSwap
	ex de,hl
NoSwap:
	push de
	push hl
	call PNGScanner_ReadBlock
	exx
	pop de
	ld l,(ix + PNGScanner.bytesPerPixelNegated)
	ld h,-1
	add hl,de
	ex de,hl
	exx
	pop de
	push de
	ld l,(ix + PNGScanner.bytesPerPixelNegated)
	ld h,-1
	add hl,de
	ex de,hl
	; hl = Raw(x), de = Raw(x-bpp), hl' = Prior(x), de' = Prior(x-bpp)
Loop:
	ld a,(de)
	inc de
	exx
	ld b,(hl)
	inc hl
	ex de,hl
	ld c,(hl)
	ex de,hl
	inc de
	push de
	push hl
	call PNGScanner_PaethPredictor
	pop hl
	pop de
	exx
	add a,(hl)
	ld (hl),a
	inc hl
	dec bc
	ld a,b
	or c
	jp nz,Loop
	pop hl
	ret
	ENDP

; a = Raw(x-bpp)
; b = Prior(x)
; c = Prior(x-bpp)
; a <- value
; Modifies: de, hl
PNGScanner_PaethPredictor: PROC
	ld l,a
	add a,b
	jr c,AddOverflow
	sub c
	jr nc,Continue
	ld a,0
	jp Continue
AddOverflow:
	sub c
	jr c,Continue
	ld a,255
Continue:
	ld h,a  ; p := a + b - c
	ABS b
	ld d,a  ; pb := abs(p - b)
	ld a,h
	ABS c
	ld e,a  ; pc := abs(p - c)
	ld a,h
	ABS l
	ld h,a  ; pa := abs(p - a)
	ld a,d
	cp h
	jr c,CheckReturnBC
	ld a,e
	cp h
	jr c,CheckReturnBC
	ld a,l  ; if pa <= pb AND pa <= pc then return a
	ret
CheckReturnBC:
	ld a,e
	cp d
	ld a,b  ; else if pb <= pc then return b
	ret nc
	ld a,c  ; else return c
	ret
ABS: MACRO ?register
	sub ?register
	jr nc,Done
	neg
Done:
	ENDM
	ENDP

; de = scanline
; iy = reader
; ix = this
; bc <- bytes read
PNGScanner_ReadBlock:
	ld c,(ix + PNGScanner.lineSize)
	ld b,(ix + PNGScanner.lineSize + 1)
	call Reader_ReadBlock_IY
	ret
