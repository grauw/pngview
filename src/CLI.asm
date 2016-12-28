;
; Command-line interface parser
;
CLI: MACRO
	path:
		dw 0
	buffer:
		ds 255
	size:
	ENDM

; ix = this
; ix <- this
CLI_Construct:
	call CLI_GetBuffer
	ld hl,CLI_parametersEnvName
	ld b,255
	call DOS_GetEnvironmentItem
	ret

; ix = this
; ix <- this
CLI_Destruct:
	ret

; ix = this
; de <- buffer
; Modifies: bc
CLI_GetBuffer:
	push ix
	pop de
	ld bc,CLI.buffer
	ex de,hl
	add hl,bc
	ex de,hl
	ret

; ix = this
; hl <- path
CLI_GetPath:
	ld l,(ix + CLI.path)
	ld h,(ix + CLI.path + 1)
	ret

; ix = this
CLI_Parse: PROC
	call CLI_GetBuffer
Loop:
	ld a,(de)
	and a
	ret z
	cp "/"
	jr z,Option
	cp " "
	jr nz,Path
	inc de
	jp Loop
Option:
	call CLI_ParseOption
	jp Loop
Path:
	call CLI_ParsePath
	jp Loop
	ENDP

; de = buffer position
; ix = this
CLI_ParseOption: PROC
	inc de
	ld a,(de)
	and 11011111B  ; upper-case
	ld hl,CLI_unknownOptionError
	jp Application_TerminateWithError
Next:
	ld a,(de)
	and a
	ret z
	cp " "
	ret z
	ld hl,CLI_unknownOptionError
	jp Application_TerminateWithError
	ENDP

; de = buffer position
; ix = this
CLI_ParsePath:
	ld a,(ix + CLI.path)
	or (ix + CLI.path + 1)
	ld hl,CLI_multiplePathsError
	jp nz,Application_TerminateWithError
	ld (ix + CLI.path),e
	ld (ix + CLI.path + 1),d
	call DOS_ParsePathname
	ld a,(de)
	and a
	ret z
	ld a,0
	ld (de),a
	inc de
	ret

;
CLI_parametersEnvName:
	db "PARAMETERS",0

CLI_unknownOptionError:
	db "Unknown command line option.",13,10,0

CLI_multiplePathsError:
	db "Can not specify more than one file path.",13,10,0
