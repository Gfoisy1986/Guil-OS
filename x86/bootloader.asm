BITS 16
ORG 0x7C00

start:
    ; Set up the stack
    ; In real mode, the stack is a combination of the SS and SP registers.
    mov ax, 0
    mov ss, ax
    mov sp, 0x7C00               ; Stack grows down from 0x7C00

    mov ah, 0x02                    ; BIOS Read Sector function
    mov al, 4                     ; Number of sectors to read
    mov ch, 0                       ; Cylinder 0
    mov cl, 2                 ; Sector 2 (the first sector after the bootloader)
    mov dh, 0                       ; Head 0
    mov dl, 0x80                    ; Drive 0x80 (first hard disk).
    int 0x13 
    mov si, kernel_msg
    call print_string               ; Call BIOS interrupt
    jc error_read                   ; Jump if the carry flag is set (indicating an error)

    ; Disable interrupts
    cli

    ; Load GDT with LGDT instruction
    ; This loads the address and size of our GDT into the GDTR register.
    lgdt [gdt_descriptor]

    ; Enable the A20 line (allows access to more than 1MB of memory)
    ; This is a legacy step for compatibility with older systems.
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; Set the Protected Mode Enable (PE) bit in the CR0 register
    ; Setting this bit switches the CPU from real mode to protected mode.
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to the 16-bit protected mode code segment
    ; This jump flushes the instruction prefetch queue and loads CS with the new selector.
    jmp CODE_SEG:protected_mode_start

; This is our 16-bit protected mode code section.
; We must be careful not to use any real mode instructions here.
BITS 16
protected_mode_start:
    ; Set up data segment registers
    ; All segment registers must be reloaded with their new protected mode selectors.
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x9000                    ; New stack address in protected mode

    ; Jump to the kernel
    ; IMPORTANT: This must be a far jump to the correct segment and offset.
    ; The kernel starts at memory address 0x5000.
    mov si, kernel_msg2
    call print_string
    jmp CODE_SEG:0x5000          ; Jump to the kernel's entry point

error_read:
    mov si, read_error_msg
    call print_string
    jmp $

; Helper function to print a string
print_string:
    mov ah, 0x0E ; BIOS teletype output function
.loop:
    lodsb        ; Load byte from [SI] into AL
    test al, al  ; Check if AL is the null terminator (0)
    jz .done     ; If it is, jump to .done
    int 0x10     ; Call BIOS to print the character
    jmp .loop    ; Loop to the next character
.done:
    ret


gdt_start:
    ; Null Descriptor (required)
    ; The first entry in the GDT must be a null descriptor, which is never used.
    gdt_null:
        dd 0x0
        dd 0x0

    ; Code Segment Descriptor (Ring 0)
    ; This describes the segment where our code will reside.
    ; Base: 0x0, Limit: 0xFFFF.
    gdt_code:
        dw 0xFFFF                   ; Limit (bits 0-15)
        dw 0x0                      ; Base (bits 0-15)
        db 0x0                      ; Base (bits 16-23)
        db 10011010b                ; Access Byte: P(1),DPL(00),S(1),E(1),R/W(0),A(0)
        db 11001111b                ; Flags (4 bits), Limit (16-19).
        db 0x0                      ; Base (bits 24-31)

    ; Data Segment Descriptor (Ring 0)
    ; This describes the segment where our data will reside. It has the same
    ; base and limit as the code segment for simplicity.
    gdt_data:
        dw 0xFFFF                   ; Limit (bits 0-15)
        dw 0x0                      ; Base (bits 0-15)
        db 0x0                      ; Base (bits 16-23)
        db 10010010b                ; Access Byte: P(1), DPL(00), S(1), Type(0010)=Read/Write
        db 11001111b                ; Flags (4 bits), Limit (16-19)
        db 0x0                      ; Base (bits 24-31)
gdt_end:

; GDT Pointer for the LGDT instruction
; The LGDT instruction loads this 6-byte descriptor into the GDTR register.
gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; GDT size - 1
    dd gdt_start                    ; GDT base address

; Constants for segment selectors
; These are offsets into the GDT, used to select our code and data segments.
CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
; Messages
read_error_msg db 'Disk Read Error!', 0
kernel_msg db 'Loading Guil-OS Kernel...', 0
kernel_msg2 db 'Loading Kernel...', 0
kernel_loaded_msg db 'Kernel Loaded Successfully!', 0

; Fill the remaining bytes of the sector with 0s and add the boot signature
times 510 - ($ - $$) db 0
dw 0xAA55
