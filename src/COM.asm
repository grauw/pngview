;
; PNGView
;
; PNG image viewer
;

	INCLUDE "Macros.asm"

DEBUG: equ 1

HEAP: equ 0C000H
HEAP_SIZE: equ 1180H
STACK_SIZE: equ 100H
READBUFFER_SIZE: equ 0D00H

	org 100H

TPA: ds 2E80H
TPA_PAGE0: ds 0080H
RAM_PAGE0: ds 0300H
RAM_RESIDENT: equ RAM_PAGE0
READBUFFER: ds READBUFFER_SIZE
TPA_PAGE1: ds 3000H
RAM: ds 0F00H
RAM_PAGE1: ds 0100H

	SECTION TPA

;
; Program entry point
;
COM_Main:
	jp Application_Main

	INCLUDE "DOS.asm"
	INCLUDE "BIOS.asm"
	INCLUDE "Class.asm"
	INCLUDE "System.asm"
	INCLUDE "Memory.asm"
	INCLUDE "Mapper.asm"
	INCLUDE "Heap.asm"
	INCLUDE "Application.asm"
	INCLUDE "MappedBuffer.asm"
	INCLUDE "MappedBufferLoader.asm"
	INCLUDE "MappedReader.asm"
	INCLUDE "MappedWriter.asm"
	INCLUDE "Mapped32KWriter.asm"

	; gunzip
	INCLUDE "Archive.asm"
	INCLUDE "deflate/Inflate.asm"
	INCLUDE "deflate/Alphabet.asm"
	INCLUDE "deflate/Branch.asm"
	INCLUDE "deflate/FixedAlphabets.asm"
	INCLUDE "deflate/DynamicAlphabets.asm"
	INCLUDE "Reader.asm"
	INCLUDE "Writer.asm"
	INCLUDE "FileReader.asm"
	INCLUDE "CRC32Checker.asm"

CRC32Table:
	; not present

	ENDS

	SECTION TPA_PAGE1

	INCLUDE "VDP.asm"
	INCLUDE "CLI.asm"
	INCLUDE "PNG.asm"
	INCLUDE "MemoryTest.asm"
	INCLUDE "HeapTest.asm"

	ENDS

	SECTION RAM_PAGE0

Heap_main:
	Heap HEAP, HEAP_SIZE

	ENDS
