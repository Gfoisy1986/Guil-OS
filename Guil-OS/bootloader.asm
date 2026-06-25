[org 0x7C00]

KERNEL_LOAD_SEG equ 0x2000
KERNEL_LOAD_OFF equ 0x0000
KERNEL_LBA      equ 1          ; kernel starts at LBA 1 (seek=1 in build script)



; ------------------------------------------------------------
; Entry
; ------------------------------------------------------------
start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9FF0        ; safer stack above bootloader

    mov dl, [boot_drive]       ; BIOS boot drive
    mov si, msg_loading
    call print

    mov si, disk_list

; ------------------------------------------------------------
; Scan candidate disks using EDD (int 13h extensions)
; ------------------------------------------------------------
next_disk:
    mov dl, [si]
    cmp dl, 0xFF
    je disk_error              ; no valid disk found

    cmp dl, 0xFE
    jne .use_dl
    mov dl, [boot_drive]       ; use BIOS boot drive
.use_dl:

    ; Check EDD support
    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc .try_next               ; no EDD
    cmp bx, 0xAA55
    jne .try_next              ; invalid signature

    ; --------------------------------------------------------
    ; Read 1 sector at KERNEL_LBA into 0x0000:0x8000
    ; to check 'GOS!' signature
    ; --------------------------------------------------------
    mov word [dap_sectors], 267
    mov word [dap_offset], KERNEL_LOAD_OFF   ; 0x0000
	mov word [dap_segment], KERNEL_LOAD_SEG  ; 0x1000
    mov dword [dap_lba], KERNEL_LBA
    mov dword [dap_lba+4], 0

    mov si, dap
    mov ah, 0x42
    int 0x13
    jc .try_next

    ; Check signature
    mov ax, 0x2000
	mov ds, ax
	cmp dword [0x0000], 'GOS!'
    jne .try_next
    mov si, found
    call print
    jmp load_kernel            ; FOUND VALID DISK

.try_next:
    inc si
    jmp next_disk

; ------------------------------------------------------------
; Load full kernel using LBA
; ------------------------------------------------------------
load_kernel:
    mov word [dap_sectors], 267
	mov word [dap_offset], KERNEL_LOAD_OFF    ; 0x0000
	mov word [dap_segment], KERNEL_LOAD_SEG   ; 0x1000
	mov dword [dap_lba], KERNEL_LBA
	mov dword [dap_lba+4], 0

	mov si, dap
	mov ah, 0x42
	int 0x13

    cli
	jmp KERNEL_LOAD_SEG:KERNEL_LOAD_OFF


; ------------------------------------------------------------
; Utilities
; ------------------------------------------------------------
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

; ------------------------------------------------------------
; Data
; ------------------------------------------------------------
boot_drive db 0

msg_loading db 'Scanning disks for Guil-OS (LBA)...', 0
msg_error   db 'No valid Guil-OS disk found or EDD unsupported!', 0
found db 'disk found', 0
; Candidate DL values:
; 0xFE = use BIOS boot drive
; 0x80, 0x81 = typical HDDs
; 0x00, 0xE0 = floppies/other
; 0xFF = end marker
disk_list db 0xFE, 0x80, 0x81, 0x00, 0xE0, 0xFF

; ------------------------------------------------------------
; Disk Address Packet (DAP) for int 13h AH=42h
; ------------------------------------------------------------
dap:
    db 0x10
    db 0
dap_sectors:
    dw 0
dap_offset:
    dw 0
dap_segment:
    dw 0
dap_lba:
    dq 0

; ------------------------------------------------------------
; Boot signature
; ------------------------------------------------------------
times 510 - ($ - $$) db 0
dw 0xAA55
