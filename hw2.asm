.model large
.stack 3000h
CAPACITY equ 9000h
BLOCK_SIZE equ 16

.data
	input_file db 128 dup (0)
	output_file db 128 dup (0)
	cmd_buff db 128 dup(0)

	S db 41, 46, 67, 201, 162, 216, 124, 1, 61, 54, 84, 161, 236, 240, 6, 19, 98, 167, 5, 243, 192, 199, 115, 140, 152, 147, 43, 217, 188, 76, 130, 202, 30, 155, 87, 60, 253, 212, 224, 22, 103, 66, 111, 24, 138, 23, 229, 18, 190, 78, 196, 214, 218, 158, 222, 73, 160, 251, 245, 142, 187, 47, 238, 122, 169, 104, 121, 145, 21, 178, 7, 63, 148, 194, 16, 137, 11, 34, 95, 33, 128, 127, 93, 154, 90, 144, 50, 39, 53, 62, 204, 231, 191, 247, 151, 3, 255, 25, 48, 179, 72, 165, 181, 209, 215, 94, 146, 42, 172, 86, 170, 198, 79, 184, 56, 210, 150, 164, 125, 182, 118, 252, 107, 226, 156, 116, 4, 241, 69, 157, 112, 89, 100, 113, 135, 32, 134, 91, 207, 101, 230, 45, 168, 2, 27, 96, 37, 173, 174, 176, 185, 246, 28, 70, 97, 105, 52, 64, 126, 15, 85, 71, 163, 35, 221, 81, 175, 58, 195, 92, 249, 206, 186, 197, 234, 38, 44, 83, 13, 110, 133, 40, 132, 9, 211, 223, 205, 244, 65, 129, 77, 82, 106, 220, 55, 200, 108, 193, 171, 250, 36, 225, 123, 8, 12, 189, 177, 74, 120, 136, 149, 139, 227, 99, 232, 109, 233
	db 203, 213, 254, 59, 0, 29, 57, 242, 239, 183, 14, 102, 88, 208, 228, 166, 119, 114, 248, 235, 117, 75, 10, 49, 68, 80, 180, 143, 237, 31, 26, 219, 153, 141, 51, 159, 17, 131, 20

	msg_help db "This program creates an md2 hash of a specified file", 10, 13, "/i ARG specifies the input file, where ARG is the path to the input file", 10, 13, "/o ARG specifies the output file in which the MD2 hash will be saved, where ARG is the path to the output file$"
	msg_invalid_opt db "Invalid option(s)!$"
	msg_fail_open db "Failed to open the file!$"
	msg_no_arg db "Each file option has to have a path specified$"
	msg_too_many_opts db "There must exactly be one option suplied for input and output$"
	msg_a_bug db "A bug in the program was encoutered, quiting$"

	input dw 0000h
	output dw 0000h

	C db BLOCK_SIZE dup (0), "$"
	; M db "test yest pest nest fest", (CAPACITY) dup (?)
	M db (CAPACITY) dup ("$")
	M_size dw 0
	L db 0
	X db 48 dup(0), "$"
	X_msg db 32 dup ("?")
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
	mov di, offset input_file

	jmp @@SKIP_SPACE

; bl is used as a flag for input
; bh - for output
@@OUT:
	; Check for incorrect input, in this case too many /o inputs
	cmp bh, 0
	jne PRINT_TOO_MANY_OPTS

	inc bh
	mov di, offset output_file
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
    mov dx, offset input_file
    int 21h
    mov [input], ax
	jc PRINT_FAIL_OPEN

	; Reads the whole file into M
	mov bx, ax
	mov cx, (CAPACITY)
	mov dx, offset M
	mov ah, 3Fh
	int 21h
	mov [M_size], ax
	jc PRINT_FAIL_OPEN

; The spec requires messages to be padded
; so that they can be nicely divided by 16-byte blocks
; (padding is done even then message is equally divisible by 16-bytes,
; in that case whole new 16-byte block is appended)
; --- WORKS ---
; --- PADING --- 
	mov ax, M_size
	mov bl, BLOCK_SIZE
	div bl
	; AH - has the remainder

	mov si, offset M
	add si, M_size

	xor cx, cx
	mov cl, BLOCK_SIZE
	sub cl, ah
	add M_size, cx
	mov ah, cl

	cmp ah, 0
	jne PADDING
	mov ah, BLOCK_SIZE

PADDING:
	mov [si], ah
	inc si
	loop PADDING

	jmp CHECHSUM
PRINT_ERROR:
	mov ah, 21h
	lea dx, msg_a_bug
	int 21h
	jmp EXIT

; ----  WORKS  ----
; --- CHECKSUM ---
CHECHSUM:
	mov ax, M_size
	mov bl, BLOCK_SIZE
	div bl ; -> al - quatient,  ah -> remainder

	mov si, offset M

	xor cx, cx
	xor dx, dx ; dh -> j
	mov cx, M_size

	; Set c to M[i*16+j]. +
    ; Set C[j] to C[j] xor S[c xor L]. 
    ; Set L to C[j]. 
CHECKSUM_LOOP:
	xor ax, ax
	xor bx, bx
	; Set c to M[i*16+j]
	; bl -> c
	; si -> M
	mov bl, [si]
	; bl -> c xor L
	xor bl, L

	; ax -> [di] -> S[c xor L]
	lea di, S
	add di, bx
	mov ax, [di]
		
	; di -> C
	; bx -> C[dx] -> C[j]
	xor bx, bx
	lea di, C
	add di, dx
	mov bx, [di]

	; ax -> C[j] xor S[c xor L]
	xor ax, bx
 
	; C[j] = C[j] xor S[c xor L]
	mov [di], al

 	; L = C[j]
	mov [L], al

	inc si
	inc dx
	cmp dx, 16
	jne @@LOOP

	xor dx, dx
	
@@LOOP:
	loop CHECKSUM_LOOP

; The 16-byte checksum C[0 ... 15] is appended to the (padded) message
	; si -> M
	; di -> C
	mov si, offset M
	add si, M_size
	add M_size, BLOCK_SIZE
	mov di, offset C
	mov cx, BLOCK_SIZE

	; M[M_size..M_size + 15] = C[0..15]
@@APPEND_CHECKSUM:
	mov dx, [di]
	mov [si], dx
	
	inc di
	inc si
	loop @@APPEND_CHECKSUM


; --- THE LAST PART ----
; 3.4 Step 4. Process Message in 16-Byte Blocks

	xor cx, cx
	mov ax, M_size
	mov cl, BLOCK_SIZE
	div cl

	lea si, M  ; si -> M[0]
	cmp ah, 0
	jne PRINT_ERROR

	xor cx, cx
	mov cl, al

; i loop
PROCESS:
	
	lea di, X  ; di -> X[0]
	add di, 16 ; di -> X[16]
	
	; xor ax, ax
	xor bx, bx
	xor dx, dx ; dl -> j

	; --- WORKS ---
	; j loop
	@@PROCESS:
		; Set X[16+j] to M[i*16+j]
		mov al, [si]
		mov [di], al

		; Set X[32+j] to (X[16+j] xor X[j])
		; ah = X[16 + j]
		mov ah, [di]

		; al = X[j]
		sub di, 16
		mov al, [di]
		add di, 16

		xor al, ah   ; al = X[16+j] xor X[j]

		add di, 16
		mov [di], al
		sub di, 16

		inc si
		inc di

		inc dx
		cmp dx, 16
		jne @@PROCESS

	push si
	push cx

	; Set t to 0
	xor ax, ax ; al = t

	xor dx, dx
	; dx -> j
	; j loop 
	@@PROCESS_J:

		lea di, X ; di -> X[0]

		xor cx, cx
	; 	; cx -> k
	; 	; k loop
		@@PROCESS_K:
	; 		; Set t and X[k] to (X[k] xor S[t])
			lea si, S    ; si -> S[0]
			add si, ax   ; di -> S[t]
			mov bl, [si] ; bl = S[t]
			mov bh, [di] ; bh = X[k]
			
			xor bl, bh   ; bh = X[k] xor S[t]
			mov al, bl   ; t = ah = X[k] xor S[t]
			mov [di], bl ; X[k] = ah = t

			inc di       ; di -> X[k]
			inc cx

			cmp cx, 48
			jne @@PROCESS_K
		
		; Set t to (t+j) modulo 256
		add ax, dx  ; t + j

		push dx
		xor dx, dx

		mov cx, 256
		div cx      ; (t + j) / 256
		mov ax, dx  ; t = (t + j) % 256

		pop dx

		; cmp ax, 256
		; jb @@NO_MOD
		; sub ax, 256
		; @@NO_MOD:

		inc dl
		cmp dl, 18
		jne @@PROCESS_J

	pop cx
	pop si
	loop PROCESS

; TODO: CONVERT TO READABLE OUTPUT
mov cx, 16
lea si, X
lea di, X_msg
CONVERT:
	push cx

	xor ax, ax
	mov al, [si]
	; the quotient is placed in AL and the remainder in AH
	xor dx, dx
	mov cl, 16
	div cl

	cmp ah, 9
	jna @@NUMBER_AH
	add ah, 39
@@NUMBER_AH:
	add ah, "0"­

	cmp al, 9
	jna @@NUMBER_AL
	add al, 39
@@NUMBER_AL:

	add al, "0"­
	mov [di], al
	inc di
	mov [di], ah

	inc di
	inc si
	pop cx
	loop CONVERT

OUTPUTT:
	; creates the output file
	xor cx, cx
	mov ax, 3C02h
	lea dx, output_file
	int 21h
	mov output, ax
	
	mov ah, 40h
	mov cx, 32
	lea dx, X_msg

	jc PRINT

	; Saves output to a file
	mov bx, output
	int 21h
	jmp EXIT
		
PRINT:
	; Prints output to stdout
	mov ah, 40h
	mov bx, 1
	int 21h

EXIT:
	;; Closes the file handles
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
end START
