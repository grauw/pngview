;
; Reader backed by a mapped buffer
;
MappedReader_SEGMENT_SIZE: equ 4000H

MappedReader: MACRO
	super: Reader
	buffer:
		dw 0
	positionSegmentIndex:
		db -1
	size:
	ENDM

; de = mapped buffer
; hl = base address
; ix = this
; ix <- this
MappedReader_Construct:
	ld a,l
	and a
	call nz,System_ThrowException
	ld a,h
	and 3FH
	call nz,System_ThrowException
	ld (ix + MappedReader.buffer),e
	ld (ix + MappedReader.buffer + 1),d
	ld bc,MappedReader_SEGMENT_SIZE
	ld de,MappedReader_Fill_IY
	call Reader_Construct
	ret

; iy = this
; de <- buffer
; ix <- buffer
MappedReader_GetBuffer_IY:
	ld e,(iy + MappedReader.buffer)
	ld d,(iy + MappedReader.buffer + 1)
	ld ixl,e
	ld ixh,d
	ret

; ehl = address
; iy = this
MappedReader_SetPosition_IY:
	push ix
	ld a,e
	call MappedReader_GetBuffer_IY
	ld e,a
	call MappedBuffer_IsValidPosition
	jp nc,MappedReader_ThrowAddressOutOfBounds
	ld a,h
	and 3FH
	or 80H
	ld (iy + MappedReader.super.bufferPosition),l
	ld (iy + MappedReader.super.bufferPosition + 1),a
	ld (iy + MappedReader.super.fillPending),0
	ld a,h
	rla
	rl e
	rla
	rl e
	ld (iy + MappedReader.positionSegmentIndex),e
	ld a,e
	ld h,(iy + MappedReader.super.bufferStart + 1)
	call MappedBuffer_SelectSegment
	pop ix
	ret

; iy = this
; dehl <- address
MappedReader_GetPosition_IY: PROC
	ld l,(iy + MappedReader.super.bufferPosition)
	ld h,(iy + MappedReader.super.bufferPosition + 1)
	ld a,(iy + MappedReader.positionSegmentIndex)
	bit 0,(iy + MappedReader.super.fillPending)
	call nz,FillPending
	rlc h
	rlc h
	rrca
	rr h
	rrca
	rr h
	and 3FH
	ld e,a
	ld d,0
	ret
FillPending:
	ld l,(iy + MappedReader.super.bufferStart)
	ld h,(iy + MappedReader.super.bufferStart + 1)
	inc a
	ret
	ENDP

; ehl = nr of bytes to skip
; iy = this
MappedReader_Skip_IY:
	ld a,d
	and a
	jp nz,MappedReader_ThrowAddressOutOfBounds
	push de
	push hl
	call MappedReader_GetPosition_IY
	pop bc
	add hl,bc
	pop bc
	ex de,hl
	adc hl,bc
	ex de,hl
	jp c,MappedReader_ThrowAddressOutOfBounds
	call MappedReader_SetPosition_IY
	ret

; de = destination address
; bc = bytes count
; iy = this
MappedReader_ReadBlock_IY: PROC
Loop:
	ld a,c
	or b
	ret z
	push bc
	call Reader_ReadBlockDirect_IY
	push bc
	call System_FastLDIR
	pop bc
	pop hl
	and a
	sbc hl,bc
	call c,System_ThrowException
	ld c,l
	ld b,h
	jp Loop
	ENDP

; bc = byte count
; de = buffer start
; iy = this
; Modifies: af, hl
MappedReader_Fill_IY:
	push bc
	push de
	call MappedReader_SelectNextSegment_IY
	pop de
	pop bc
	ret

; iy = this
MappedReader_SelectNextSegment_IY:
	ld a,(iy + MappedReader.positionSegmentIndex)
	inc a
	ld (iy + MappedReader.positionSegmentIndex),a
	push de
	push ix
	call MappedReader_GetBuffer_IY
	ld h,(iy + MappedReader.super.bufferStart + 1)
	call MappedBuffer_SelectSegment
	pop ix
	pop de
	ret

MappedReader_ThrowAddressOutOfBounds:
	ld hl,MappedReader_addressOutOfBoundsError
	call System_ThrowExceptionWithMessage
	ret

;
MappedReader_addressOutOfBoundsError:
	db "Address out of bounds.",13,10,0
