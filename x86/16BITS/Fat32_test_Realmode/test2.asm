[org 0x1000]
[bits 16]
start:
    mov si, msg
    call print_string
    jmp $

print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

msg db "Stage 2 loaded successfully!", 0

times 29696 - ($ - $$) db 0
