;
; Writer backed by a mapped buffer
;
Mapped32KWriter_BASE_ADDRESS: equ 4000H
Mapped32KWriter_SEGMENT_SIZE: equ 4000H
Mapped32KWriter_BUFFER_SIZE: equ 8000H

Mapped32KWriter: MACRO
	super: Writer
	buffer:
		dw 0
	originalSlot1:
		db 0
	originalMapperBank1:
		db 0
	originalSlot2:
		db 0
	originalMapperBank2:
		db 0
	_size:
	ENDM

Mapped32KWriter_class: Class Mapped32KWriter, Mapped32KWriter_template, Heap_main
Mapped32KWriter_template: Mapped32KWriter

; de = mapped buffer
; ix = this
; ix <- this
Mapped32KWriter_Construct:
	ld (ix + Mapped32KWriter.buffer),e
	ld (ix + Mapped32KWriter.buffer + 1),d
	ld hl,Mapped32KWriter_BASE_ADDRESS
	ld bc,Mapped32KWriter_BUFFER_SIZE
	ld de,Mapped32KWriter_Flush
	call Writer_Construct

	call Memory_GetSlotPage1
	ld (ix + Mapped32KWriter.originalSlot1),a
	call Mapper_instance.GetP1
	ld (ix + Mapped32KWriter.originalMapperBank1),a
	call Memory_GetSlotPage2
	ld (ix + Mapped32KWriter.originalSlot2),a
	call Mapper_instance.GetP2
	ld (ix + Mapped32KWriter.originalMapperBank2),a

	push ix
	call Mapped32KWriter_GetBuffer
	call MappedBuffer_AllocateAndAddSegment
	ld h,40H
	call MappedBuffer_SelectSegment
	call MappedBuffer_AllocateAndAddSegment
	ld h,80H
	call MappedBuffer_SelectSegment
	pop ix
	ret

; ix = this
Mapped32KWriter_Destruct:
	ld a,(ix + Mapped32KWriter.originalSlot1)
	call Memory_SetSlotPage1
	ld a,(ix + Mapped32KWriter.originalMapperBank1)
	call Mapper_instance.PutP1
	ld a,(ix + Mapped32KWriter.originalSlot2)
	call Memory_SetSlotPage2
	ld a,(ix + Mapped32KWriter.originalMapperBank2)
	call Mapper_instance.PutP2
	ret

; ix = this
; de <- buffer
; ix <- buffer
Mapped32KWriter_GetBuffer:
	ld e,(ix + Mapped32KWriter.buffer)
	ld d,(ix + Mapped32KWriter.buffer + 1)
	ld ixl,e
	ld ixh,d
	ret

; bc = byte count
; de = buffer start
; ix = this
; Modifies: af, hl
Mapped32KWriter_Flush:
	push bc
	push de
	call Mapped32KWriter_CopyToMappedBuffer
	pop de
	pop bc
	ret

; ix = this
Mapped32KWriter_CopyToMappedBuffer: PROC
	push bc
	push de
	push ix
	call Mapped32KWriter_GetBuffer
	call MappedBuffer_IncreaseSize
	pop ix
	pop de
	pop bc
	ld hl,Mapped32KWriter_BASE_ADDRESS + Mapped32KWriter_BUFFER_SIZE
	and a
	sbc hl,de
	call c,System_ThrowException
	sbc hl,bc
	call c,System_ThrowException
	ret nz
	ld hl,Mapped32KWriter_BASE_ADDRESS
	sbc hl,de
	call nz,System_ThrowException
Loop:
	ld hl,-Mapped32KWriter_SEGMENT_SIZE
	add hl,bc
	push hl
	jp nc,NoCap
	ld bc,Mapped32KWriter_SEGMENT_SIZE
NoCap:
	push bc
	push ix
	call Mapped32KWriter_GetBuffer
	call MappedBuffer_AllocateAndAddSegment
	ld h,80H
	call MappedBuffer_SelectSegment
	pop ix
	pop bc
	ld hl,4000H
	ld de,8000H
	call System_FastLDIR
	push ix
	call Mapped32KWriter_GetBuffer
	call MappedBuffer_GetSegmentCount
	sub 2
	ld h,40H
	call MappedBuffer_SelectSegment
	pop ix
	pop bc
	dec bc
	bit 7,b
	inc bc
	jr z,Loop
	ret
	ENDP
