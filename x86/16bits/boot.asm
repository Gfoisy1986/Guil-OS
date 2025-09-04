; ---------------------------------------------------------------------------------------------------------------------
; This is the initial boot sector, loaded at memory address 0x7c00.
; Its job is to set up the environment and load the kernel.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x7c00]

; --- Constants and Data ---
KERNEL_SECTOR_COUNT equ 10  ; The number of sectors the kernel occupies
KERNEL_LOAD_ADDRESS equ 0x8000 ; The memory address to load the kernel to

; --- Main Routine ---
main:
    ; Set up the segment registers
    mov ax, 0x07c0
    mov ds, ax
    mov es, ax

    ; Set up the stack
    mov ax, 0x9000
    mov ss, ax
    mov sp, 0xffff

    ; Clear the screen
    mov ah, 0x00
    mov al, 0x03  ; 80x25 text mode
    int 0x10

    ; Print a welcome message
    mov si, welcome_msg
    call print_string
    
    ; Print a loading message
    mov si, loading_msg
    call print_string

    ; Load the kernel from the disk
    ; BIOS interrupt 0x13, service 0x02
    mov ah, 0x02            ; Read sectors from disk
    mov al, KERNEL_SECTOR_COUNT  ; Number of sectors to read
    mov ch, 0x00            ; Cylinder (track)
    mov cl, 0x02            ; Sector (starting from 1, so sector 2 is LBA 1)
    mov dh, 0x00            ; Head
    mov dl, 0x00            ; Drive (floppy A:)
    mov bx, KERNEL_LOAD_ADDRESS ; Buffer address for data
    int 0x13
    
    ; Check for errors
    jc disk_error

    ; Jump to the loaded kernel
    jmp KERNEL_LOAD_ADDRESS

; --- Subroutines ---
; print_string: Prints a null-terminated string at [si]
print_string:
    mov ah, 0x0e  ; Teletype output
.loop:
    lodsb         ; Load byte from [si] into al, increment si
    or al, al     ; Check if it's the null terminator
    jz .done      ; If zero, we are done
    int 0x10      ; Otherwise, print the character
    jmp .loop
.done:
    ret

; disk_error: Prints an error message and halts the system
disk_error:
    mov si, disk_error_msg
    call print_string
    cli           ; Clear interrupts
    hlt           ; Halt the system
    
; --- Messages ---
welcome_msg:       db 'Welcome to my 16-bit OS!', 0x0d, 0x0a, 0x00
loading_msg:       db 'Loading kernel...', 0x0d, 0x0a, 0x00
disk_error_msg:    db 'Disk read error!', 0x0d, 0x0a, 0x00

; --- Padding and Boot Signature ---
times 510-($-$$) db 0  ; Fill the rest of the boot sector with zeros
dw 0xAA55              ; Boot signature