; TODO:
; 
; POP
; AND
; LEA
; LDS
; DEC
; LOOP
; LOOPE
; LOOPNE

.model large
.stack 100h

CAPACITY equ 10h

.data
	; Input and output buffers
	input dw (CAPACITY) dup (0)
    output db (CAPACITY) * 100 dup (0)

	; File name buffers
	input_file_arg db 128 dup (0)
	output_file_arg db 128 dup (0)

	; Command line option buffer
	cmd_buff db 128 dup(0)

    ; Messages to the user
	msg_help db "This program partially disassembles a COM executable", 10, 13, "/i ARG specifies input, where ARG is the path to the COM executable", 10, 13, "/o ARG specifies the output file in which the disassembled program will be saved, where ARG is the path to the output file$"
	msg_invalid_opt db "Invalid option(s)!$"
	msg_fail_open db "Failed to open the file!$"
	msg_fail_read db "Failed to read from the file!$"
	msg_no_arg db "Each file option has to have a path specified$"
	msg_too_many_opts db "There must exactly be one option supplied for input and output$"

    ; File handles
	input_hnd dw 0000h
	output_hnd dw 0000h

    ; Amount of bytes read
    bytes_read dw (CAPACITY)
	bytes_written dw 0

	; Absolute amount of bytes read
	total_bytes dw 0000h

	; 
	prog_pos dw 0100h

	; is used as a boolean value to indicate whenever
	; the block read is the last
	is_last_block db 0

	; Opcode strings
	msgop_pop db    "pop      "
	msgop_and db    "and      "
	msgop_lea db    "lea      "
	msgop_lds db    "lds      "
	msgop_dec db    "dec      "
	msgop_loop db   "loop     "
	msgop_loope db  "loope    "
	msgop_loopne db "loopne   "
	msgop_unreg db  "unrecognized opcode"

	; Opcode bytes
	; 1. registras / atmintis -> stekas
	; 1111 1111 mod 110 r/m [poslinkis]

	; 2. registras -> stekas
	; 0101 0reg
	op_push2 db 01010000b

	; 3. segmento registras -> stekas
	; 000 sreg 110
	; op_push3 db 000 00 110b

	; 1. stekas -> registras / atmintis
	; 1000 1111 mod 110 r/m [poslinkis] 
	op_pop1 db 10001111b

	; 2. stekas -> registras
	; 01011 reg
	op_pop2 db 01011000b

	; 3. stekas -> segmento registras
	; 000 sreg 111
	op_pop3 db 00000111b

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

DISASSEMBLE:

	call GET_BYTE
	call BYTE_TO_STR

	; inc di
	; inc bytes_written
	; mov di, " "

	cmp [is_last_block], 1
	jne @@LOOOOOP

	; mov ah, 02h
	; mov dl, "#"
	; int 21h

@@LOOOOOP:

	; call PRINT_OUTPUT

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

	inc di
	mov al, ah
	call TO_HEX
	mov [di], al
	; inc di

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
	cmp [bytes_read], (CAPACITY)
	jb @@NOT_READ

	mov ah, 02h
	mov dl, "?"
	int 21h

	cmp [is_last_block], 1
	jb @@NO_EXIT
	call EXIT

@@NO_EXIT:
	call NEW_BLOCK

	cmp [bytes_read], (CAPACITY)
	je @@NOT_LAST_BLOCK
	inc [is_last_block]
	
	jmp @@NOT_LAST_BLOCK

@@NOT_READ:
	inc si

@@NOT_LAST_BLOCK:
	inc [bytes_read]

	ret
; Reads (CAPACITY) number of bytes from a file 
NEW_BLOCK:
	call PRINT_OUTPUT
	
	; Resets si and di
	lea si, input

	; Reading from file
	mov bx, [input_hnd]
	mov cx, (CAPACITY)
	lea dx, input
	mov ax, 3F00h
	int 21h
	mov [bytes_read], ax

	jnc @@NO_FAIL
	call PRINT_FAIL_READ
@@NO_FAIL:
	ret

PRINT_OUTPUT:
	mov cx, [bytes_written]
	lea dx, output
	mov ah, 40h
	mov bx, output_hnd
	int 21h

	lea di, output
	mov [bytes_written], 0

	mov dl, "#"
	mov ah, 02h
	int 21h

	mov dl, 10
	mov ah, 02h
	int 21h

	mov dl, 13
	mov ah, 02h
	int 21h

	ret

; OPCODES
SUB_OP_PUSH1:
	ret

SUB_OP_PUSH2:
	ret

end START

