; ---------------------------------------------------------------------------------------------------------------------
; A simple 64-bit kernel that runs in Long Mode.
; It is loaded by the bootloader at 0x10000.
; This kernel provides a simple command-line interface by writing directly to video memory.
; ---------------------------------------------------------------------------------------------------------------------

[bits 64]                       ; Set the assembler to 64-bit mode.
[org 0x10000]                   ; Set the origin to the address where the kernel is loaded by the bootloader.

; --- Kernel Code ---

; Entry point for the 64-bit kernel.
kernel_entry_64:
    ; Set up the stack. A 64-bit environment needs a 64-bit stack pointer.
    mov rsp, 0x90000            ; Set the stack pointer (RSP). A good address in high memory.

    ; Print a welcome message.
    mov rsi, welcome_msg        ; Load the address of the welcome message string into RSI.
    call print_string_64        ; Call the 64-bit printing routine.
    
    ; Display the prompt and start the main loop.
    mov rsi, prompt             ; Load the prompt string.
    call print_string_64
    
    ; Main command loop.
    main_loop:
        ; This is a placeholder for the actual command-line interface.
        ; The kernel would wait for user input, parse it, and execute commands here.
        jmp $                       ; Loop indefinitely.

; --- 64-bit Printing Subroutine ---
; This routine prints a null-terminated string directly to the VGA video memory buffer.
; It works in 64-bit mode as it does not rely on BIOS interrupts.
; Input: RSI = address of the string to print.
print_string_64:
    ; We are printing to the video memory buffer at 0xB8000.
    ; Each character is 2 bytes: ASCII character (1 byte) and color attribute (1 byte).
    ; Default color: light gray on black (0x07).
    mov rdi, 0xB8000            ; Load the video memory address into RDI (Destination Index).
    
.loop:
    lodsb                       ; Load a byte from the string (pointed to by RSI) into AL and increment RSI.
    test al, al                 ; Check if the character is the null terminator.
    jz .done                    ; If it is, we're done.
    
    ; Write the character to video memory.
    mov [rdi], al               ; Store the character in AL at the current video memory address.
    
    ; Write the color attribute.
    mov al, 0x07                ; The color attribute (light gray on black).
    mov [rdi+1], al             ; Store the color byte at the next address.
    
    add rdi, 2                  ; Move to the next character position in video memory (2 bytes per character).
    jmp .loop                   ; Loop to the next character.
    
.done:
    ret                         ; Return from the subroutine.
    
; --- Data Section ---
welcome_msg:
    db 'Welcome to my 64-bit Kernel!', 0
prompt:
    db '>', 0

; --- Hardcoded File System ---
; This section contains the files to be displayed by the kernel's `cat` command.
; This is a simple, static file system.
file_table_start:
    ; file 1: 'README.md'
    db 'README.MD', 0, 0, 0, 0, 0, 0, 2, 1
    
    ; file 2: 'MESSAGE.TXT'
    db 'MESSAGE.TXT', 0, 0, 0, 0, 0, 3, 1
file_table_end:

; Content of README.md
times 2*512 - ($ - $$) db 0         ; Pad to sector 2
readme_content:
    db 'This is a README file for the kernel.', 0x0d, 0x0a
    db 'It explains what the kernel does.', 0x0d, 0x0a
    db 'It is a hardcoded file in the kernel binary.', 0

; Content of MESSAGE.TXT
times 3*512 - ($ - $$) db 0         ; Pad to sector 3
message_content:
    db 'This is a simple test message.', 0x0d, 0x0a
    db 'Hello, World!', 0

; --- Padding to fill up the remaining space of the kernel binary ---
; This ensures the kernel binary has a specific, fixed size, which is critical
; for the bootloader to load it correctly.
end_of_kernel_content:
times 10*512 - ($ - $$) db 0
