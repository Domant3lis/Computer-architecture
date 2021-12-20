.model large
.stack 100h

CAPACITY equ 20h

.data
	; Input and output buffers
	input db (CAPACITY) dup (0)
    output db (CAPACITY) * 100 dup (0)

	; File name buffers
	input_file_arg db 128 dup (0)
	output_file_arg db 128 dup (0)
	
	; File handles
	input_hnd dw 0000h
	output_hnd dw 0000h

	; Amount of bytes read
    bytes_read dw ?
    bytes_scanned dw (CAPACITY)
	bytes_written dw 0


	; Command line option buffer
	cmd_buff db 128 dup(0)

    ; Messages to the user
	msg_help db "This program partially disassembles a COM executable", 10, 13, "/i ARG specifies input, where ARG is the path to the COM executable", 10, 13, "/o ARG specifies the output file in which the disassembled program will be saved, where ARG is the path to the output file$"
	msg_invalid_opt db "Invalid option(s)!$"
	msg_fail_open db "Failed to open the file!$"
	msg_fail_read db "Failed to read from the file!$"
	msg_no_arg db "Each file option has to have a path specified$"
	msg_too_many_opts db "There must exactly be one option supplied for input and output$"

	str_op_buffer db 32 dup (?)

	; Instruction position
	pos dw 0100h

	; Opcode strings
	strop_push db   " push ", 0
	strop_pop db    " pop ", 0
	strop_and db    " and ", 0
	strop_lea db    " lea ", 0
	strop_lds db    " lds ", 0
	strop_dec db    " dec ", 0
	strop_loop db   " loop ", 0
	strop_loope db  " loope ", 0
	strop_loopne db " loopne ", 0
	strop_unreg db  " Unrecognized opcode", 0

	; Stuff
	d db 0
	w db 0
	sreg db 0
	reg db 0
	rm db 0
	mmod db 0

	; Registers
	reg_ax db 00000000b
	reg_bx db 00000011b
	reg_cx db 00000001b
	reg_dx db 00000010b

	str_sign_plus db "+", 0
	str_sign_lbracket db "[", 0
	str_sign_rbracket db "]", 0


	strreg_ax db "AX", 0
	strreg_bx db "BX", 0
	strreg_cx db "CX", 0
	strreg_dx db "DX", 0

	strsreg_es db "ES", 0
	strsreg_cs db "CS", 0
	strsreg_ss db "SS", 0
	strsreg_ds db "DS", 0

	str_si db "SI", 0
	str_di db "DI", 0

.code
START:
    mov dx, @data
    mov ds, dx

	; Count of characters in command line options
    mov cl, es:[80h]
    ; SI gets incremented right after, as so it's 80h and not 81h
    mov si, 80h

	cmp cl, 0
	jne PARSE_OPTS

PRINT_HELP:
	mov dx, offset msg_help
	mov ah, 09h
	int 21h
	jmp EXIT

; OPTION PARSING
PARSE_OPTS:
	inc si
	mov dl, es:[si]

	; Ignores spaces
	cmp dl, " "
	je PARSE_OPTS

	; The end of file was reached 
	cmp dl, 13
	je FILE_OPEN

	cmp dl, "/"
	jne PRINT_INVALID_OPT

	inc si
	mov dl, es:[si]

	cmp dl, "?"
	je PRINT_HELP

	cmp dl, "o"
	je @@OUT

	cmp dl, "i"
	jne PRINT_INVALID_OPT
	
	; Check for incorrect input, in this case too many /i inputs
	cmp bl, 0
	jne PRINT_TOO_MANY_OPTS
	
	inc bl	
	mov di, offset input_file_arg

	jmp @@SKIP_SPACE

; bl is used as a flag for input
; bh - for output
@@OUT:
	; Check for incorrect input, in this case too many /o inputs
	cmp bh, 0
	jne PRINT_TOO_MANY_OPTS

	inc bh
	lea di, output_file_arg
@@SKIP_SPACE:
	inc si
	mov dl, es:[si]

	cmp dl, " "
	je @@SKIP_SPACE

	cmp dl, 13
	je PRINT_MISSING_ARG

@@FILE_OPT:

	mov dl, es:[si]
	
	cmp dl, " "
	je PARSE_OPTS

	cmp dl, 13
	je FILE_OPEN

	mov ds:[di], dl

   	inc si
	inc di
	
	loop @@FILE_OPT

; This section is used only to print certain messages to the user
PRINT_MISSING_ARG:
	mov dx, offset msg_no_arg
	mov ah, 09h
	int 21h
	jmp EXIT

PRINT_TOO_MANY_OPTS:
	mov dx, offset msg_too_many_opts
	mov ah, 09h
	int 21h
	jmp EXIT

PRINT_INVALID_OPT:
	mov dx, offset msg_invalid_opt
	mov ah, 09h
	int 21h
	jmp EXIT

PRINT_FAIL_OPEN:
	mov dx, offset msg_fail_open
	mov ah, 09h
	int 21h
	jmp EXIT

FILE_OPEN:
	; sets up an input file handle
	mov ax, 3D00h
    mov dx, offset input_file_arg
    int 21h
    mov [input_hnd], ax
	jnc @@NOT_FAIL_INPUT
	call PRINT_FAIL_OPEN
@@NOT_FAIL_INPUT:
	; creates the output file
	xor cx, cx
	mov ax, 3C02h
	lea dx, output_file_arg
	int 21h
	mov output_hnd, ax	
	jnc @@NOT_FAIL_OUTPUT
	mov [output_hnd], 1
@@NOT_FAIL_OUTPUT:

	; mov cx, 30
DISASSEMBLE:
	
	call COLUMN
	call GET_BYTE	

; --- PREFIX BYTE ----
	mov al, [si]
	and al, 11100111b
	cmp al, 00100110b
	jne @@NOT_OP_PREFIX

	mov al, [si]
	and al, 00011000b
	shr al, 3
	mov [mmod], al

@@NOT_OP_PREFIX:

; --- POP3 ---
	mov al, [si]
	and al, 11100111b
	cmp al, 00000111b
	jne @@NOT_OP_POP3

	lea dx, strop_pop
	call STR_ADD

	mov al, [si]
	shr al, 3
	mov [sreg], al
	call STR_SREG
	jmp OP_END

@@NOT_OP_POP3:
; --- POP1 ---
	mov al, [si]
	cmp al, 10001111b
	jne @@NOT_OP_POP1

	call GET_BYTE

	; Gets mod
	mov al, [si]
	and al, 11000000b
	SHR al, 6
	mov [mmod], al
	; Gets r/m
	mov al, [si]
	and al, 00000111b
	mov [rm], al

	lea dx, strop_pop
	call STR_ADD

	; lea dx, str_op_buffer
	; call STR_ADD

	jmp OP_END

@@NOT_OP_POP1:
; --- PUSH2 ---
	mov al, [si]
	and al, 11111000b
	cmp al, 01010000b
	jne @@NOT_OP_PUSH2

	lea dx, strop_push
	call STR_ADD

	mov al, [si]
	mov [reg], al
	call STR_REG
	jmp @@OP_END
	; cmp al, 1
	; jb @@NOT_OP_PUSH2

	; sub di, 5
	; sub bytes_written, 5

@@NOT_OP_PUSH2:
; --- POP2 ---
	mov al, [si]
	and al, 11111000b
	cmp al, 01011000b
	jne @@NOT_OP_POP2

	lea dx, strop_pop
	call STR_ADD

	mov al, [si]
	mov [reg], al
	call STR_REG
	jmp @@OP_END

@@OP_END:
	cmp al, 1
	jb OP_END

	sub di, 5
	sub bytes_written, 5
@@NOT_OP_POP2:
; --- DEC1 ---
	mov al, [si]
	and al, 11111110b
	cmp al, 11111110b
	jne @@NOT_OP_DEC1

	mov al, [si]
	and al, 00000001b
	mov w, al

	call GET_BYTE

	mov al, [si]
	and al, 11000000b
	mov [mmod], al

	mov al, [si]
	and al, 00000111b
	mov [rm], al

	call MOD_RM

	lea dx, strop_dec
	call STR_ADD

	jmp OP_END
@@NOT_OP_DEC1:

; --- DEC2 ---
	mov al, [si]
	and al, 11111000b
	cmp al, 01001000b
	jne @@NOT_OP_DEC2

	lea dx, strop_dec
	call STR_ADD

	mov al, [si]
	mov [reg], al
	call STR_REG

	jmp OP_END

@@NOT_OP_DEC2:
	lea dx, strop_unreg
	call STR_ADD


OP_END:
	; End line
	mov byte ptr [di], 13
	inc bytes_written
	inc di

	mov byte ptr [di], 10
	inc bytes_written
	inc di

	jmp DISASSEMBLE

EXIT:
; Closes the file handles
	; input
	mov ah, 3Eh
	mov bx, input_hnd
	int 21h
	; output
	mov ah, 3Eh
	mov bx, output_hnd
	int 21h

; exits the program
	mov ax, 4C00h
	int 21h

; --- ALL SUBROUTINES BELOW ---
PRINT_FAIL_READ:
	mov dx, offset msg_fail_read
	mov ah, 09h
	int 21h
	jmp EXIT
COLUMN:
; Save column information to di
; -- BH --
	mov bx, [pos]
	xor ax, ax
	mov al, bh
	mov cl, 16
	div cl 

	call TO_HEX
	mov [di], al

	mov al, ah
	call TO_HEX
	inc di
	mov [di], al

; -- BL --
	mov bx, [pos]
	xor ax, ax
	mov al, bl
	mov cl, 16
	div cl 

	call TO_HEX
	inc di
	mov [di], al

	mov al, ah
	call TO_HEX
	inc di
	mov [di], al
	inc di

	mov byte ptr [di], " "
	inc di

	mov byte ptr [di], " "
	inc di

	add bytes_written, 6

	ret

; Takes a byte from [si] and
; saves hex representation to a string in di  
BYTE_TO_STR:
	xor ax, ax
	mov al, [si]
	mov cl, 16
	div cl
	; al = ax / cl
	; ah = ax % cl

	call TO_HEX
	mov [di], al

	mov al, ah
	call TO_HEX

	inc di
	mov [di], al
	inc di

	add [bytes_written], 2

	ret

; TO_HEX converts value inside al
TO_HEX:
	cmp al, 9
	jna @@NUMBER_AL
	add al, 39
@@NUMBER_AL:
	add al, "0"
	ret

GET_BYTE:
	mov dx, [bytes_read]

	; mov dx, [bytes_scanned]
	; cmp [bytes_read], dx
	mov dx, [bytes_scanned]
	inc dx
	cmp dx, [bytes_read]
	; cmp [bytes_scanned], 4
	jb @@INC_SI

	call NEW_BLOCK
	jmp @@NEW_BLOCK

@@INC_SI:
	inc si
	inc [bytes_scanned]

@@NEW_BLOCK:
	inc [pos]
	call BYTE_TO_STR
	ret

; Reads CAPACITY number of bytes from a file 
NEW_BLOCK:
	call PRINT_OUTPUT

	; Reading from file
	mov bx, [input_hnd]
	mov cx, (CAPACITY)
	lea dx, input
	mov ax, 3F00h(CAPACITY)
	int 21h
	mov [bytes_read], ax

	jnc @@NO_FAIL
	call PRINT_FAIL_READ

@@NO_FAIL:
	test ax, ax
	jz @@END_OF_FILE

	; Resets si and di
	lea si, input
	lea di, output
	mov [bytes_scanned], 0
	mov [bytes_written], 0

	ret
@@END_OF_FILE:
	call EXIT

PRINT_OUTPUT:
	mov cx, [bytes_written]
	lea dx, output
	mov ah, 40h
	mov bx, output_hnd
	int 21h

	ret

; OPCODES
STR_SREG:
	mov al, [sreg]
	and al, 00000011b
	cmp al, 00000000b
	jne @@STR_SREG_NOT_ES

	lea dx, strsreg_es
	call STR_ADD
	ret

@@STR_SREG_NOT_ES:
	cmp al, 00000001b
	jne @@STR_SREG_NOT_CS

	lea dx, strsreg_cs
	call STR_ADD
	ret

@@STR_SREG_NOT_CS:
	cmp al, 00000010b
	jne @@STR_SREG_NOT_SS

	lea dx, strsreg_ss
	call STR_ADD
	ret
@@STR_SREG_NOT_SS:
	lea dx, strsreg_ds
	call STR_ADD
	ret
; 00 – ES
; 01 – CS
; 10 – SS
; 11 – DS

STR_REG:
	mov al, [reg]
	and al, 00000111b
	cmp al, reg_ax
	jne @@STR_REG_NOT_AX

	lea dx, strreg_ax
	call STR_ADD
	xor al, al
	ret

@@STR_REG_NOT_AX:
	cmp al, reg_bx
	jne @@STR_REG_NOT_BX

	lea dx, strreg_bx
	call STR_ADD
	xor al, al
	ret
@@STR_REG_NOT_BX:
	cmp al, reg_cx
	jne @@STR_REG_NOT_CX

	lea dx, strreg_cx
	call STR_ADD
	xor al, al
	ret
@@STR_REG_NOT_CX:
	cmp al, reg_dx
	jne @@STR_REG_NOT_DX

	lea dx, strreg_dx
	call STR_ADD
	xor al, al
	ret
@@STR_REG_NOT_DX:
	or al, 00000001b
	ret

SUB_OP_PUSH2:
	ret

; --- String subroutines ---
STR_ADD:
	push si

	mov si, dx
@@STR_LOOP:

	mov dx, [si]
	mov [di], dx

	inc di
	inc si
	inc bytes_written

	cmp byte ptr [si], 0
	jne @@STR_LOOP
	
	pop si
	ret

STR_BUF_ADD:
	push si
	push di

	mov si, dx
	lea di, str_op_buffer

	mov di, " "
	inc di

@@STR_BUF_LOOP:

	mov dx, [si]
	mov [di], dx

	inc di
	inc si

	cmp byte ptr [si], 0
	jne @@STR_BUF_LOOP

	mov [di], 0

	pop di
	pop si
	ret

; --- OP CODE SUBROUTINES ---
; Detects which subroutine to call
MOD_RM:
	cmp [mmod], 00b
	jne @@MOD_NOT00
	call MOD00
	ret

@@MOD_NOT00:
	cmp [mmod], 01b
	jne @@MOD_NOT01
	call MOD01_10
	ret

@@MOD_NOT01:
	cmp [mmod], 10b
	jne @@MOD_NOT10
	call MOD01_10
	ret

@@MOD_NOT10:
	call MOD11

	ret

MOD00:
	lea dx, str_sign_lbracket
	call STR_BUF_ADD

	cmp [rm], 000b
	jne @@MOD00_RM_NOT_000

	jmp @@MOD00_END

@@MOD00_RM_NOT_000:
	cmp [rm], 100b
	jne @@MOD00_RM_NOT_100

	lea dx, str_si
	call STR_BUF_ADD

	jmp @@MOD00_END

@@MOD00_RM_NOT_100:

	; mov 
@@MOD00_END:
	lea dx, str_sign_rbracket
	call STR_BUF_ADD
	ret

MOD01_10:
	ret

MOD11:
	cmp [w], 0b
	jne @@W1

	ret
@@W1:

	ret

end START

