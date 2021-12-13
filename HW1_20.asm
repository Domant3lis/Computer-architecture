; 20th task
; This program replaces all spaces (expect leading ones) with numbers ranging form 0 to 9 e.g.:
; "a b c" -> "a0b1c"

.model small
.stack 100h
.data
	greeter db "Please, enter a phraze: $"
	endl db 10, 13, "$"

	result_msg db "The result is: "
	buffer db 255, 0, 253 dup (?)
	buffer_size db 0

.code
START:
	; gets data from the stack for later use
	mov dx, @data
	mov ds, dx

	; prints greeting message
	mov	ah, 09h
	mov dx, offset greeter
	int 21h

	; gets user input
    mov ah, 0Ah
    mov dx, offset buffer
    int 21h

	; prints end line
	mov ah, 09h
	mov dx, offset endl
	int 21h

	; sets up loop counter
	mov cl, [buffer + 1]
	mov [buffer_size], cl
	mov si, offset [buffer + 1]
	mov bl, '0'

	cmp cl, 0
	jne SKIP_LEADING_SPACES

	mov BYTE PTR [si - 2], "$"
	jmp END_OF_PROGRAM

SKIP_LEADING_SPACES:
	inc si
	mov dl, [si]
	mov [si - 2], dl

	cmp dl, ' '
	jne PROCESS
	loop SKIP_LEADING_SPACES

PROCESS:

	inc si
	mov dl, [si]
	mov [si - 2], dl

	cmp dl, ' '
	jne @@SKIP_LOOP

	mov [si - 2], bl
	inc bl

	; checks if bl is more than '9' and resets it back to '0' in case it is
	cmp bl, '9' + 1
	jne @@SKIP_LOOP

	mov bl, '0'
	jmp @@SKIP_LOOP

@@SKIP_LOOP:
	loop PROCESS

	mov BYTE PTR [si - 1], '$'

END_OF_PROGRAM:
	; prints the result
	mov ah, 40h
	mov bx, 1
	xor cx, cx
	mov cl, [buffer_size] 
	mov dx, offset result_msg
	add dx, 15
	int 21h

	; exits the program
	mov ax, 4C00h
	int 21h

end START
