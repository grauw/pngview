;
; Memory-mapped buffer
;
MappedBuffer: MACRO
	size:
		dd 0
	freebie:
		dw 0
	segmentCount:
		db 0
	segments:
		ds 255 * 2
	_size:
	ENDM

; ix = this
MappedBuffer_Construct:
	ret

; ix = this
MappedBuffer_Destruct:
	ret

; a = segment number
; b = slot id
; ix = this
MappedBuffer_SetFreebie:
	ld (ix + MappedBuffer.freebie),a
	ld (ix + MappedBuffer.freebie + 1),b
	ret

; ix = this
; a <- nr of segments
MappedBuffer_GetSegmentCount:
	ld a,(ix + MappedBuffer.segmentCount)
	ret

; h = address space page
; a = segment index
; ix = this
; a <- segment
; Modifies: af
MappedBuffer_SelectSegment:
	cp (ix + MappedBuffer.segmentCount)
	call nc,System_ThrowException
	push bc
	push de
	push hl
	push ix
	ld e,a
	ld d,0
	add ix,de
	add ix,de
	ld a,(ix + MappedBuffer.segments + 1)
	push hl
	call Memory_SetSlot
	pop hl
	ld a,(ix + MappedBuffer.segments)
	call Mapper_instance.PutPH
	pop ix
	pop hl
	pop de
	pop bc
	ret

; ix = this
; a <- new segment index
MappedBuffer_AllocateAndAddSegment: PROC
	ld a,(ix + MappedBuffer.segmentCount)
	and a
	jr nz,Continue
	or (ix + MappedBuffer.freebie + 1)
	jr nz,Freebie
Continue:
	call MappedBuffer_AllocateSegment
	call MappedBuffer_AddSegment
	ret
Freebie:
	ld a,(ix + MappedBuffer.freebie)
	ld b,(ix + MappedBuffer.freebie + 1)
	call MappedBuffer_AddSegment
	ret
	ENDP

; ix = this
; a <- segment number
; b <- slot id
MappedBuffer_AllocateSegment:
	ld a,(Mapper_instance.primaryMapperSlot)
	or 00100000B  ; allocate primary slot, or another
	ld b,a
	ld a,0
	call Mapper_instance.Allocate
	ld hl,MappedBuffer_outOfMemoryError
	jp c,System_TerminateWithError
	ret

; a = segment number
; b = slot id
; ix = this
; a <- new segment index
; Modifies: de, hl
MappedBuffer_AddSegment:
	ld e,(ix + MappedBuffer.segmentCount)
	inc e
	ld hl,MappedBuffer_outOfMemoryError
	jp z,System_TerminateWithError
	ld (ix + MappedBuffer.segmentCount),e
	dec e
	ld d,0
	push ix
	add ix,de
	add ix,de
	ld (ix + MappedBuffer.segments),a
	ld (ix + MappedBuffer.segments + 1),b
	pop ix
	ld a,e
	ret

; bc = size to add
; ix = this
MappedBuffer_IncreaseSize:
	ld l,(ix + MappedBuffer.size)
	ld h,(ix + MappedBuffer.size + 1)
	ld a,(ix + MappedBuffer.size + 2)
	add hl,bc
	adc a,0
	ld (ix + MappedBuffer.size),l
	ld (ix + MappedBuffer.size + 1),h
	ld (ix + MappedBuffer.size + 2),a
	ret

; ehl = position
; ix = this
; f <- nc: position points past the end
; Modifies: af
MappedBuffer_IsValidPosition:
	ld a,e
	cp (ix + MappedBuffer.size + 2)
	ret c
	ld a,h
	cp (ix + MappedBuffer.size + 1)
	ret c
	ld a,l
	cp (ix + MappedBuffer.size)
	ret

;
	SECTION RAM_PAGE0

MappedBuffer_instance: MappedBuffer

	ENDS

MappedBuffer_outOfMemoryError:
	db "Not enough memory.",13,10,0
