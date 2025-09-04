; This file contains assembly functions that can be called from C.
; We use the C calling convention here.
; The function name must be prefixed with an underscore for C compatibility in older compilers, but we'll use a direct name to be safe with modern compilers.

[bits 64]

; --- Function to print a null-terminated string to the screen ---
; `put_string_asm(const char* str)`
; Input: RDI holds the address of the string (per C calling convention).
put_string_asm:
    mov rdx, 0xB8000            ; RDX will hold the current video memory address.
.loop:
    movzx rax, byte [rdi]       ; Read a byte from the string into AL, zero-extend to RAX.
    test al, al                 ; Check for null terminator.
    jz .done                    ; If null, we're done.

    cmp al, 0x0a                ; Check for a newline character (LF).
    je .newline

    mov [rdx], al               ; Write the character to video memory.
    mov byte [rdx+1], 0x07      ; Write the color attribute.
    add rdx, 2                  ; Move to the next character position.

.next_char:
    inc rdi                     ; Move to the next character in the string.
    jmp .loop                   ; Loop back.

.newline:
    ; Handle newline: move cursor to the next line.
    ; Divide current position by 160 (2 bytes * 80 columns) to get current row.
    ; Multiply (current_row + 1) by 160 to get the start of the next row.
    mov rax, rdx
    mov rbx, 160
    xor rdx, rdx
    div rbx                     ; RAX = RAX / RBX, RDX = RAX % RBX

    inc rax                     ; Move to the next row.
    mul rbx                     ; RAX = RAX * RBX

    mov rdx, rax                ; Update RDX with the new position.
    jmp .next_char              ; Continue to the next character in the string.

.done:
    ret                         ; Return from the function.
