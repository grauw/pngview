;
; Reader backed by a mapped buffer, reading indirectly via a regular buffer
;
IndirectMappedReader: MACRO
	super: Reader
	mappedReader:
		MappedReader
	_size:
	ENDM

IndirectMappedReader_class: Class IndirectMappedReader, IndirectMappedReader_template, Heap_main
IndirectMappedReader_template: IndirectMappedReader

; de = mapped buffer
; hl = buffer start
; bc = buffer size
; ix = this
; ix <- this
; de <- this
IndirectMappedReader_Construct:
	push de
	ld de,IndirectMappedReader_Fill_IY
	call Reader_Construct
	pop de
	push ix
	ld bc,IndirectMappedReader.mappedReader
	add ix,bc
	ld hl,8000H
	call MappedReader_Construct
	pop ix
	ld e,ixl
	ld d,ixh
	ret

; ix = this
; ix <- this
IndirectMappedReader_Destruct:
	push ix
	ld de,IndirectMappedReader.mappedReader
	call MappedReader_Destruct
	pop ix
	call Reader_Destruct
	ret

; bc = byte count
; de = buffer start
; iy = this
; Modifies: af, bc, de, hl
IndirectMappedReader_Fill_IY:
	push bc
	push de
	push ix
	push iy
	push bc
	push de
	ld bc,IndirectMappedReader.mappedReader
	add iy,bc
	ld h,(iy + MappedReader.super.bufferStart + 1)
	push hl
	call Memory_GetSlot
	pop hl
	ld l,a
	push hl
	call Mapper_instance.GetPH
	push af
	ld a,(iy + MappedReader.positionSegmentIndex)  ; yuck
	cp -1
	call nz,MappedReader_SelectCurrentSegment_IY
	pop af
	pop hl
	pop de
	pop bc
	push hl
	push af
	call MappedReader_ReadBlock_IY
	pop af
	pop hl
	call Mapper_instance.PutPH
	ld a,l
	call Memory_SetSlot
	pop iy
	pop ix
	pop de
	pop bc
	ret
