; ---------------------------------------------------------------------------------------------------------------------
; A simple 64-bit kernel to run on a x86_64 CPU.
; It prints a simple message to the screen without BIOS calls.
; ---------------------------------------------------------------------------------------------------------------------

[bits 64]                       ; Explicitly declare that we are using 64-bit instructions.
[extern kernel_main]            ; In a real C kernel, this would be the C entry point. It's not used here,
                                ; but is good practice for a future C kernel.

; --- Constants ---
VIDEO_MEM_ADDR equ 0xB8000      ; The physical address of the text mode video memory.
                                ; This is where the kernel will write characters to display them.

; --- Entry Point ---
_start:
    mov rdi, 0              ; Clear the RDI register. This is often used for a destination pointer
                            ; but here it's simply a good habit to initialize registers.
    mov rbx, 0              ; Clear the RBX register.
    mov rax, 0              ; Clear the RAX register.
    
    call print_string       ; Call the 'print_string' subroutine. This is the only action the
                            ; kernel performs. The 'call' instruction pushes the address of the
                            ; next instruction onto the stack and jumps to the subroutine's address.
    
    cli                     ; Disable interrupts. This is critical in a bare-metal kernel to
                            ; prevent the CPU from responding to external signals, which could
                            ; cause unexpected behavior.
    hlt                     ; Halt the CPU. Puts the processor into a low-power state and
                            ; effectively stops execution. The system is now idle.

; --- Function to print a string to video memory ---
; Takes a null-terminated string as the first argument in rdi.
print_string:
    push rdi                ; Save the value of RDI on the stack. This is a standard
                            ; procedure for subroutines that modify a caller's register.
    push rbx                ; Save the value of RBX on the stack.
    
    mov rbx, VIDEO_MEM_ADDR ; Move the video memory address into the RBX register.
                            ; We will use RBX as a pointer to the video memory buffer.
    
.loop:
    mov al, byte [rdi]      ; Move a single byte (a character) from the memory location pointed
                            ; to by RDI into the AL register (the lower 8 bits of RAX).
    cmp al, 0               ; Compare the character in AL to 0 (the null terminator).
    je .done                ; If it's a null character, jump to the '.done' label to exit the loop.
    
    mov byte [rbx], al      ; Write the character from AL into the memory location pointed
                            ; to by RBX (the video memory).
    add rbx, 2              ; Increment the RBX pointer by 2. Each character on the screen
                            ; takes up two bytes in video memory: one for the ASCII value and
                            ; one for the color attribute.
    inc rdi                 ; Increment the RDI pointer by 1. We've processed one character,
                            ; so move to the next one in the string.
    jmp .loop               ; Jump back to the beginning of the loop to process the next character.
    
.done:
    pop rbx                 ; Restore the original value of RBX from the stack.
    pop rdi                 ; Restore the original value of RDI from the stack.
    ret                     ; Return from the subroutine. This pops the return address off the
                            ; stack and jumps back to the caller (in this case, the `_start` label).

; --- Data Section ---
message db 'Hello, 64-bit World!', 0 ; Define a string of bytes (db = Define Byte). The string is
                                    ; terminated with a null byte (0).

; Note: This kernel is a simple demonstration of the boot process.
; It lacks a terminal, filesystem, or any advanced features.