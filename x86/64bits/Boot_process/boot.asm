; ---------------------------------------------------------------------------------------------------------------------
; A simple 64-bit bootloader that loads a kernel, sets up a minimal 
; environment, and switches to Long Mode.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x7c00]                    ; Set the origin address to 0x7c00, where the BIOS loads the boot sector.
[bits 16]                       ; Use 16-bit instructions, as the CPU starts in 16-bit Real Mode.

KERNEL_SECTOR_COUNT equ 10      ; Define a constant for the number of sectors to load for the kernel.
KERNEL_LOAD_ADDR    equ 0x10000 ; Define a constant for the physical memory address to load the kernel to.

; --- 16-bit Code: The Entry Point ---
start:
    ; Reset the disk system
    xor ax, ax                  ; Clear the AX register.
    mov ds, ax                  ; Set the Data Segment register to 0.
    mov es, ax                  ; Set the Extra Segment register to 0.
    mov ss, ax                  ; Set the Stack Segment register to 0.
    mov sp, 0x7c00              ; Set the stack pointer. The stack grows downwards from the bootloader address.
    
    ; Clear the screen using BIOS interrupt 0x10, function 0x00.
    mov ah, 0x00                ; Function 0x00: Set Video Mode.
    mov al, 0x03                ; Video mode 03h: 80x25 text mode.
    int 0x10                    ; Call the BIOS interrupt.

    ; Load the kernel from disk using BIOS interrupt 0x13, function 0x02.
    mov ah, 0x02                ; Function 0x02: Read Sector(s) from Drive.
    mov al, KERNEL_SECTOR_COUNT ; AL = number of sectors to read.
    mov ch, 0x00                ; CH = cylinder number (0).
    mov cl, 0x02                ; CL = sector number (start reading from sector 2).
    mov dh, 0x00                ; DH = head number (0).
    mov dl, 0x00                ; DL = drive number (A:, 00h).
    mov bx, KERNEL_LOAD_ADDR    ; BX = destination buffer address.
    int 0x13                    ; Call the BIOS interrupt to perform the read.
    
    ; Check for read errors. The 'jc' (Jump if Carry) instruction checks the carry flag,
    ; which is set by the BIOS if a read error occurs.
    jc read_error

    ; --- Switch to 32-bit Protected Mode ---
    
    cli                         ; Disable interrupts. This is a crucial step before transitioning modes.
                                ; Interrupts must be disabled until a proper Interrupt Descriptor Table (IDT) is set up.
    
    ; Load the Global Descriptor Table (GDT) using the 'lgdt' instruction.
    lgdt [gdt_descriptor]       ; Load the GDT descriptor, which points to the GDT's base address and limit.
    
    ; Enable Protected Mode by setting the lowest bit (PE) in the CR0 control register.
    mov eax, cr0                ; Move the current value of CR0 into EAX.
    or eax, 1                   ; Set the PE (Protected Enable) bit.
    mov cr0, eax                ; Write the modified value back to CR0.
    
    ; Jump to the 32-bit code section. This is a far jump to clear the prefetch queue and
    ; force the processor to reload segment registers.
    jmp dword 0x08:protected_mode_start ; Jump to a 32-bit offset using the code segment selector (0x08).

; --- 32-bit Protected Mode Code ---
[bits 32]                       ; Switch the assembler to 32-bit instruction mode.
protected_mode_start:
    ; Set up the segment registers with the data segment selector (0x10).
    mov ax, 0x10
    mov ds, ax                  ; Data Segment
    mov es, ax                  ; Extra Segment
    mov fs, ax                  ; FS Segment
    mov gs, ax                  ; GS Segment
    mov ss, ax                  ; Stack Segment
    mov esp, 0x9000             ; Set the 32-bit stack pointer.

    ; --- Setup Paging for Long Mode ---
    
    ; Load the Page Map Level 4 (PML4) table's physical address into the CR3 register.
    mov eax, pml4_table
    mov cr3, eax                ; CR3 holds the physical base address of the PML4 table.
    
    ; Set up the PML4 entry to point to the Page Directory Pointer Table (PDPT).
    mov dword [pml4_table], pdpt_table + 7 ; Address of PDPT plus present (bit 0) and read/write (bit 1) flags.
    
    ; Set up the PDPT entry to point to the Page Directory (PD).
    mov dword [pdpt_table], pd_table + 7
    
    ; The Page Directory (PD) contains entries for mapping memory.
    mov ecx, 0
.map_1gb_loop:
    ; Map 1GB of physical memory using large pages (2MB or 1GB pages).
    ; 0x00000083 = Present (bit 0), Read/Write (bit 1), Page Size (bit 7 - for 2MB pages)
    mov dword [pd_table + ecx*8], ecx + 0x00000083 ; Identity map 1GB of memory.
    add ecx, 0x200000           ; Add 2MB for the next page directory entry.
    cmp ecx, 0x40000000         ; Check if we've mapped 1GB (0x40000000).
    jne .map_1gb_loop           ; Loop until 1GB is mapped.

    ; --- Enable Long Mode ---
    
    ; Set the PAE (Physical Address Extension) bit in CR4.
    mov eax, cr4
    or eax, 1<<5                ; Set bit 5 (PAE).
    mov cr4, eax                ; Write the updated value back to CR4.
    
    ; Set the LME (Long Mode Enable) bit in the EFER Model-Specific Register (MSR).
    mov ecx, 0xc0000080         ; Load the MSR number for EFER into ECX.
    rdmsr                       ; Read the MSR into EDX:EAX.
    or eax, 1<<8                ; Set bit 8 (LME).
    wrmsr                       ; Write the value from EDX:EAX back to the MSR.
    
    ; Set the PG (Paging Enable) and PE (Protected Enable) bits in CR0.
    mov eax, cr0
    or eax, (1<<31) | 1         ; Set bit 31 (PG) and bit 0 (PE).
    mov cr0, eax                ; Write the final value to CR0, enabling paging and long mode.
    
    ; --- Jump to 64-bit kernel ---
    ; This is a long jump to the 64-bit kernel entry point. The processor is now in Long Mode.
    jmp KERNEL_LOAD_ADDR

read_error:
    ; A simple error routine to print an error message if the kernel can't be loaded.
    mov ah, 0x0e                ; Function 0x0E: Teletype Output.
    mov al, 'E'
    int 0x10                    ; Print 'E'
    mov al, 'R'
    int 0x10                    ; Print 'R'
    mov al, 'R'
    int 0x10                    ; Print 'R'
    mov al, 'O'
    int 0x10                    ; Print 'O'
    mov al, 'R'
    int 0x10                    ; Print 'R'
    cli                         ; Disable all interrupts.
    hlt                         ; Halt the CPU indefinitely.

; --- Data Section ---

; GDT Structure
gdt_start:
    gdt_null: equ $-gdt_start   ; Null descriptor: required by the CPU.
        dq 0
    gdt_code: equ $-gdt_start   ; 64-bit Code descriptor.
        dw 0xFFFF               ; Limit: not used in Long Mode but required for compatibility.
        dw 0x0000               ; Base: not used in Long Mode.
        db 0x00                 ; Base: not used.
        db 0x9A                 ; Access byte: Present (P=1), DPL 00 (Ring 0), Code (S=1), Readable (R=1), Conforming (C=0).
        db 0xA0                 ; Flags: Granularity (G=1), 64-bit mode (L=1), Default Op Size (D=0).
        db 0x00                 ; Base: not used.
    gdt_data: equ $-gdt_start   ; Data descriptor.
        dw 0xFFFF
        dw 0x0000
        db 0x00
        db 0x92                 ; Access byte: Present (P=1), DPL 00 (Ring 0), Data (S=1), Writable (W=1).
        db 0xA0                 ; Flags: Granularity (G=1), not a 64-bit segment (L=0), Default Op Size (D=1).
        db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; The GDT size. The limit is the number of bytes minus 1.
    dd gdt_start                ; The base address of the GDT.

; Page Tables (identity map 1GB of memory)
; This section sets up the memory mapping that allows the 64-bit kernel to access memory.
align 4096                      ; Align the next variable to a 4KB boundary, as required for page tables.
pml4_table:
    resb 4096                   ; Reserve 4096 bytes for the Page Map Level 4 table.
align 4096
pdpt_table:
    resb 4096                   ; Reserve 4096 bytes for the Page Directory Pointer Table.
align 4096
pd_table:
    resb 4096                   ; Reserve 4096 bytes for the Page Directory.

times 512 - ($ - $$) db 0       ; Pad the entire bootloader to be exactly 512 bytes, as required for a boot sector.