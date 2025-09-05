; ---------------------------------------------------------------------------------------------------------------------
; This is the initial boot sector, loaded at memory address 0x7c00.
; Its job is to set up the environment and load the kernel.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x7c00] 
; This directive tells the assembler that the code will be loaded at memory address 0x7c00.
; The BIOS (Basic Input/Output System) loads the first sector of a bootable disk to this address.

; --- Constants and Data ---
KERNEL_SECTOR_COUNT equ 10
; Defines a constant, KERNEL_SECTOR_COUNT, which represents the number of disk sectors the kernel occupies.
; This is a crucial value for the BIOS disk read function.

KERNEL_LOAD_ADDRESS equ 0x8000 
; Defines a constant, KERNEL_LOAD_ADDRESS, which is the memory address where the kernel will be loaded.
; 0x8000 is a common choice, as it's outside the memory used by the boot sector itself (0x7c00).

; --- Main Routine ---
main:
; Set up the segment registers
  mov ax, 0x07c0
; Moves the hexadecimal value 0x07c0 into the AX register.
; This value, when shifted left by four bits, becomes 0x7c00, which is the base address of the boot sector.

  mov ds, ax
; Moves the value from AX into the DS (Data Segment) register.
; DS is used to point to the base of the data segment, so setting it to 0x07c0 makes it possible to
; access data (like the messages) relative to the boot sector's base address.

  mov es, ax
; Moves the value from AX into the ES (Extra Segment) register.
; ES is another general-purpose segment register, often used for destination operations.
; Setting it to the same value as DS is a simple way to ensure a consistent addressing scheme.

; Set up the stack
  mov ax, 0x9000
; Moves the hexadecimal value 0x9000 into the AX register.
; This value will be the base address for the stack. The stack grows downwards in memory.

  mov ss, ax
; Moves the value from AX into the SS (Stack Segment) register.
; SS points to the base of the stack.

  mov sp, 0xffff
; Moves the hexadecimal value 0xffff (the largest 16-bit value) into the SP (Stack Pointer) register.
; SP points to the top of the stack. Setting it to 0xffff when the SS is 0x9000
; places the top of the stack at address 0x9ffff. This gives the stack a full 64KB of space.

; Clear the screen
  mov ah, 0x00
; Sets the AH register to 0x00, which selects the "Set Video Mode" service of the BIOS interrupt 0x10.

  mov al, 0x03 
; Sets the AL register to 0x03, which specifies the video mode to be set.
; 0x03 corresponds to an 80x25 color text mode, a standard for simple text-based applications.

  int 0x10
; Calls BIOS interrupt 0x10, which handles video services.
; With AH=0x00 and AL=0x03, it clears the screen and sets the specified text mode.

  ; Print a welcome message
  mov si, welcome_msg
; Moves the address of the welcome_msg string into the SI (Source Index) register.
; SI is used as a pointer to the string data.

  call print_string
; Calls the `print_string` subroutine.
; This transfers control to the `print_string` label, which will print the string located at the address in SI.

 ; Print a loading message
  mov si, loading_msg
; Moves the address of the loading_msg string into the SI register.

 call print_string
; Calls the `print_string` subroutine again to display the loading message.

; Load the kernel from the disk
; BIOS interrupt 0x13, service 0x02
  mov ah, 0x02 
; Sets the AH register to 0x02, which selects the "Read Sectors from Disk" service of the BIOS interrupt 0x13.

  mov al, KERNEL_SECTOR_COUNT 
; Sets the AL register to the number of sectors to read, which is defined by the constant KERNEL_SECTOR_COUNT (10).

   mov ch, 0x00 
; Sets the CH register to 0x00, specifying the cylinder (or track) number to read from. The kernel is assumed to be on the first cylinder.

   mov cl, 0x02 
; Sets the CL register to 0x02, specifying the starting sector number on the cylinder.
; Sector numbers on a disk start from 1, so sector 2 corresponds to the second sector on the track.
; The first sector (sector 1) is the boot sector itself, so the kernel starts immediately after it.

  mov dh, 0x00 
; Sets the DH register to 0x00, specifying the head number. This is for the first head.

; Use DL as set by BIOS — no need to overwrite
; DL already contains the boot drive number

;  mov dl, 0x00 
; Sets the DL register to 0x00, specifying the drive number. 0x00 is for the first floppy drive (A:).

  mov bx, KERNEL_LOAD_ADDRESS 
; Moves the address where the data will be loaded into the BX register.
; This serves as the memory buffer for the data read from the disk.

  int 0x13
; Calls BIOS interrupt 0x13, which handles low-level disk I/O.
; This call executes the disk read operation using the parameters set in the registers.

; Check for errors
  jc disk_error
; Jumps to the `disk_error` label if the carry flag (CF) is set.
; The BIOS interrupt 0x13 sets the carry flag if an error occurred during the disk read operation.

 ; Jump to the loaded kernel
  jmp KERNEL_LOAD_ADDRESS
; Jumps unconditionally to the address where the kernel was loaded (0x8000).
; This transfers control from the boot sector to the kernel, which will then begin its execution.

; --- Subroutines ---
; print_string: Prints a null-terminated string at [si]
print_string:
 mov ah, 0x0e 
; Sets the AH register to 0x0e, which is the "Teletype Output" service of the BIOS interrupt 0x10.
; This service prints a character to the screen and automatically advances the cursor.

.loop:
 lodsb 
; Loads a byte from the memory address pointed to by DS:SI into the AL register and then increments SI.
; This is a powerful instruction for iterating through strings.

  or al, al 
; Performs a bitwise OR operation of the AL register with itself.
; This is a common and efficient way to check if the value in AL is zero, as the result is zero only if AL is zero.

  jz .done 
; Jumps to the `.done` label if the zero flag (ZF) is set, which happens if the previous `or al, al`
; operation resulted in zero. This indicates the end of the null-terminated string.

  int 0x10 
; Calls BIOS interrupt 0x10 to print the character currently in the AL register.

  jmp .loop
; Jumps back to the beginning of the `.loop` to process the next character.

.done:
  ret
; Returns from the subroutine. This pops the return address off the stack and transfers control back to the instruction after the `call print_string`.


; --- Messages ---
welcome_msg:     db 'Welcome to FoisyOS!', 0
loading_msg:     db 'Loading kernel...', 0
disk_error:      db 'Disk read error!', 0



; --- Padding and Boot Signature ---
times 510-($-$$) db 0 
; This is a very important part of the boot sector.
; `$ - $$` calculates the current position relative to the start of the section.
; `510-($-$$)` calculates how many bytes are left to fill before reaching the 510th byte.
; This command fills the remaining space with zeros (`db 0`) to pad the boot sector to a size of 512 bytes.

dw 0xAA55