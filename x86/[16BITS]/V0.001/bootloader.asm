; bootloader.asm
[org 0x7C00]

mov ah, 0x0E         ; BIOS teletype output
mov al, 'B'
int 0x10
mov al, 'O'
int 0x10
mov al, 'O'
int 0x10
mov al, 'T'
int 0x10
mov al, ' '
int 0x10
; Load kernel (assumes it's at sector 2)
mov bx, 0x8000       ; Load address for kernel
mov dh, 0            ; Head
mov dl, 0x80         ; First hard disk
mov ch, 0            ; Cylinder
mov cl, 2            ; Sector 2
mov ah, 2            ; Read sectors
mov al, 1            ; Number of sectors
int 0x13

jmp 0x0000:0x8000    ; Jump to kernel

times 510 - ($ - $$) db 0
dw 0xAA55            ; Boot signature
