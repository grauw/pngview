;
; Top-level application program class
;
Application: MACRO
	pngReference:
		dw 0
	originalBackgroundColor:
		db 0
	originalBorderColor:
		db 0
	cli:
		CLI
	reader:
		FileReader
	png:
		PNG
	pngViewer:
		PNGViewer
	size:
	ENDM

;
Application_Main:
	ld hl,DOS_Terminate
	call System_SetTerminateHandler

	call DOS_IsDOS2
	ld hl,Application_dos2RequiredError
	jp c,System_TerminateWithError

	call Application_CheckStack

	call VDP_InitMirrorsOnVDPUpgrades

	ld hl,Application_welcome
	call System_Print

	ld ix,Mapper_instance
	call Mapper_Construct
	ld ix,Heap_main
	call Heap_Construct

	call MemoryTest_Test
	call HeapTest_Test

	ld ix,Application_instance
	call Application_Construct
	ld de,Application_Abort
	call DOS_DefineAbortExitRoutine
	call Application_EnterMainLoop
	call Application_Abort
	ret

; DOS error or abort handler
Application_Abort:
	push af
	push bc
	ld ix,Mapper_instance
	call Mapper_RestoreInitialState
	ld ix,Application_instance
	call Application_Destruct
	ld ix,Mapper_instance
	call Mapper_Destruct
	pop bc
	pop af
	ret

; ix = this
; ix <- this
Application_Construct:
	ld a,(BAKCLR)
	ld (ix + Application.originalBackgroundColor),a
	ld a,(BDRCLR)
	ld (ix + Application.originalBorderColor),a
	push ix
	call Application_GetCLI
	call CLI_Construct
	pop ix
	ret

; ix = this
; ix <- this
Application_Destruct:
	push ix
	call Application_GetPNGReference
	ld a,e
	or d
	call nz,PNG_Destruct
	pop ix
	push ix
	call Application_GetCLI
	call CLI_Destruct
	pop ix
	call VDP_InitText
	ld a,(ix + Application.originalBackgroundColor)
	ld (BAKCLR),a
	ld a,(ix + Application.originalBorderColor)
	ld (BDRCLR),a
	push ix
	ld ix,CHGCLR
	call System_CallBIOS
	pop ix
	ret

; ix = this
; ix <- Command-line interface
Application_GetCLI:
	ld de,Application.cli
	add ix,de
	ret

; ix = this
; ix <- reader
Application_GetReader:
	ld de,Application.reader
	add ix,de
	ret

; ix = this
; ix <- PNG
Application_GetPNG:
	ld de,Application.png
	add ix,de
	ret

; ix = this
; ix <- PNG
Application_GetPNGReference:
	ld e,(ix + Application.pngReference)
	ld d,(ix + Application.pngReference + 1)
	ld ixl,e
	ld ixh,d
	ret

; ix = this
; ix <- PNG viewer
Application_GetPNGViewer:
	ld de,Application.pngViewer
	add ix,de
	ret

; ix = this
Application_EnterMainLoop:
	call Application_ParseCLI
	call Application_LoadFile
	call Application_ConstructPNG
	call Application_Show
	ret

; ix = this
Application_ParseCLI:
	push ix
	call Application_GetCLI
	call CLI_Parse
	call CLI_GetPath
	ld a,l
	or h
	ld hl,Application_usageInstructions
	jp z,System_TerminateWithError
	pop ix
	ret

; ix = this
Application_LoadFile:
	call Application_PrintLoading
	push ix
	call Application_GetCLI
	call CLI_GetPath
	pop ix
	push ix
	call Application_GetReader
	ex de,hl
	ld hl,READBUFFER
	ld bc,READBUFFER_SIZE
	call FileReader_Construct
	pop ix
	ret

; ix = this
Application_PrintLoading:
	ld hl,Application_loadingFile
	call System_Print
	push ix
	call Application_GetCLI
	call CLI_GetPath
	pop ix
	call System_Print
	ld hl,Application_dotDotDot
	call System_Print
	ret

; ix = this
Application_ConstructPNG:
	push ix
	push ix
	call Application_GetReader
	ex (sp),ix
	call Application_GetPNG
	pop de
	call PNG_Construct
	call PNG_PrintInfo
	ld e,ixl
	ld d,ixh
	pop ix
	ld (ix + Application.pngReference),e
	ld (ix + Application.pngReference + 1),d
	ret

; ix = this
Application_Show:
	ld hl,Application_showing
	call System_Print
	push ix
	call Application_GetPNG
	ex (sp),ix
	call Application_GetPNGViewer
	pop de
	call PNGViewer_Construct
	call PNGViewer_Show
	pop ix
	ret

; Check if the stack is well above the heap
Application_CheckStack:
	ld hl,-(HEAP + HEAP_SIZE + STACK_SIZE)
	add hl,sp
	ld hl,Application_insufficientTPAError
	jp nc,System_TerminateWithError
	ret

; a = DOS error code
Application_CheckDOSError:
	and a
	ret z
Application_TerminateWithDOSError:
	ld b,a
	ld de,Application_explainBuffer
	call DOS_ExplainErrorCode
	ld hl,Application_explainBuffer
	call System_Print
	call System_PrintCrLf
	jp System_TerminateWithError

;
	SECTION RAM

Application_instance: Application

Application_explainBuffer:
	ds 64,0

	ENDS

Application_welcome:
	db "PNGView 1.0 by Grauw",13,10,10,0

Application_loadingFile:
	db "Loading ",0

Application_dotDotDot:
	db "...",13,10,0

Application_showing:
	db 13,10,"Showing...",13,10,0

Application_dos2RequiredError:
	db "MSX-DOS 2 is required.",13,10,0

Application_insufficientTPAError:
	db "Insufficient TPA space.",13,10,0

Application_usageInstructions:
	db "Usage: pngview <image.png>",13,10,0
