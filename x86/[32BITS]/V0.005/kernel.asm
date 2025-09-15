[org 0x8000]            ; Kernel load address

[BITS 16]
global protected_mode

start:



    ; Print initial messages
    mov si, message
    call print
    call newline
    call newline

    mov si, message2
    call print

    ; Switch to 32-bit protected mode

    lgdt [gdt_descriptor]   ; Load Global Descriptor Table
    cli                     ; Disable interrupts

    mov eax, cr0
    or eax, 1               ; Set PE bit (bit 0) to enable protected mode
    mov cr0, eax

    jmp CODE_SEG:protected_mode  ; Far jump to flush pipeline




[BITS 32]
protected_mode:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    call Clear_screen

.start_shell:
    mov esi, msg_pm
    call print_pm

    call clear_input_buffer       ; 🧼 Clear buffer BEFORE reading
    call read_input_pm            ; Read user input
    call parse_command            ; Parse and execute
    jmp .start_shell              ; Loop back






parse_command:
    mov si, input_buffer

    ; Check for "-help"
    mov di, cmd_help_inline
    push si
    call strcmp
    pop si
    cmp al, 1
    je .handler_help

    ; Check for "-ls"
    mov di, cmd_ls_inline
    push si
    call strcmp
    pop si
    cmp al, 1
    je .handler_ls

    ; Unknown command
    mov esi, msg_unknown
    call print_pm
    jmp .advance_cursor

.handler_help:
    mov esi, msg_help
    call print_pm
    jmp .advance_cursor

.handler_ls:
    mov esi, msg_ls
    call print_pm
    jmp .advance_cursor

.advance_cursor:
    call clear_input_buffer
    ; Move to next line
    inc byte [cursor_row]
    mov byte [cursor_col], 0

    ; Reinitialize input buffer


    ; Optionally reset other state variables here
    ; e.g., command flags, temporary registers, etc.

    ; Update cursor position
    call set_cursor_pm


    ret





strcmp:
.next_char:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    je .check_end
    inc si
    inc di
    jmp .next_char

.check_end:
    mov al, [si]
    test al, al
    jne .not_equal
    mov al, 1
    ret

.not_equal:
    mov al, 0
    ret

scancode_to_ascii:
    ; AL = scancode
    cmp al, 0x39
    ja .unknown              ; Only handle scancodes up to 0x39

    movzx ebx, al            ; Index into table
    mov al, [scancode_table + ebx]
    ret

.unknown:
    mov al, '?'
    ret

clear_input_buffer:
    mov di, input_buffer
    mov cx, 128
    mov al, 0
    rep stosb
    xor bx, bx
    ret


read_input_pm:
    mov si, input_buffer
    xor bx, bx                      ; character count

.read_key:
    in al, 0x64                     ; check keyboard status
    test al, 1
    jz .read_key                    ; wait for key

    in al, 0x60                     ; read scancode
    test al, 0x80
    jnz .read_key                   ; skip key releases

    cmp al, 0x1C                    ; Enter key
    je .done

    cmp al, 0x0E                    ; Backspace
    je .backspace

    ; Convert scancode to ASCII
    call scancode_to_ascii         ; AL = character
    mov [si], al                   ; store in buffer
    inc si
    inc bx

    ; Prepare AX for printing
    mov ah, 0x07                   ; attribute: light gray on black
    movzx eax, al                  ; clear upper bits
    or ax, 0x0700                  ; combine with attribute

    ; Calculate screen position
    mov edi, 0xB8000
    movzx ecx, byte [cursor_row]
    imul ecx, 80
    movzx edx, byte [cursor_col]
    add ecx, edx
    shl ecx, 1
    add edi, ecx

    stosw                          ; write character to screen

    inc byte [cursor_col]
    call set_cursor_pm
    jmp .read_key

.backspace:
    cmp bx, 0
    je .read_key                   ; nothing to delete

    dec bx
    dec si

    cmp byte [cursor_col], 0
    je .read_key
    dec byte [cursor_col]

    ; Calculate screen position
    mov edi, 0xB8000
    movzx ecx, byte [cursor_row]
    imul ecx, 80
    movzx edx, byte [cursor_col]
    add ecx, edx
    shl ecx, 1
    add edi, ecx

    mov ax, 0x0720                 ; space character with attribute
    stosw                          ; erase character

    call set_cursor_pm
    jmp .read_key

.done:

    mov byte [si], 0     ; Null-terminate input
    ret



set_cursor_pm:
    movzx eax, byte [cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx            ; EAX = row * 80 + col

    mov bx, ax              ; BX = cursor position

    ; Send high byte
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh              ; High byte of BX
    out dx, al

    ; Send low byte
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl              ; Low byte of BX
    out dx, al
    ret


Clear_screen:
 ; Clear screen only once? Or move this to init
    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw
    ret
; --- Protected Mode Print Routine ---
print_pm:

    ; ESI should point to the string to print
    ; Calculate EDI from cursor position
    movzx eax, byte [cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, 0xB8000
    add edi, eax

    mov ah, 0x07              ; Attribute: light gray on black
    call print_string_pm      ; Print string from ESI to EDI

    ; Update cursor_col based on printed length
    mov ecx, esi
    call string_length
    add byte [cursor_col], cl
    call set_cursor_pm
    ret

string_length:
    ; Input: ESI = pointer to string
    ; Output: CL = length of string
    push esi
    xor ecx, ecx
.next_char:
    lodsb
    test al, al
    jz .done
    inc ecx
    jmp .next_char
.done:
    mov cl, cl
    pop esi
    ret


; ----------------------------------------
; Subroutine: print_string_pm
; Prints string at [ESI] to [EDI] with attribute in AH
; ----------------------------------------
print_string_pm:
    push esi
.next_char:
    lodsb                         ; Load byte from [ESI] into AL
    test al, al                   ; Check for null terminator
    jz .done

    cmp al, 0x0A                  ; Check for newline
    je .newline

    mov ah, 0x07                  ; Attribute: light gray on black
    mov [edi], ax                 ; Write character and attribute
    add edi, 2                    ; Advance EDI by 2 bytes (char + attr)
    inc byte [cursor_col]         ; Advance column
    jmp .next_char

.newline:
    inc byte [cursor_row]         ; Move to next row
    mov byte [cursor_col], 0      ; Reset column to start of line

    ; Recalculate EDI based on new cursor position
    movzx eax, byte [cursor_row]
    imul eax, 80                  ; 80 characters per row
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1                    ; Each character cell is 2 bytes
    mov edi, 0xB8000
    add edi, eax

    jmp .next_char

.done:
    pop esi
    ret




; ----------------------------------------
; Data section (example)
; ----------------------------------------
msg_pm     db "$Guil-OS:> ", 0

cursor_row db 0
cursor_col db 0
input_buffer times 512 db 0
msg_help:
db 0x0A
db "  cmd:  -help <list command>", 0x0A
db "  cmd:  -ls <list file>", 0x0A
db 0
msg_ls:
db 0x0A
db "  bootloader.bin", 0x0A
db "  kernel.bin", 0x0A
db 0
msg_unknown db " unknow command! ", 0
cmd_help_inline db "-help", 0
cmd_ls_inline   db "-ls", 0

scancode_table:
    db 0    ; 0x00
    db 0    ; 0x01 - ESC
    db "1"  ; 0x02
    db "2"  ; 0x03
    db "3"  ; 0x04
    db "4"  ; 0x05
    db "5"  ; 0x06
    db "6"  ; 0x07
    db "7"  ; 0x08
    db "8"  ; 0x09
    db "9"  ; 0x0A
    db "0"  ; 0x0B
    db "-"  ; 0x0C
    db "="  ; 0x0D
    db 0    ; 0x0E - Backspace
    db 0    ; 0x0F - Tab
    db "q"  ; 0x10
    db "w"  ; 0x11
    db "e"  ; 0x12
    db "r"  ; 0x13
    db "t"  ; 0x14
    db "y"  ; 0x15
    db "u"  ; 0x16
    db "i"  ; 0x17
    db "o"  ; 0x18
    db "p"  ; 0x19
    db "["  ; 0x1A
    db "]"  ; 0x1B
    db 0x0D ; 0x1C - Enter
    db 0    ; 0x1D - Ctrl
    db "a"  ; 0x1E
    db "s"  ; 0x1F
    db "d"  ; 0x20
    db "f"  ; 0x21
    db "g"  ; 0x22
    db "h"  ; 0x23
    db "j"  ; 0x24
    db "k"  ; 0x25
    db "l"  ; 0x26
    db ";"  ; 0x27
    db "'"  ; 0x28
    db "`"  ; 0x29
    db 0    ; 0x2A - Left Shift
    db "\"  ; 0x2B
    db "z"  ; 0x2C
    db "x"  ; 0x2D
    db "c"  ; 0x2E
    db "v"  ; 0x2F
    db "b"  ; 0x30
    db "n"  ; 0x31
    db "m"  ; 0x32
    db ","  ; 0x33
    db "."  ; 0x34
    db "/"  ; 0x35
    db 0    ; 0x36 - Right Shift
    db "*"  ; 0x37 - Keypad *
    db 0    ; 0x38 - Alt
    db " "  ; 0x39 - Space



[BITS 16]
; --- Global Descriptor Table ---

gdt_start:

gdt_null:                  ; Null descriptor (required)
    dd 0x00000000
    dd 0x00000000

gdt_code:                  ; Code segment descriptor
    dw 0xFFFF              ; Limit low (16 bits)
    dw 0x0000              ; Base low (16 bits)
    db 0x00                ; Base middle (8 bits)
    db 0x9A                ; Access byte: present, ring 0, executable, readable
    db 0xCF                ; Flags: granularity, 32-bit segment
    db 0x00                ; Base high (8 bits)

gdt_data:                  ; Data segment descriptor
    dw 0xFFFF              ; Limit low
    dw 0x0000              ; Base low
    db 0x00                ; Base middle
    db 0x92                ; Access byte: present, ring 0, writable
    db 0xCF                ; Flags: granularity, 32-bit
    db 0x00                ; Base high

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Size of GDT (limit)
    dd gdt_start                 ; Linear base address of GDT



; --- Real Mode Print Routine ---
newline:
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

print:
    mov ah, 0x0E
.next_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .next_char
.done:
    ret

; --- Messages ---
message  db 'Kernel loaded...', 0
message2 db 'Kernel up n running!...', 0
;msg_pm db "Hello from Protected Mode!", 0x0A, "Second line here.", 0

; --- Segment Selectors ---
CODE_SEG equ 0x08
DATA_SEG equ 0x10

row dw 0        ; Current row (0–24)
col dw 0        ; Current column (0–79)

; --- Padding to 512 bytes ---
times 4096 - ($ - $$) db 0

