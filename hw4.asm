.model large
.stack 100h

CAPACITY equ 20h

.data
	str_test db "?????", 0
	; Input and output buffers
	input db (CAPACITY) dup (0)
    output db (CAPACITY) * 30 dup (0)

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
	str_op_buffer_offset dw 0

	; Instruction position
	pos dw 0100h

	; Opcode strings
	strop_mov db " MOV ", 0
	strop_nop db " NOP ", 0
	strop_push db   " PUSH ", 0
	strop_pop db    " POP ", 0
	strop_and db    " AND ", 0
	strop_lea db    " LEA ", 0
	strop_lds db    " LDS ", 0
	strop_dec db    " DEC ", 0
	strop_loop db   " LOOP ", 0
	strop_loope db  " LOOPE ", 0
	strop_loopne db " LOOPNE ", 0
	strop_unreg db  " UNKNOWN OPCODE", 0

	s db 0
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

	str_sign_colon db ":", 0
	str_sign_plus db "+", 0
	str_sign_lbracket db "[", 0
	str_sign_rbracket db "]", 0
	str_sep db ", ", 0


	strreg_ax db "AX", 0
	strreg_bx db "BX", 0	
	strreg_cx db "CX", 0
	strreg_dx db "DX", 0

	strreg_al db "AL", 0
	strreg_bl db "BL", 0	
	strreg_cl db "CL", 0
	strreg_dl db "DL", 0

	strreg_ah db "AH", 0
	strreg_bh db "BH", 0	
	strreg_ch db "CH", 0
	strreg_dh db "DH", 0

	strsreg_es db "ES", 0
	strsreg_cs db "CS", 0
	strsreg_ss db "SS", 0
	strsreg_ds db "DS", 0

	str_si db "SI", 0
	str_di db "DI", 0
	str_bp db "BP", 0
	str_sp db "SP", 0

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
	lea di, output
DISASSEMBLE:
	call COLUMN

	call GET_BYTE

	mov al, [si]
	and al, 11100111b
	cmp al, 00100110b
	jne @@NO_PREFIX

; --- PREFIX BYTE ----
	mov al, [si]
	and al, 00011000b
	shr al, 3
	mov [sreg], al
	call GET_BYTE

@@NO_PREFIX:

	mov al, [si]
	and al, 11100111b
	cmp al, 00000111b
	je @@OP_POP3

	mov al, [si]
	cmp al, 10001111b
	je @@OP_POP1

	mov al, [si]
	and al, 11111000b
	cmp al, 01011000b
	je @@OP_POP2

	mov al, [si]
	and al, 11111110b
	cmp al, 11111110b
	je @@OP_DEC1
	
	jmp JUMP0

@@OP_POP3:
	lea dx, strop_pop
	call STR_BUF_ADD

	mov [w], 1
	mov al, [si]
	shr al, 3
	mov [sreg], al
	call STR_SREG

	jmp OP_END

; --- POP1 ---
@@OP_POP1:
	lea dx, strop_pop
	call STR_BUF_ADD

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

	call MOD_RM

	jmp OP_END
@@OP_POP2:
	lea dx, strop_pop
	call STR_BUF_ADD

	mov al, [si]
	mov [w], 1
	call STR_REG
	jmp OP_END

; --- DEC1 ---
@@OP_DEC1:
	mov al, [si]
	and al, 00000001b
	mov [w], al

	call GET_BYTE

	mov al, [si]
	and al, 11000000b
	shr al, 6
	mov [mmod], al

	mov al, [si]
	and al, 00000111b
	mov [rm], al

	lea dx, strop_dec
	call STR_BUF_ADD

	call MOD_RM

	jmp OP_END

JUMP0:

	mov al, [si]
	and al, 11111000b
	cmp al, 01010000b
	je @@OP_PUSH2

	mov al, [si]
	cmp al, 0E2h
	je @@OP_LOOP

	mov al, [si]
	cmp al, 0E1h
	je @@OP_LOOPE

	mov al, [si]
	cmp al, 0E0h
	je @@OP_LOOPNE

	mov al, [si]
	and al, 11111000b
	cmp al, 01001000b
	je @@OP_DEC2

	mov al, [si]
	cmp al, 90h
	je @@OP_NOP

	jmp JUMP1

@@OP_PUSH2:
	lea dx, strop_push
	call STR_ADD

	mov al, [si]
	mov [w], 1
	call STR_REG

	jmp OP_END

@@OP_DEC2:
	lea dx, strop_dec
	call STR_BUF_ADD

	mov al, [si]
	mov [w], 1
	mov [reg], al
	call STR_REG

	jmp OP_END

@@OP_NOP:
	lea dx, strop_nop
	call STR_BUF_ADD
	jmp OP_END

@@OP_LOOP:
	lea dx, strop_loop
	call STR_BUF_ADD

	call GET_BYTE

	mov ax, [pos]
	add al, [si]

	mov dl, ah
	call BYTE_TO_STR_BUF

	mov dl, al
	call BYTE_TO_STR_BUF
	jmp OP_END

@@OP_LOOPE:
	lea dx, strop_loope
	call STR_BUF_ADD

	call GET_BYTE

	mov ax, [pos]
	add al, [si]

	mov dl, ah
	call BYTE_TO_STR_BUF

	mov dl, al
	call BYTE_TO_STR_BUF
	jmp OP_END

@@OP_LOOPNE:
	lea dx, strop_loopne
	call STR_BUF_ADD

	call GET_BYTE

	mov ax, [pos]
	add al, [si]

	mov dl, ah
	call BYTE_TO_STR_BUF

	mov dl, al
	call BYTE_TO_STR_BUF
	jmp OP_END

JUMP1:

	mov al, [si]
	cmp al, 11000101b
	je @@OP_LDS

	mov al, [si]
	cmp al, 10001101b
	je @@OP_LEA

	jmp JUMP2

@@OP_LDS:
	lea dx, strop_lds
	call STR_BUF_ADD

	call GET_BYTE

	mov w, 1

	mov al, [si]
	and al, 11000000b
	shr al, 6
	mov [mmod], al

	mov al, [si]
	and al, 00111000b
	shr al, 3
	call STR_REG

	lea dx, str_sep
	call STR_BUF_ADD
	
	mov al, [si]
	and al, 00000111b
	mov [rm], al
	call MOD_RM

	jmp OP_END

@@OP_LEA:
	lea dx, strop_lea
	call STR_BUF_ADD

	call GET_BYTE
	mov w, 1

	mov al, [si]
	and al, 11000000b
	shr al, 6
	mov [mmod], al

	mov al, [si]
	and al, 00111000b
	shr al, 3
	call STR_REG

	lea dx, str_sep
	call STR_BUF_ADD
	
	mov al, [si]
	and al, 00000111b
	mov [rm], al
	call MOD_RM

	jmp OP_END

JUMP2:
	mov al, [si]
	or al, 00000011b
	cmp al, 10000011b
	je @@OP_AND2

	mov al, [si]
	or al, 00000011b
	cmp al, 00100011b
	je @@OP_AND1

	jmp JUMP3

@@OP_AND1:
	lea dx, strop_and
	call STR_BUF_ADD

	mov al, [si]
	and al, 00000010b
	shr al, 1
	mov [d], al

	mov al, [si]
	and al, 00000001b
	mov [w], al

	call GET_BYTE

	mov al, [si]
	and al, 11000000b
	shr al, 6
	mov [mmod], al

	mov al, [si]
	and al, 00111000b
	shr al, 3
	mov [reg], al

	mov al, [si]
	and al, 00000111b
	mov [rm], al

	cmp [d], 0
	je @@REV

	mov al, [reg]
	call STR_REG
	
	lea dx, str_sep
	call STR_BUF_ADD
	
	call MOD_RM
	
	jmp OP_END

@@REV:
	
	call MOD_RM

	lea dx, str_sep
	call STR_BUF_ADD

	mov al, [reg]
	call STR_REG

	jmp OP_END

@@OP_AND2:
	lea dx, strop_and
	call STR_BUF_ADD

	mov al, [si]
	and al, 00000010b
	mov [s], al

	mov al, [si]
	and al, 00000001b
	mov [w], al

	call GET_BYTE
	mov al, [si]
	and al, 11000000b
	shr al, 6
	mov [mmod], al

	mov al, [si]
	and al, 00000111b
	mov [rm], al

	call MOD_RM

	lea dx, str_sep
	call STR_BUF_ADD

	cmp [w], 1
	je @@TWO_DATA

	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF

	jmp OP_END

@@TWO_DATA:

	call GET_BYTE
	mov al, [si]
	push ax

	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF
	pop ax
	
	mov dl, al
	call BYTE_TO_STR_BUF

	jmp OP_END

JUMP3:

	mov al, [si]
	or al, 00000001b
	cmp al, 00100101b
	je @@OP_AND3

	mov al, [si]
	or al, 00001111b ; 1011 w reg
	cmp al, 10111111b
	je @@OP_MOV3

	jmp JUMP4

@@OP_AND3:
	lea dx, strop_and
	call STR_BUF_ADD

	mov al, [si]
	and al, 00000001b
	; mov [w], al

	cmp al, 1
	je @@TWO

	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF

@@TWO:

	call GET_BYTE
	mov al, [si]
	push ax

	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF
	pop ax
	
	mov dl, al
	call BYTE_TO_STR_BUF

	jmp OP_END

@@OP_MOV3:
	lea dx, strop_mov
	call STR_BUF_ADD

	; mov al, [si]
	; and al, 00001000b
	; shr al, 3
	; mov [w], al

	jmp OP_END

JUMP4:
; No op found
	lea dx, strop_unreg
	call STR_BUF_ADD

OP_END:
	lea dx, str_op_buffer
	call STR_ADD
	mov [str_op_buffer_offset], 0

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

; Converts value inside dl and 
; stores it inside str_op_buffer 
BYTE_TO_STR_BUF:
	push di
	push ax

	lea di, str_op_buffer
	add di, [str_op_buffer_offset]
	xor ax, ax
	mov al, dl
	mov cl, 16
	div cl
	; al = ax / cl
	; ah = ax % cl

	call TO_HEX
	mov [di], al

	mov al, ah
	call TO_HEX

	inc di
	inc [str_op_buffer_offset]
	mov [di], al

	inc di
	inc [str_op_buffer_offset]
	mov [di], 0

	pop ax
	pop di
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

	mov dx, [bytes_scanned]
	inc dx
	cmp dx, [bytes_read]
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
	add di, str_op_buffer_offset

@@STR_BUF_LOOP:

	mov dx, [si]
	mov [di], dx

	inc di
	inc si
	inc [str_op_buffer_offset]

	cmp byte ptr [si], 0
	jne @@STR_BUF_LOOP

	mov byte ptr [di], 0

	pop di
	pop si
	ret

; OPCODES
STR_SREG:
	mov al, [sreg]
	and al, 00000011b
	cmp al, 00000000b
	jne @@STR_SREG_NOT_ES

	lea dx, strsreg_es
	call STR_BUF_ADD
	ret

@@STR_SREG_NOT_ES:
	cmp al, 00000001b
	jne @@STR_SREG_NOT_CS

	lea dx, strsreg_cs
	call STR_BUF_ADD
	ret

@@STR_SREG_NOT_CS:
	cmp al, 00000010b
	jne @@STR_SREG_NOT_SS

	lea dx, strsreg_ss
	call STR_BUF_ADD
	ret
@@STR_SREG_NOT_SS:
	lea dx, strsreg_ds
	call STR_BUF_ADD
	ret
; 00 – ES
; 01 – CS
; 10 – SS
; 11 – DS

; al is reg or r/m
STR_REG:
	and al, 00000111b

	cmp [w], 1
	je @@STR_REG_W1

	; cmp al, 00000000b
	; je @@STR_REG_W0_000

	cmp al, 00000001b
	je @@STR_REG_W0_001

	cmp al, 00000010b
	je @@STR_REG_W0_010

	cmp al, 00000011b
	je @@STR_REG_W0_011

	cmp al, 00000100b
	je @@STR_REG_W0_100

	cmp al, 00000101b
	je @@STR_REG_W0_101

	cmp al, 00000110b
	je @@STR_REG_W0_110

	cmp al, 00000111b
	je @@STR_REG_W0_111

; w = 0
; @@STR_REG_W0_000:
	lea dx, strreg_al
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_001:
	lea dx, strreg_cl
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_010:
	lea dx, strreg_dl
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_011:
	lea dx, strreg_bl
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_100:
	lea dx, strreg_ah
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_101:
	lea dx, strreg_ch
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_110:
	lea dx, strreg_dh
	call STR_BUF_ADD
	ret 
@@STR_REG_W0_111:
	lea dx, strreg_bh
	call STR_BUF_ADD
	ret 

; w = 1
@@STR_REG_W1:

	cmp al, 00000000b
	je @@STR_REG_W1_000

	cmp al, 00000001b
	je @@STR_REG_W1_001

	cmp al, 00000010b
	je @@STR_REG_W1_010

	cmp al, 00000011b
	je @@STR_REG_W1_011

	cmp al, 00000100b
	je @@STR_REG_W1_100

	cmp al, 00000101b
	je @@STR_REG_W1_101

	cmp al, 00000110b
	je @@STR_REG_W1_110

	cmp al, 00000111b
	je @@STR_REG_W1_111

	push ax 
	lea dx, str_test
	call STR_BUF_ADD
	pop ax

@@STR_REG_W1_000:
	lea dx, strreg_ax
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_001:
	lea dx, strreg_cx
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_010:
	lea dx, strreg_dx
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_011:
	lea dx, strreg_bx
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_100:
	lea dx, str_sp
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_101:
	lea dx, str_bp
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_110:
	lea dx, str_si
	call STR_BUF_ADD
	ret 
@@STR_REG_W1_111:
	lea dx, str_di
	call STR_BUF_ADD
	ret

; --- OP CODE SUBROUTINES ---
; Detects which subroutine to call
MOD_RM:
	cmp [sreg], 5
	je @@MOD_RM_NO_SREG

	call STR_SREG

	lea dx, str_sign_colon
	call STR_BUF_ADD

	mov [sreg], 5

@@MOD_RM_NO_SREG:
; mod == 11
	mov al, [mmod]
	cmp al, 00000011b
	je @@MOD_11

	call MOD_NOT_11
	ret

@@MOD_11:
	mov al, [rm]
	call STR_REG
	ret 

; mod == 00 | 01 | 10
MOD_NOT_11:
	lea dx, str_sign_lbracket
	call STR_BUF_ADD

	cmp [rm], 000b
	je @@RM000

	cmp [rm], 001b
	je @@RM001

	cmp [rm], 010b
	je @@RM010

	cmp [rm], 011b
	je @@RM011

	cmp [rm], 100b
	je @@RM100

	cmp [rm], 101b
	je @@RM101

	cmp [rm], 110b
	je @@RM110

	cmp [rm], 111b
	je @@RM111


@@RM000:
	lea dx, strreg_bx
	call STR_BUF_ADD

	lea dx, str_sign_plus
	call STR_BUF_ADD

	lea dx, str_si
	call STR_BUF_ADD
	jmp _MOD

@@RM001:
	lea dx, strreg_bx
	call STR_BUF_ADD

	lea dx, str_sign_plus
	call STR_BUF_ADD

	lea dx, str_di
	call STR_BUF_ADD
	ret

@@RM010:
	lea dx, str_bp
	call STR_BUF_ADD

	lea dx, str_sign_plus
	call STR_BUF_ADD

	lea dx, str_si
	call STR_BUF_ADD
	jmp _MOD

@@RM011:
	lea dx, str_bp
	call STR_BUF_ADD

	lea dx, str_sign_plus
	call STR_BUF_ADD

	lea dx, str_di
	call STR_BUF_ADD
	jmp _MOD

@@RM100:
	lea dx, str_si
	call STR_BUF_ADD
	jmp _MOD

@@RM101:
	lea dx, str_di
	call STR_BUF_ADD
	jmp _MOD

@@RM110:
	cmp [mmod], 0
	jne @@DISPLACEMENT

	jmp @@TWO_BYTES

@@DISPLACEMENT:
	lea dx, str_bp
	call STR_BUF_ADD
	jmp _MOD

@@RM111:
	lea dx, strreg_bx
	call STR_BUF_ADD
	jmp _MOD

_MOD:
; No displacement
	cmp [mmod], 00b 
	je @@RM0XX_END

	lea dx, str_sign_plus
	call STR_BUF_ADD

	cmp [mmod], 00000010b
	je @@TWO_BYTES

; One byte displacement
	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF

	jmp @@RM0XX_END

; Two byte displacement
@@TWO_BYTES:
	call GET_BYTE
	mov al, [si]
	push ax

	call GET_BYTE
	mov dl, [si]
	call BYTE_TO_STR_BUF
	pop ax
	
	mov dl, al
	call BYTE_TO_STR_BUF
	jmp @@RM0XX_END

@@RM0XX_END:
	lea dx, str_sign_rbracket
	call STR_BUF_ADD
	ret
	
end START

