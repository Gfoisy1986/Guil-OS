; kernel.asm
[org 0x8000]
mov ah, 0x0E
mov al, 'o'
int 0x10
mov ah, 0x0E
mov al, 'k'
int 0x10
mov ah, 0x0E
mov al, ' '
int 0x10
mov al, 'K'
int 0x10
mov al, 'E'
int 0x10
mov al, 'R'
int 0x10
mov al, 'N'
int 0x10
mov al, 'E'
int 0x10
mov al, 'L'
int 0x10

jmp $
