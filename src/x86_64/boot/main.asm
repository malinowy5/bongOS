global start
extern long_mode_start 

section .text
bits 32
start:
  mov esp, stack_top

  call check_multiboot 
  call check_cpuid
  call check_long_mode

  call setup_page_tables
  call enable_paging

  lgdt [gdt64.pointer]
  jmp gdt64.code_segment:long_mode_start
  hlt

check_multiboot:
  ; check the magic number
  cmp eax, 0x36d76289
  jne .no_multiboot
  ret
.no_multiboot:
  mov al, "M"
  jmp error

check_cpuid:
  pushfd
  pop eax
  mov ecx, eax
  ; flip the cpuid bit 
  xor eax, 1 << 21
  push eax
  popfd
  pushfd
  pop eax
  push ecx
  popfd
  ; check if the cpuid bit got flipped back
  cmp eax, ecx
  je .no_cpuid
  ret 
.no_cpuid:
  mov al, "C"
  jmp error

check_long_mode:
  mov eax, 0x80000000
  cpuid
  cmp eax, 0x80000001
  jb .no_long_mode
  
  mov eax, 0x80000001
  cpuid
  ; test if the lm (long mode) bit is set
  test edx, 1 << 29
  jz .no_long_mode

  ret
.no_long_mode:
  mov al, "L"
  jmp error

setup_page_tables:
  mov eax, page_table_l3
  or eax, 0b11 ; present, writable
  mov [page_table_l4], eax

  mov eax, page_table_l2
  or eax, 0b11 ; present, writable
  mov [page_table_l3], eax

  xor ecx, ecx ; counter
.loop:
  
  mov eax, 0x200000 ; 2MiB
  mul ecx
  or eax, 0b10000011 ; present, writable, huge page
  mov [page_table_l2 + ecx * 8], eax

  inc ecx
  cmp ecx, 512 ; check if whole table mapped
  jne .loop

  ret

enable_paging:
  ; pass page table address to cpu
  mov eax, page_table_l4
  mov cr3, eax

  ;enable Physical Address Extension
  mov eax, cr4
  or eax, 1 << 5 ; PAE flag
  mov cr4, eax

  ; enable long mode
  mov ecx, 0xc0000080
  rdmsr
  or eax, 1 << 8 ; long mode flag
  wrmsr

  ; enable paging
  mov eax, cr0
  or eax, 1 << 31 ; paging flag
  mov cr0, eax

  ret

error:
  ; print ERR: X, where X is the error code (letter)
  mov dword [0xb8000], 0x4f524f45
  mov dword [0xb8004], 0x4f3a4f52
  mov dword [0xb8008], 0x4f204f20
  mov byte [0xb800a], al
  hlt


section .bss

align 4096

page_table_l4:
  resb 4096
page_table_l3:
  resb 4096
page_table_l2:
  resb 4096

stack_bottom:
  resb 4096 * 4
stack_top:

section .rodata
gdt64:
  dq 0 ; zero entry
.code_segment: equ $ - gdt64
  dq (1 << 43) | (1 << 44) | (1<<47) | (1 <<  53)  ; code segment, magic flags
.pointer:
  dw $ - gdt64 - 1
  dq gdt64