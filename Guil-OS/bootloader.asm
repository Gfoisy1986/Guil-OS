[org 0x7C00]

    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl        ; BIOS boot drive
    mov ah, 0x0E
    mov si, msg_loading
    call print





; ============================================================
; SCAN DISKS FOR GUIL-OS SIGNATURE IN SECTOR 2
; ============================================================
scan_disks:
    mov si, disk_list

next_disk:
    mov dl, [si]
    cmp dl, 0xFF
    je disk_error              ; no valid disk found

    cmp dl, 0xFE
    jne .use_dl
    mov dl, [boot_drive]       ; use BIOS boot drive
.use_dl:

    ; Read sector 2 into 0x8000
    mov bx, 0x8000
    mov dh, 0
    mov ch, 0
    mov cl, 2
    mov ah, 0x02
    mov al, 1
    int 0x13
    jc .try_next               ; read failed → next disk

    ; Check signature at start of sector
    cmp dword [0x8000], 'GOS!' ; your Guil-OS signature
    jne .try_next

    jmp load_kernel            ; FOUND VALID DISK

.try_next:
    inc si
    jmp next_disk



; ============================================================
; LOAD KERNEL (126 sectors) FROM SELECTED DL
; ============================================================
load_kernel:
    mov bx, 0x8000
    mov dh, 0
    mov ch, 0
    mov cl, 2
    mov ah, 0x02
    mov al, 128
    int 0x13
    jc disk_error

    cli
    jmp 0x0000:0x8000          ; jump to kernel



; ============================================================
; UTILITIES
; ============================================================
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

disk_error:
    mov si, msg_error
    call print
    jmp $


; ============================================================
; DATA
; ============================================================
boot_drive db 0

msg_loading db 'Scanning disks for Guil-OS...', 0
msg_error   db 'No valid Guil-OS disk found!', 0

; ============================================================
; DISK LIST (DL candidates)
; ============================================================
disk_list: db 0xFE, 0x80, 0x81, 0x00, 0xE0, 0xFF


; ============================================================
; BOOT SIGNATURE
; ============================================================
times 510 - ($ - $$) db 0
dw 0xAA55
