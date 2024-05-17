global start

section .text
bits 32
start:
  ; print shit
  mov dword [0xb8000], 0x2f4b2f43
  hlt