
.loop:
	xor ah, ah
	int 0x16 ; read char from keyboard
	mov ah, 0x0e
	int 0x10 ; print the char out
	jmp .loop

; infinite loop
jmp $

times 510-($-$$) db 0
db 0x55, 0xaa