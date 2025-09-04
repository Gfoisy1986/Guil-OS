; ---------------------------------------------------------------------------------------------------------------------
; A simple 32-bit bootloader that switches the CPU from 16-bit Real Mode to 32-bit Protected Mode.
; This code is a boot sector, loaded by the BIOS at 0x7C00.
; Its purpose is to prepare the CPU environment and then load and jump to a 32-bit kernel.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x7c00]                    ; Set the origin of the code to 0x7c00, the address where the BIOS loads the boot sector.
[bits 16]                       ; The CPU starts in 16-bit real mode. All instructions must be 16-bit initially.

KERNEL_SECTOR_COUNT equ 10      ; Constant for the number of sectors to load for our kernel.
KERNEL_LOAD_ADDR equ 0x10000    ; Constant for the memory address where the 32-bit kernel will be loaded.

; --- The Bootloader Code ---
start:
    ; Set up the segment registers for a clean environment.
    xor ax, ax                  ; Clear the AX register.
    mov ds, ax                  ; Set the Data Segment register to 0.
    mov es, ax                  ; Set the Extra Segment register to 0.
    mov ss, ax                  ; Set the Stack Segment register to 0.
    mov sp, 0x7c00              ; Set the Stack Pointer to the start of the boot sector.

    ; Print a message to the screen using BIOS interrupt 0x10.
    mov si, boot_msg            ; Load the address of the boot message string into SI (Source Index).
    call print_string_16        ; Call the subroutine to print the string.

    ; Load the kernel from disk. We use BIOS interrupt 0x13, which works in 16-bit real mode.
    mov ah, 0x02                ; Function 0x02: Read Sector(s) from drive.
    mov al, KERNEL_SECTOR_COUNT ; AL = number of sectors to read.
    mov ch, 0x00                ; CH = cylinder number (0).
    mov cl, 0x02                ; CL = sector number (start reading from sector 2, as sector 1 is the boot sector itself).
    mov dh, 0x00                ; DH = head number (0).
    mov dl, 0x00                ; DL = drive number (A:, 00h).
    mov bx, KERNEL_LOAD_ADDR    ; BX = destination buffer address.
    int 0x13                    ; Call the BIOS interrupt to perform the read operation.
    
    ; Check for read errors.
    jc read_error

    ; --- Transition to 32-bit Protected Mode ---
    
    ; 1. Disable interrupts. We don't want any interrupts occurring during the mode switch.
    cli                         ; Clear the Interrupt Flag.

    ; 2. Load the Global Descriptor Table (GDT).
    lgdt [gdt_descriptor]       ; Load the GDT into the GDTR register. The GDT is a crucial table that defines our memory segments.

    ; 3. Enable the Protected Mode bit in the CR0 control register.
    mov eax, cr0                ; Move the contents of the CR0 register into EAX.
    or eax, 1                   ; Set the Protected Mode Enable (PE) bit.
    mov cr0, eax                ; Move the new value back into CR0.
    
    ; The CPU is now in protected mode, but the segment registers still hold 16-bit selectors.
    ; We need a long jump to reset the instruction pipeline and reload CS with a 32-bit selector.
    jmp dword 0x08:protected_mode_start ; Jump to the 'protected_mode_start' label using the Code Segment Selector (0x08).
    
[bits 32]                       ; The code from here on is 32-bit.
protected_mode_start:
    ; 4. Set up the 32-bit segment registers.
    ; Now that we are in protected mode, we can use the 32-bit data segment selector (0x10).
    mov eax, 0x10               ; Load the data segment selector into EAX.
    mov ds, eax                 ; Set the Data Segment register.
    mov es, eax                 ; Set the Extra Segment register.
    mov fs, eax                 ; Set the FS Segment register.
    mov gs, eax                 ; Set the GS Segment register.
    mov ss, eax                 ; Set the Stack Segment register.
    
    ; The stack pointer is already set for 32-bit from the real mode code.
    ; The kernel is loaded, and the CPU is in 32-bit protected mode.
    
    ; 5. Jump to the 32-bit kernel.
    jmp KERNEL_LOAD_ADDR        ; Jump to the entry point of our 32-bit kernel.

read_error:
    ; If there's a disk read error, display an error message and halt.
    mov si, error_msg           ; Load the address of the error message string.
    call print_string_16        ; Print the error message.
    cli                         ; Disable all interrupts.
    hlt                         ; Halt the CPU indefinitely.

; --- Subroutine to Print a Null-Terminated String in 16-bit Mode ---
; Input: SI = Address of the string to print.
print_string_16:
    mov ah, 0x0e                ; Function 0x0E: Teletype Output. Prints a character to the screen.
.loop:
    lodsb                       ; Load a byte from the string (pointed to by SI) into AL and increment SI.
    or al, al                   ; Check if the character is the null terminator.
    jz .done                    ; If it is, jump to .done.
    int 0x10                    ; Call the BIOS interrupt to print the character in AL.
    jmp .loop                   ; Loop back to print the next character.
.done:
    ret                         ; Return from the subroutine.

; --- Data Section ---
boot_msg db 'Switching to 32-bit Protected Mode...', 0x0d, 0x0a, 0
error_msg db 'Disk read error!', 0x0d, 0x0a, 0

; --- Global Descriptor Table (GDT) ---
; The GDT is a table of descriptors that define memory segments.
gdt_start:
    ; Null Descriptor (required)
    dq 0                        ; A 64-bit value of 0.

    ; Code Segment Descriptor
    dw 0xFFFF                   ; Limit (bits 0-15) - 0x00FFFF
    dw 0x0000                   ; Base (bits 0-15) - 0x00000000
    db 0x00                     ; Base (bits 16-23)
    db 10011010b                ; Access Byte (P, DPL, S, Type)
    db 11001111b                ; Flags (G, D/B, L, AVL) and high 4 bits of Limit
    db 0x00                     ; Base (bits 24-31)

    ; Data Segment Descriptor
    dw 0xFFFF                   ; Limit (bits 0-15)
    dw 0x0000                   ; Base (bits 0-15)
    db 0x00                     ; Base (bits 16-23)
    db 10010010b                ; Access Byte (P, DPL, S, Type)
    db 11001111b                ; Flags (G, D/B, L, AVL) and high 4 bits of Limit
    db 0x00                     ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT Limit (size of the GDT - 1)
    dd gdt_start                ; GDT Base Address

; --- Boot Sector Padding and Signature ---
times 510 - ($ - $$) db 0       ; Pad the entire bootloader to 510 bytes.
dw 0xAA55                       ; Boot signature (0xAA55), required by the BIOS.