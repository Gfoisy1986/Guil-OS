; bootloader.asm
[org 0x7C00]

dap:
    db 0x10, 0x00      ; Size, reserved
    dw 1               ; Number of sectors
    dw buffer          ; Offset
    dw 0               ; Segment (placeholder)
    dq 204800          ; LBA


dap_kernel:
    db 0x10, 0x00
    dw 100
    dw 0x8000        ; Offset
	dw 0x0000        ; Segment (later patched to CS)

    dq 1
    
mov ah, 0x0E
mov al, 'B'
int 0x10




mov ah, 0x42         ; Read sector
mov al, 101          ; Number of sectors
mov ch, 0             ; Cylinder
mov cl, 1             ; Sector (starts at 1)
mov dh, 0             ; Head
mov dl, 0x80          ; First hard disk
mov bx, buffer        ; ES:BX points to buffer
mov ax, cs
mov [dap + 6], ax     ; Set segment field in DAP
mov ds, ax
mov si, dap
int 0x13
mov ah, 0x0E
mov al, 'R'
int 0x10

jc disk_error         ; Handle error

mov si, buffer

; BytesPerSector (optional if always 512)
mov ax, [si + 0x0B]
mov [0x9000], ax

; SectorsPerCluster
mov al, [si + 0x0D]
mov [0x9002], al

; ReservedSectors
mov ax, [si + 0x0E]
mov [0x9003], ax

; NumberOfFATs
mov al, [si + 0x10]
mov [0x9005], al

; FATSize32
mov eax, [si + 0x24]
mov [0x9006], eax

; RootCluster
mov eax, [si + 0x2C]
mov [0x900A], eax





mov si, msgk
call print
call newline
mov ah, 2
mov ax, cs
mov [dap_kernel + 6], ax
mov es, ax
mov bx, 0x8000
mov ds, ax
mov si, dap_kernel
mov ah, 0x42
mov dl, 0x80
int 0x13
jc disk_error



mov ah, 0x0E
mov al, 'K'
int 0x10

jmp 0x0000:0x8000




mov ah, 0x0E
mov al, 'G'
int 0x10



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






section .data
    errmsg db 'Disk read failed!', 0
    msgk db 'loading kernel   ', 0
    msgk2 db 'jmp to protected mode done...   ', 0

    buffer db 512 dup(0) ; reserve 512 bytes for boot sector

    ; FAT32 Boot Sector Parameters
    BytesPerSector      dw    0x0200      ; 512 bytes per sector
    SectorsPerCluster   db    0x08        ; 8 sectors per cluster (4 KB clusters)
    ReservedSectors     dw    0x3190      ; 202752 sectors = 99 MB
    NumberOfFATs        db    0x02        ; standard for FAT32
    FATSize32           dd    0x00004000  ; 16384 sectors per FAT (8 MB per FAT)
    RootCluster         dd    0x00000002  ; root directory starts at cluster 2


	
section .text
    ; Load BytesPerSector (offset 0x0B, 2 bytes)
    mov ax, [buffer + 0x0B]
    mov [BytesPerSector], ax

    ; Load SectorsPerCluster (offset 0x0D, 1 byte)
    mov al, [buffer + 0x0D]
    mov [SectorsPerCluster], al

    ; Load ReservedSectors (offset 0x0E, 2 bytes)
    mov ax, [buffer + 0x0E]
    mov [ReservedSectors], ax

    ; Load NumberOfFATs (offset 0x10, 1 byte)
    mov al, [buffer + 0x10]
    mov [NumberOfFATs], al

    ; Load FATSize32 (offset 0x24, 4 bytes)
    mov eax, [buffer + 0x24]
    mov [FATSize32], eax

    ; Load RootCluster (offset 0x2C, 4 bytes)
    mov eax, [buffer + 0x2C]
    mov [RootCluster], eax



times 510 - ($ - $$) db 0
dw 0xAA55
