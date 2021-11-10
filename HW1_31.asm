; PS1 ~ Domantas Keturakis ~ 31st task
; The program takes a string from a user end replaces each letter with a symetrical letter from the alphabet:
; abc -> zyx

.model small
.stack 100h
.data
	greeter db "Please, enter a phraze: $"
	endl db 10, 13, "$"

	result_msg db "The result is: " ; 15
	buffer db 255, 0, 253 dup (?)

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
	xor cx, cx
	mov cl, [buffer + 1]
	mov si, offset [buffer + 1]

	; handles no input
	cmp cl, 0
	jne CONVERT

	; mov BYTE PTR [si - 2], "$"
	jmp END_OF_PROGRAM

CONVERT:
	inc si
	mov dl, [si]

	; this code does range checking
		; checks for range [00h, 'A')
		cmp dl, 'A'
		jb @@SKIP_LOOP

		; checks for range ('z', 127]
		cmp dl, 'z'; 7Ah ; 'z'
		ja @@SKIP_LOOP

		; checks for range ['a', 'z']
		cmp dl, 'a'
		jnb @@CONVERTION_LOWER_CASE

		; checks for range ('Z'; 127)
		cmp dl, 'Z'
		ja @@SKIP_LOOP

		; checks for range (0; 'A')
		cmp dl, 'A'
		jb @@SKIP_LOOP

; @@CONVERTION_CAPITAL_CASE:

	; [si] = 'A' + ('Z' - [si])
	; 					|
	; This shows a letter's position counting from the end of the alphabet
	; Consult ASCII table for clarity

	mov dl, 'Z'
	sub dl, [si]
	add dl, 'A'

	jmp @@SKIP_LOOP

@@CONVERTION_LOWER_CASE:
	; [si] = 'a' + ('z' - [si])
	mov dl, 'z'
	sub dl, [si]
	add dl, 'a'

@@SKIP_LOOP:
	mov [si - 2], dl
	loop CONVERT
	dec si

END_OF_PROGRAM:
	; prints the result
	mov ah, 40h
	mov bx, 1
	mov cx, si
	sub cx, offset buffer - 15
	mov dx, offset result_msg; + [si]
	int 21h

	; exits the program
	mov ax, 4C00h
	int 21h

end START
