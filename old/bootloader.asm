; bootloader.asm
[org 0x7C00]

mov ah, 0x0E         ; BIOS teletype output

mov ax, 0x0000
mov ds, ax
mov si, msgk



call print
call newline
; Load kernel (assumes it's at sector 2)
mov bx, 0x8000       ; Load address for kernel
mov dh, 0            ; Head
mov dl, 0x80         ; First hard disk
mov ch, 0            ; Cylinder
mov cl, 2            ; Sector 2
mov ah, 2            ; Read sectors
mov al, 126       ; Number of sectors
int 0x13
jc disk_error         ; Jump if carry flag is set (error)




jmp 0x0000:0x8000    ; Jump to kernel


newline:
    mov al, 0x0D   ; Carriage return
    int 0x10
    mov al, 0x0A   ; Line feed
    int 0x10
    ret

disk_error:
    mov si, errmsg
    call print
    jmp $

; --- Print routine ---
print:
    mov ah, 0x0E        ; BIOS teletype function
.next_char:
    lodsb               ; Load byte at DS:SI into AL and increment SI
    cmp al, 0           ; Check for null terminator
    je .done            ; If zero, we're done
    int 0x10            ; Print character in AL
    jmp .next_char
.done:
    ret


errmsg db 'Disk read failed!', 0
msgk db 'loading kernel   ', 0
msgk2 db 'jmp to protected mode done...   ', 0


times 510 - ($ - $$) db 0
dw 0xAA55            ; Boot signature
