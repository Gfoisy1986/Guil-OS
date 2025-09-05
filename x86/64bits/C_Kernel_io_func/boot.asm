; ---------------------------------------------------------------------------------------------------------------------
; A simple 64-bit kernel that runs in Long Mode.
; It is loaded by the bootloader at 0x10000.
; This kernel provides a simple command-line interface by writing directly to video memory.
; ---------------------------------------------------------------------------------------------------------------------

[bits 64]                       ; Set the assembler to 64-bit mode.

; Define our entry point as a global symbol so the linker can find it.
global main
extern main

; --- Kernel Code ---

; Entry point for the 64-bit kernel.
main:
    ; Set up the stack. A 64-bit environment needs a 64-bit stack pointer.
    mov rsp, 0x90000            ; Set the stack pointer (RSP). A good address in high memory.

    ; Call the main C function.
    call main                   ; Transfer control to our C kernel.
    
    ; Loop indefinitely if main returns.
    jmp $                       ; Loop indefinitely.

; --- 64-bit Printing Subroutine ---
; This routine prints a null-terminated string directly to the VGA video memory buffer.
; It works in 64-bit mode as it does not rely on BIOS interrupts.
; Input: RSI = address of the string to print.
print_string:
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

