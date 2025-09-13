ORG 0x5000

start:
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov ax, 0x0F20
    mov cx, 2000
    rep stosw
    hlt ; Halt the CPU




times 1024-($-$$) db 0