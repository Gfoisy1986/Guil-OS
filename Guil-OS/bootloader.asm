; ================================
; Guil-OS Bootloader (Stage 1)
; ================================
[org 0x7C00]

    cli                     ; Désactive interruptions
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00          ; Stack simple (évite écraser bootloader)

    mov ah, 0x0E
    mov si, msg_loading
    call print

; ================================
; Lecture du kernel (126 secteurs)
; ================================
    mov bx, 0x8000          ; Adresse de chargement du kernel
    mov dh, 0               ; Head
    mov dl, 0x80            ; Disque dur principal
    mov ch, 0               ; Cylinder
    mov cl, 2               ; Secteur 2
    mov ah, 0x02            ; Fonction BIOS: lire secteurs
    mov al, 126             ; Nombre de secteurs à lire
    int 0x13
    jc disk_error

; ================================
; Jump vers le kernel
; ================================
    cli
    jmp 0x0000:0x8000       ; Jump far vers kernel

; ================================
; Routines utilitaires
; ================================
print:
    mov ah, 0x0E
.next:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .next
.done:
    ret

newline:
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

disk_error:
    mov si, msg_error
    call print
    jmp $

; ================================
; Messages
; ================================
msg_loading db 'Loading Guil-OS kernel...', 0
msg_error   db 'Disk read failed!', 0

; ================================
; Boot signature
; ================================
times 510 - ($ - $$) db 0
dw 0xAA55
