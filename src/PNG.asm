;
; PNG image
;
PNG: MACRO
	reader:
		dw 0
	width:
		dd 0
	height:
		dd 0
	bitDepth:
		db 0
	colorType:
		db 0
	compression:
		db 0
	filter:
		db 0
	interlace:
		db 0
	ENDM

; de = mapped reader
; ix = this
; ix <- this
PNG_Construct:
	ld (ix + PNG.reader),e
	ld (ix + PNG.reader + 1),d
	call PNG_GetReaderIY
	call PNG_ReadMagicNumber
	call PNG_ReadIHDR
	call PNG_Validate
	ld hl,PNG_invalidPNGError
	jp c,Application_TerminateWithError
	ret

; ix = this
; ix <- this
PNG_Destruct:
	ret

; ix = this
; iy <- reader
PNG_GetReaderIY:
	ld e,(ix + PNG.reader)
	ld d,(ix + PNG.reader + 1)
	ld iyl,e
	ld iyh,d
	ret

; iy = reader
; ix = this
PNG_ReadMagicNumber:
	ld hl,PNG_noPNGFileError
	call Reader_Read_IY
	cp 137
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "P"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "N"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "G"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 13
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 10
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 26
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 10
	jp nz,Application_TerminateWithError
	ret

; iy = reader
; ix = this
PNG_ReadIHDR:
	ld hl,PNG_invalidPNGError
	call Reader_Read_IY
	cp 0
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 0
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 0
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp 13
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "I"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "H"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "D"
	jp nz,Application_TerminateWithError
	call Reader_Read_IY
	cp "R"
	jp nz,Application_TerminateWithError
	call PNG_ReadDoubleWordBE_IY
	ld (ix + PNG.width),l
	ld (ix + PNG.width + 1),h
	ld (ix + PNG.width + 2),e
	ld (ix + PNG.width + 3),d
	call PNG_ReadDoubleWordBE_IY
	ld (ix + PNG.height),l
	ld (ix + PNG.height + 1),h
	ld (ix + PNG.height + 2),e
	ld (ix + PNG.height + 3),d
	call Reader_Read_IY
	ld (ix + PNG.bitDepth),a
	call Reader_Read_IY
	ld (ix + PNG.colorType),a
	call Reader_Read_IY
	ld (ix + PNG.compression),a
	call Reader_Read_IY
	ld (ix + PNG.filter),a
	call Reader_Read_IY
	ld (ix + PNG.interlace),a
	call PNG_ReadDoubleWordBE_IY  ; skip crc
	ret

; ix = this
; f <- c: invalid
PNG_Validate: PROC
	bit 7,(ix + PNG.width + 3)
	jr nz,Invalid
	bit 7,(ix + PNG.height + 3)
	jr nz,Invalid
	xor a
	or (ix + PNG.compression)
	jr nz,Invalid
	or (ix + PNG.filter)
	jr nz,Invalid
	ld a,~1
	and (ix + PNG.interlace)
	jr nz,Invalid
	ld a,(ix + PNG.colorType)
	and a
	jp z,ColorType0
	cp 2
	jp z,ColorType2
	cp 4
	jp c,ColorType3
	jp z,ColorType4
	cp 6
	jp z,ColorType6
	jr Invalid
ColorType0:
	ld a,(ix + PNG.bitDepth)
	cp 1
	ret z
	cp 2
	ret z
	cp 4
	ret z
	cp 8
	ret z
	cp 16
	ret z
	jr Invalid
ColorType3:
	ld a,(ix + PNG.bitDepth)
	cp 1
	ret z
	cp 2
	ret z
	cp 4
	ret z
	cp 8
	ret z
	jr Invalid
ColorType2:
ColorType4:
ColorType6:
	ld a,(ix + PNG.bitDepth)
	cp 8
	ret z
	cp 16
	ret z
Invalid:
	scf
	ret
	ENDP

; ix = this
PNG_PrintInfo:
	ld hl,PNG_width
	call System_Print
	ld l,(ix + PNG.width)
	ld h,(ix + PNG.width + 1)
	ld e,(ix + PNG.width + 2)
	ld d,(ix + PNG.width + 3)
	call System_PrintDecDEHL
	call System_PrintCrLf
	ld hl,PNG_height
	call System_Print
	ld l,(ix + PNG.height)
	ld h,(ix + PNG.height + 1)
	ld e,(ix + PNG.height + 2)
	ld d,(ix + PNG.height + 3)
	call System_PrintDecDEHL
	call System_PrintCrLf
	ld hl,PNG_bitDepth
	call System_Print
	ld a,(ix + PNG.bitDepth)
	call System_PrintDecA
	call System_PrintCrLf
	ld hl,PNG_colorType
	call System_Print
	ld a,(ix + PNG.colorType)
	call System_PrintDecA
	call System_PrintCrLf
	ld hl,PNG_compression
	call System_Print
	ld a,(ix + PNG.compression)
	call System_PrintDecA
	call System_PrintCrLf
	ld hl,PNG_filter
	call System_Print
	ld a,(ix + PNG.filter)
	call System_PrintDecA
	call System_PrintCrLf
	ld hl,PNG_interlace
	call System_Print
	ld a,(ix + PNG.interlace)
	call System_PrintDecA
	call System_PrintCrLf
	ret

; ix = this
PNG_Show: PROC
Loop:
	call PNG_ReadDoubleWordBE_IY
	exx
	call PNG_ReadDoubleWordBE_IY
	call PNG_ProcessChunk
	push af
	call PNG_ReadDoubleWordBE_IY  ; skip crc
	pop af
	jp nc,Loop
	ret
	ENDP

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- end reached
PNG_ProcessChunk: PROC
	ld a,d
	cp "I"
	jr z,PrefixI
	jp PNG_ProcessUnknownChunk
PrefixI:
	ld a,e
	cp "E"
	jr z,PrefixIE
	jp PNG_ProcessUnknownChunk
PrefixIE:
	ld a,h
	cp "N"
	jr z,PrefixIEN
	jp PNG_ProcessUnknownChunk
PrefixIEN:
	ld a,l
	cp "D"
	jr z,PNG_ProcessIENDChunk
	jp PNG_ProcessUnknownChunk
	ENDP

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- end reached
PNG_ProcessIENDChunk:
	exx
	ld a,l
	or h
	or e
	or d
	ld hl,PNG_invalidPNGError
	jp nz,Application_TerminateWithError
	scf
	ret

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- end reached
PNG_ProcessUnknownChunk:
	exx
	call PNG_SkipDEHL_IY
	and a
	ret

; iy = reader
; dehl <- value
PNG_ReadDoubleWordBE_IY:
	call Reader_Read_IY
	ld d,a
	call Reader_Read_IY
	ld e,a
	call Reader_Read_IY
	ld h,a
	call Reader_Read_IY
	ld l,a
	ret

; dehl = nr of bytes to skip
; iy = this
; Modifies: af, bc, de, hl
PNG_SkipDEHL_IY: PROC
	ld c,l
	ld b,h
	ld a,c
	or b
	call nz,Reader_Skip_IY
	inc de
Loop:
	dec de
	ld a,e
	or d
	ret z
	ld bc,8000H
	call Reader_Skip_IY
	ld bc,8000H
	call Reader_Skip_IY
	jp Loop
	ENDP

PNG_noPNGFileError:
	db "Not a PNG file.",13,10,0

PNG_invalidPNGError:
	db "Invalid PNG file.",13,10,0

PNG_width:
	db "Width: ",0

PNG_height:
	db "Height: ",0

PNG_bitDepth:
	db "Bit depth: ",0

PNG_colorType:
	db "Color type: ",0

PNG_compression:
	db "Compression method: ",0

PNG_filter:
	db "Filter method: ",0

PNG_interlace:
	db "Interlace method: ",0
