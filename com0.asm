;  POP, AND, DEC
;  LOOP, LOOPE, LOOPNE, LDS
;  LEA

;  NOP
;  PUSH (only 2nd var.)

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
	DEC dx
	DEC ds:bx
	DEC bl
	inc di
	DEC di
	DEC [bp + 1000h]
	DEC [bp]
	DEC byte ptr [si]
	DEC byte ptr [di + 20h]
	DEC byte ptr [si + 0AA20h]
	DEC byte ptr [si + bx]
	DEC byte ptr [si + bx + 20h]
	DEC byte ptr [si + bx + 0AA21h]
	DEC byte ptr [bp + si + 1234h]

	mov ah, 0Ah
	DEC ah
	DEC bh
	DEC ch
	DEC dh
	lea dx, [bx + 1000h]
	int 21h
	
	mov cx, 5
@@LOOP:
	mov ah, 02h
	mov dl, "#"
	int 21h
	inc di
	inc si

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
	LDS di, [bx + 10h]
	NOP
	LDS di, es:[bx + 10h]
	LDS si, [bx + 1020h]

	POP dx
	POP cx
	POP bx
	POP cs:bx
	POP es:[bx + 1111h]
	POP ss:bx
	POP ds
	POP es

	nop

	AND es:bx, 1000h
	AND cx, 0BBBBh
	AND bl, 0BBh

	; AND 1000h

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
	AND [bx + 10h], bx
	AND cx, [bx + 1234h]

	AND cx, [foo]
	AND cl, [bar]

	mov ax, 4C00h
	int 21h

; --- DATA ---
	string db "This is some text", 10, 13, "$"
	endl db 10, 13, "$"
	double dd 12345678h
	foo dw 0FFFFh
	bar db 0FFh
end START
