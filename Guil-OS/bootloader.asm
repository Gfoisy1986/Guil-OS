[org 0x7C00]

<<<<<<< Updated upstream
=======
KERNEL_LOAD_SEG equ 0x0900
KERNEL_LOAD_OFF equ 0x0000
KERNEL_LBA      equ 1          ; kernel starts at LBA 1 (seek=1 in build script)



; ------------------------------------------------------------
; Entry
; ------------------------------------------------------------
start:
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
    ; Check signature at start of sector
    cmp dword [0x8000], 'GOS!' ; your Guil-OS signature
    jne .try_next

=======
    ; --------------------------------------------------------
    ; Read 1 sector at KERNEL_LBA into 0x0000:0x8000
    ; to check 'GOS!' signature
    ; --------------------------------------------------------
    mov word [dap_sectors], 1
    mov word [dap_offset], KERNEL_LOAD_OFF   ; 0x0000
	mov word [dap_segment], KERNEL_LOAD_SEG  ; 0x1000
    mov dword [dap_lba], KERNEL_LBA
    mov dword [dap_lba+4], 0

    mov si, dap
    mov ah, 0x42
    int 0x13
    jc .try_next

    ; Check signature
    mov ax, KERNEL_LOAD_SEG
	mov ds, ax
	cmp dword [0x9000], 'GOS!'
    jne .try_next
   ; mov si, found
   ; call print
>>>>>>> Stashed changes
    jmp load_kernel            ; FOUND VALID DISK

.try_next:
    inc si
    jmp next_disk

<<<<<<< Updated upstream


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
=======
; ------------------------------------------------------------
; Load full kernel using LBA
; ------------------------------------------------------------
load_kernel:
	mov word [dap_sectors], 238
    mov word [dap_offset], KERNEL_LOAD_OFF   ; 0x0000
	mov word [dap_segment], KERNEL_LOAD_SEG  ; 0x1000
    mov dword [dap_lba], KERNEL_LBA
    mov dword [dap_lba+4], 0

    mov si, dap
    mov ah, 0x42
    int 0x13

	cli
	jmp KERNEL_LOAD_SEG:KERNEL_LOAD_OFF
>>>>>>> Stashed changes



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
