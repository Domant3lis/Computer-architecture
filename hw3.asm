.model large
.stack 100h

; Must not exceed 325Fh
CAPACITY equ 16 * 2
; CAPACITY equ 0FEh
; CAPACITY equ 325Fh

.data
	; Input and output buffers
	input_text db (CAPACITY) dup (0)
    output_hex db (CAPACITY) * 4 dup (0)

	; File name buffers
	input_file_arg db 128 dup (0)
	output_file_arg db 128 dup (0)

	; Command line option buffer
	cmd_buff db 128 dup(0)

    ; Messages to the user
	msg_help db "This program creates a hex dump of a specified file", 10, 13, "/i ARG specifies the input file, where ARG is the path to the input file", 10, 13, "/o ARG specifies the output file in which the hex dump will be saved, where ARG is the path to the output file$"
	msg_invalid_opt db "Invalid option(s)!$"
	msg_fail_open db "Failed to open the file!$"
	msg_no_arg db "Each file option has to have a path specified$"
	msg_too_many_opts db "There must exactly be one option supplied for input and output$"

    ; File handles
	input dw 0000h
	output dw 0000h

    ; Amount of bytes read
    bytes_read dw 0
	bytes_written dw 0

	; Absolute amount of bytes read
	total_words dw 0000h

	; is used as a boolean value to indicate whenever
	; a valid output file was specified
	is_out_file db 1

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
    mov [input], ax
	jc PRINT_FAIL_OPEN

	; creates the output file
	xor cx, cx
	mov ax, 3C02h
	lea dx, output_file_arg
	int 21h
	mov output, ax	
	jnc FILE_READ

	mov [is_out_file], 0

FILE_READ:
	mov [bytes_written], 0
	call READ_FROM_FILE
	jc PRINT_FAIL_OPEN

	mov cx, [bytes_read]
	mov bx, di
	dec di

CONVERT:
	push cx

; --- Number column ---
	mov ax, [total_words]
	mov bx, 15
	and ax, bx
	push ax

	; Print column only then 16 bytes have been processed
	; total_words % 16 == 0
	cmp ax, 0
	jne BYTES

	add bytes_written, 6
	call COLUMN

; -- SPACING --
	mov al, " "
	inc di
	mov [di], al
	inc di
	mov [di], al

BYTES:
	add bytes_written, 3
; --- byte conversion to hex 
	call BYTE_TO_STR

; --- SPACING ---
    inc di
    mov al, " "
    mov [di], al

; --- New line ---
	pop ax
	cmp ax, 15
	jne @@NOT_A_NEW_LINE
	
	add bytes_written, 2

	inc di
	mov al, 10
	mov [di], al

	inc di
	mov al, 13
	mov [di], al

@@NOT_A_NEW_LINE:	
	pop cx
	
	inc si
	inc [total_words]

	loop CONVERT
@@AFTER_LOOP:
	; Prints the whole CAPACITY sized block
	call PRINT_OUTPUT
    jmp FILE_READ

EXIT:
; Closes the file handles
	; input
	mov ah, 3Eh
	mov bx, input
	int 21h
	; output
	mov ah, 3Eh
	mov bx, output
	int 21h

; exits the program
	mov ax, 4C00h
	int 21h

; --- ALL SUBROUTINES BELOW ---

COLUMN:
; Save column information to di
	push cx
; -- BH --
	mov bx, [total_words]
	xor ax, ax
	mov al, bh
	mov cl, 16
	div cl 

	call TO_HEX
	inc di
	mov [di], al

	mov al, ah
	call TO_HEX
	inc di
	mov [di], al

; -- BL --
	mov bx, [total_words]
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

	pop cx
	ret

PRINT_OUTPUT:
	mov cx, [bytes_written]
	lea dx, output_hex
	mov ah, 40h

	cmp [is_out_file], 0
	je @@STDOUT

	; Sets to save output to a file
	mov bx, output

	jmp @@INTERRUPT
		
@@STDOUT:
	; Sets to prints the results to stdout
	mov bx, 1

@@INTERRUPT:
	int 21h
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
	inc di
	mov [di], al

	mov al, ah
	call TO_HEX
	inc di
	mov [di], al

	ret

; TO_HEX converts value inside al
TO_HEX:
	cmp al, 9
	jna @@NUMBER_AL
	add al, 39
@@NUMBER_AL:
	add al, "0"
	ret

; Reads (CAPACITY) number of bytes from a file 
READ_FROM_FILE:
	lea si, input_text
	lea di, output_hex

	mov bx, [input]
	mov cx, (CAPACITY)
	lea dx, input_text
	mov ax, 3F00h
	int 21h
	mov bytes_read, ax

	cmp [bytes_read], 0
	jne @@NOT_END_OF_FILE
	call EXIT

@@NOT_END_OF_FILE:
	ret
end START
