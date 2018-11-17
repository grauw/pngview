;
; PNG image
;
PNG_WRITER_BASE_ADDRESS: equ 8000H

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
	palette:
		dw 0
	rawDataBuffer:
		dw 0
	dataBuffer:
		dw 0
	dataWriter:
		dw 0
	paletteData:
		ds 256 * 3
	transparencyData:
		ds 256,255
	ENDM

; de = reader
; ix = this
; ix <- this
PNG_Construct:
	ld (ix + PNG.reader),e
	ld (ix + PNG.reader + 1),d
	push ix
	call MappedBuffer_class.New
	call MappedBuffer_Construct
	pop ix
	ld (ix + PNG.dataBuffer),e
	ld (ix + PNG.dataBuffer + 1),d
	push ix
	ld hl,PNG_WRITER_BASE_ADDRESS
	call MappedWriter_class.New
	call MappedWriter_Construct
	pop ix
	ld (ix + PNG.dataWriter),e
	ld (ix + PNG.dataWriter + 1),d
	push ix
	call MappedBuffer_class.New
	call MappedBuffer_Construct
	pop ix
	ld (ix + PNG.rawDataBuffer),e
	ld (ix + PNG.rawDataBuffer + 1),d
	call PNG_GetReaderIY
	call PNG_ReadMagicNumber
	call PNG_ReadIHDR
	call PNG_Validate
	jp c,PNG_TerminateWithInvalidError
	call PNG_Process
	call PNG_ValidatePalette
	jp c,PNG_TerminateWithInvalidError
	call PNG_Decompress
	ret

; ix = this
; ix <- this
PNG_Destruct:
	push ix
	call PNG_GetRawDataBuffer
	call MappedBuffer_Destruct
	call MappedBuffer_class.Delete
	pop ix
	push ix
	call PNG_GetDataWriter
	call MappedWriter_Destruct
	call MappedWriter_class.Delete
	pop ix
	push ix
	call PNG_GetDataBuffer
	call MappedBuffer_Destruct
	call MappedBuffer_class.Delete
	pop ix
	ret

; ix = this
; iy <- reader
PNG_GetReaderIY:
	ld e,(ix + PNG.reader)
	ld d,(ix + PNG.reader + 1)
	ld iyl,e
	ld iyh,d
	ret

; ix = this
; f <- nz: palette exists
PNG_HasPalette:
	ld a,(ix + PNG.palette + 1)
	and a
	ret

; ix = this
; de <- palette
PNG_GetPalette:
	ld e,(ix + PNG.palette)
	ld d,(ix + PNG.palette + 1)
	ret

; ix = this
; hl <- transparency
PNG_GetTransparency:
	ld e,ixl
	ld d,ixh
	ld hl,PNG.transparencyData
	add hl,de
	ret

; ix = this
; ix <- mapped buffer
PNG_GetDataBuffer:
	ld e,(ix + PNG.dataBuffer)
	ld d,(ix + PNG.dataBuffer + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; ix <- mapped writer
PNG_GetDataWriter:
	ld e,(ix + PNG.dataWriter)
	ld d,(ix + PNG.dataWriter + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; ix <- mapped buffer
PNG_GetRawDataBuffer:
	ld e,(ix + PNG.rawDataBuffer)
	ld d,(ix + PNG.rawDataBuffer + 1)
	ld ixl,e
	ld ixh,d
	ret

; iy = reader
; ix = this
PNG_ReadMagicNumber:
	call Reader_Read_IY
	cp 137
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "P"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "N"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "G"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 13
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 10
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 26
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 10
	jp nz,PNG_TerminateWithInvalidError
	ret

; iy = reader
; ix = this
PNG_ReadIHDR:
	call Reader_Read_IY
	cp 0
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 0
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 0
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp 13
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "I"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "H"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "D"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_Read_IY
	cp "R"
	jp nz,PNG_TerminateWithInvalidError
	call Reader_ReadDoubleWordBE_IY
	ld a,l
	or h
	or e
	or d
	jp z,PNG_TerminateWithInvalidError
	ld (ix + PNG.width),l
	ld (ix + PNG.width + 1),h
	ld (ix + PNG.width + 2),e
	ld (ix + PNG.width + 3),d
	call Reader_ReadDoubleWordBE_IY
	ld a,l
	or h
	or e
	or d
	jp z,PNG_TerminateWithInvalidError
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
	call Reader_ReadDoubleWordBE_IY  ; skip crc
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
	jr z,ColorType0
	cp 2
	jr z,ColorType2
	cp 3
	jr z,ColorType3
	cp 4
	jr z,ColorType4
	cp 6
	jr z,ColorType6
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
; f <- c: invalid
PNG_ValidatePalette:
	ld a,(ix + PNG.colorType)
	sub 3
	and a
	ret nz
	cp (ix + PNG.palette + 1)
	ccf
	ret

; ix = this
; bc <- line size
PNG_GetLineSize: PROC
	ld l,(ix + PNG.width)
	ld h,(ix + PNG.width + 1)
	ld e,(ix + PNG.width + 2)
	ld d,(ix + PNG.width + 3)
	ld a,e
	or d
	jp nz,PNG_TerminateWithUnsupportedError
	ld a,(ix + PNG.bitDepth)
	cp 1
	jr z,BitDepth1
	cp 2
	jr z,BitDepth2
	cp 4
	jr z,BitDepth4
	cp 8
	jr z,BitDepth8
BitDepth16:
	add hl,hl
	jp c,PNG_TerminateWithUnsupportedError
	jp BitDepthDone
BitDepth1:
	inc hl
	srl h
	rr l
BitDepth2:
	inc hl
	srl h
	rr l
BitDepth4:
	inc hl
	srl h
	rr l
BitDepth8:
BitDepthDone:
	ld a,(ix + PNG.colorType)
	cp 0
	jr z,ColorType0
	cp 2
	jr z,ColorType2
	cp 3
	jr z,ColorType3
	cp 4
	jr z,ColorType4
ColorType6:
	add hl,hl
	jp c,PNG_TerminateWithUnsupportedError
ColorType4:
	add hl,hl
	jp c,PNG_TerminateWithUnsupportedError
	ret
ColorType2:
	ex de,hl
	ld hl,0
	add hl,de
	add hl,de
	jp c,PNG_TerminateWithUnsupportedError
	add hl,de
	jp c,PNG_TerminateWithUnsupportedError
ColorType0:
ColorType3:
ColorTypeDone:
	ret
	ENDP

; ix = this
; a <- bytes per pixel
PNG_GetBytesPerPixel: PROC
	ld b,1
	ld a,(ix + PNG.colorType)
	cp 2
	jr z,ColorType2
	cp 4
	jr z,ColorType4
	cp 6
	jr nz,BitDepth
ColorType6:
	inc b
ColorType2:
	inc b
ColorType4:
	inc b
BitDepth:
	bit 4,(ix + PNG.bitDepth)
	ld a,b
	ret z
	add a,a
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
PNG_Decompress:
	push ix
	push ix
	call PNG_GetDataBuffer
	ld hl,READBUFFER
	ld bc,READBUFFER_SIZE
	call IndirectMappedReader_class.New
	call IndirectMappedReader_Construct
	ld e,ixl
	ld d,ixh
	ex (sp),ix  ; sp = this, reader, ix = this
	push ix
	ld a,ZLIB_ADLER32 ? -1 : 0
	call ZlibArchive_class.New
	call ZlibArchive_Construct
	ex (sp),ix  ; sp = this, reader, zlibarchive, ix = this
	call PNG_GetRawDataBuffer
	call Mapped32KWriter_class.New
	call Mapped32KWriter_Construct
	ld e,ixl
	ld d,ixh
	ex (sp),ix  ; sp = this, reader, writer, ix = zlibarchive
	push ix
	ld hl,ZlibArchive_Extract
	call System_TryCall
	pop ix
	ex (sp),ix
	call Mapped32KWriter_Destruct
	call Mapped32KWriter_class.Delete
	pop ix
	call ZlibArchive_Destruct
	call ZlibArchive_class.Delete
	pop ix
	call IndirectMappedReader_Destruct
	call IndirectMappedReader_class.Delete
	pop ix
	call System_Rethrow
	ret

; ix = this
PNG_Process: PROC
Loop:
	call Reader_ReadDoubleWordBE_IY
	bit 7,d
	jp nz,PNG_TerminateWithInvalidError
	exx
	call Reader_ReadDoubleWordBE_IY
	call PNG_ProcessChunk
	push af
	call Reader_ReadDoubleWordBE_IY  ; skip crc
	pop af
	jr nc,Loop
	ret
	ENDP

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: end reached
PNG_ProcessChunk: PROC
	ld a,d
	cp "I"
	jr z,PrefixI
	cp "P"
	jr z,PrefixP
	cp "t"
	jr z,Prefixt
	jp PNG_ProcessUnknownChunk
PrefixI:
	ld a,e
	cp "D"
	jr z,PrefixID
	cp "E"
	jr z,PrefixIE
	jp PNG_ProcessUnknownChunk
PrefixP:
	ld a,e
	cp "L"
	jr z,PrefixPL
	jp PNG_ProcessUnknownChunk
Prefixt:
	ld a,e
	cp "R"
	jr z,PrefixtR
	jp PNG_ProcessUnknownChunk
PrefixID:
	ld a,h
	cp "A"
	jr z,PrefixIDA
	jp PNG_ProcessUnknownChunk
PrefixIE:
	ld a,h
	cp "N"
	jr z,PrefixIEN
	jp PNG_ProcessUnknownChunk
PrefixPL:
	ld a,h
	cp "T"
	jr z,PrefixPLT
	jp PNG_ProcessUnknownChunk
PrefixtR:
	ld a,h
	cp "N"
	jr z,PrefixtRN
	jp PNG_ProcessUnknownChunk
PrefixIDA:
	ld a,l
	cp "T"
	jr z,PNG_ProcessIDATChunk
	jp PNG_ProcessUnknownChunk
PrefixIEN:
	ld a,l
	cp "D"
	jr z,PNG_ProcessIENDChunk
	jp PNG_ProcessUnknownChunk
PrefixPLT:
	ld a,l
	cp "E"
	jr z,PNG_ProcessPLTEChunk
	jp PNG_ProcessUnknownChunk
PrefixtRN:
	ld a,l
	cp "S"
	jr z,PNG_ProcessTRNSChunk
	jp PNG_ProcessUnknownChunk
	ENDP

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: not set (end not reached)
PNG_ProcessPLTEChunk:
	call PNG_HasPalette
	jp nz,PNG_TerminateWithInvalidError
	exx
	ld a,e
	or d
	jp nz,PNG_TerminateWithInvalidError
	ex de,hl
	ld hl,300H
	sbc hl,de
	jp c,PNG_TerminateWithInvalidError
	ld c,e
	ld b,d
	ld e,ixl
	ld d,ixh
	ld hl,PNG.paletteData
	add hl,de
	ex de,hl
	ld (ix + PNG.palette),e
	ld (ix + PNG.palette + 1),d
	call Reader_ReadBlock_IY
	and a
	ret

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: not set (end not reached)
PNG_ProcessTRNSChunk:
	exx
	ld a,e
	or d
	jp nz,PNG_TerminateWithInvalidError
	ex de,hl
	ld hl,100H
	sbc hl,de
	jp c,PNG_TerminateWithInvalidError
	ld c,e
	ld b,d
	call PNG_GetTransparency
	ex de,hl
	call Reader_ReadBlock_IY
	and a
	ret

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: not set (end not reached)
PNG_ProcessIDATChunk:
	push ix
	call PNG_GetDataWriter
	exx
	ld c,l
	ld b,h
	call Writer_CopyFromReader32
	pop ix
	and a
	ret

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: set (end reached)
PNG_ProcessIENDChunk:
	exx
	ld a,l
	or h
	or e
	or d
	jp nz,PNG_TerminateWithInvalidError
	scf
	ret

; dehl = name
; dehl' = size
; iy = reader
; ix = this
; f <- c: not set (end not reached)
PNG_ProcessUnknownChunk:
	ld a,d
	call PNG_CheckChunkNameCharacter
	ld a,e
	call PNG_CheckChunkNameCharacter
	ld a,h
	call PNG_CheckChunkNameCharacter
	ld a,l
	call PNG_CheckChunkNameCharacter
	exx
	ld c,l
	ld b,h
	call Reader_Skip32_IY
	and a
	ret

; a = character
PNG_CheckChunkNameCharacter:
	cp 65
	jr c,PNG_TerminateWithInvalidError
	cp 91
	ret c
	cp 97
	jr c,PNG_TerminateWithInvalidError
	cp 123
	ret c
	jr PNG_TerminateWithInvalidError

; ix = this
PNG_TerminateWithInvalidError:
	ld hl,PNG_invalidPNGError
	jp System_ThrowExceptionWithMessage

; ix = this
PNG_TerminateWithUnsupportedError:
	ld hl,PNG_unsupportedError
	jp System_ThrowExceptionWithMessage

;
PNG_invalidPNGError:
	db "Invalid PNG file.",13,10,0

PNG_unsupportedError:
	db "Unsupported PNG feature.",13,10,0

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
