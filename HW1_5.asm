; 5th task
; This program replaces spaces with characters before it from an string entered by the user eg:
; ab 12 oi8 -> abb122oi8

.model small
.stack 100h
.data
	greeter db "Please, enter a phraze: $"
	endl db 10, 13, "$"

	result_msg db "The result is: "
	buffer db 255, 0, 253 dup (?)

.code
START:
	mov dx, @data
	mov ds, dx

	; prints greeter
	mov ah, 09h
	mov dx, offset greeter
	int 21h

	; gets input
	mov ah, 0Ah
	mov dx, offset buffer
	int 21h

	; prints new line
	mov ah, 09h
	mov dx, offset endl
	int 21h

	mov cl, [buffer + 1]
	mov si, offset buffer + 1

	cmp cl, 0
	jne SKIP_LEADING_SPACES

	mov BYTE PTR [si - 2], "$"
	jmp END_OF_PROGRAM

SKIP_LEADING_SPACES:
	inc si
	mov dl, [si]
	mov [si - 2], dl

	cmp dl, ' '
	jne REPLACE
	loop SKIP_LEADING_SPACES

REPLACE:
	inc si
	mov dl, [si]

	cmp dl, ' '
	jne @@SKIP_LOOP

	mov dl, [si - 3]

@@SKIP_LOOP:
	mov [si - 2], dl
	loop REPLACE

	mov BYTE PTR [si - 1], "$"

END_OF_PROGRAM:
	; prints the esult
	mov ah, 09h
	mov dx, offset result_msg
	int 21h

	mov ax, 4C00h
	int 21h

end START
