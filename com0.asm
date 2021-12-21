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

	DEC ax
	DEC bl
	inc di
	DEC di
	DEC [bp + 10h]
	DEC [bp]
	DEC byte ptr [si]
	DEC byte ptr [di + 20h]
	DEC byte ptr [si + 0AA20h]
	DEC byte ptr [si + bx]
	DEC byte ptr [si + bx + 20h]
	DEC byte ptr [si + bx + 0AA21h]
	DEC byte [bp + si + 1234h]

	mov ah, 0Ah
	DEC ah
	LEA dx, endl
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

	POP ds:[bx + 1111h]
	
	POP ss:bx

	POP ds
	POP es

	nop

	AND ax, bx
	AND bx, ax
	AND ax, si
	AND si, ax
	AND di, si

	AND ax, bx
	AND al, bl
	AND cl, dl
	AND ax, [bx + 10h]
	AND ax, [bx + 1234h]

	AND cx, [foo]
	AND cl, [bar]

	mov ax, 4C00h
	int 21h

; --- DATA ---
	string db "This is some text", 10, 13, "$"
	endl db 10, 13, "$"
	double dd 01020304h
	foo dw 0FFFFh
	bar db 0FFh
end START
