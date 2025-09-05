; This file contains improved assembly functions for console I/O.
; It introduces a global cursor position variable for more robust handling of
; characters, newlines, and screen scrolling.

[bits 64]

; --- Global Variables ---
; Stores the current cursor position as an offset from the start of video memory.
; Each position is 2 bytes (character + color attribute).
section .data
    global cursor_pos
    cursor_pos dq 0xB8000

; --- Function to write a single character to the screen ---
; `put_char_asm(char c)`
; Input: RDI holds the character (per C calling convention).
; This function also handles newlines and screen scrolling.
global put_char_asm
put_char_asm:
    push rbx                ; Save RBX
    push rdx                ; Save RDX

    ; Get current cursor position
    mov rdx, [cursor_pos]

    cmp dil, 0x0a           ; Check for newline character
    je .handle_newline      ; If it's a newline, jump to the handler

    ; Not a newline, so print the character
    mov [rdx], dil          ; Write the character
    mov byte [rdx+1], 0x07  ; Write the color attribute
    add rdx, 2              ; Move cursor to the next character
    jmp .end_char_handling

.handle_newline:
    ; Calculate the end of the current line.
    mov rax, rdx
    mov rbx, 160
    xor rdx, rdx
    div rbx                 ; RAX = row number, RDX = column offset
    inc rax                 ; Move to the next row
    mov rbx, 160
    mul rbx                 ; RAX = start address of the next row
    add rax, 0xB8000        ; Add base address
    mov rdx, rax            ; Update RDX with the new position

.end_char_handling:
    ; Check for screen end and handle scrolling if needed
    cmp rdx, 0xB8FA0        ; 0xB8FA0 is the address after the last character
    jl .update_cursor       ; If not at the end, just update the cursor

    ; If at the end, perform scrolling
    mov rsi, 0xB80A0        ; Start of the second line
    mov rdi, 0xB8000        ; Start of the first line
    mov rcx, 24 * 80        ; Number of characters to move (24 lines * 80 cols)
    rep movsw               ; Move 24 lines up one line

    ; Clear the last line
    mov rdi, 0xB8F00        ; Start of the last line
    mov rcx, 80             ; Number of characters on the last line
    mov ax, 0x0720          ; Space character with color attribute
    rep stosw               ; Write spaces to the last line

    ; Reset cursor to the beginning of the last line
    mov rdx, 0xB8F00

.update_cursor:
    mov [cursor_pos], rdx   ; Save the new cursor position
    pop rdx                 ; Restore RDX
    pop rbx                 ; Restore RBX
    ret

; --- Function to print a null-terminated string ---
; `put_string_asm(const char* str)`
; Input: RDI holds the address of the string.
global put_string_asm
put_string_asm:
    ; Loop through the string and call put_char_asm for each character.
.loop:
    movzx rax, byte [rdi]
    test al, al
    jz .done

    mov rdi, rax            ; Pass character to put_char_asm
    call put_char_asm

    inc rdi                 ; Move to the next character in the original string
    jmp .loop

.done:
    ret

; --- Function to clear the entire screen ---
; `clear_screen_asm()`
global clear_screen_asm
clear_screen_asm:
    push rax
    push rdi
    push rcx

    mov rdi, 0xB8000        ; Start of video memory
    mov rcx, 2000           ; 80 * 25 characters
    mov ax, 0x0720          ; Space character with color attribute (light gray)
    rep stosw               ; Write 'ax' to [rdi], decrement 'rcx', and increment 'rdi'

    mov qword [cursor_pos], 0xB8000 ; Reset cursor position to the top-left
    
    pop rcx
    pop rdi
    pop rax
    ret

