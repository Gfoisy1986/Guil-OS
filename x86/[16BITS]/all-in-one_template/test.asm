[bits 16]
org 0x7C00

start:
    
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov si, msg
    call print_string

    call kernel


kernel:
mov si, msg2
call print_string
jmp $

print_error:
    mov si, error_message
    call print_string
    jmp $

print_string:
    pusha
.next_char:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .next_char
.done:
    popa
    ret



error_message db 'Disk read error!', 0
msg db 'heya', 0
msg2 db 'prot. no activation', 0

times 510 - ($ - $$) db 0
dw 0xAA55


