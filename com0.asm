.model tiny
.code
org 0100h
START:
	PUSH ax
	PUSH bx
	PUSH cx
	PUSH dx
	
	mov ax, 63
	mov bx, 31
	AND ax, bx

	mov ah, 0Ah
	DEC ah
	LEA dx, string
	int 21h
	
	mov cx, 5
@@LOOP:
	mov ah, 02h
	mov dl, "#"
	int 21h

	LOOP @@LOOP

	mov cx, 5
@@LOOPE:
	mov ah, 02h
	mov dl, "@"
	int 21h

	cmp cl, 5
	LOOPE @@LOOPE

	mov cx, 5
@@LOOPNE:
	mov ah, 02h
	mov dl, "%"
	int 21h

	cmp cl, ah
	LOOPNE @@LOOPNE

	LDS di, double
	; si = 0102
	; ds = 0304

	POP dx
	POP cx
	POP bx
	POP ax

	mov ax, 4C00h
	int 21h

; --- DATA ---
	string db "This is some text", 10, 13, "$"
	endl db 10, 13, "$"
	double dd 01020304h
end START
