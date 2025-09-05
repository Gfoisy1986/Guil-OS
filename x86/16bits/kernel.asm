[org 0x8000]
start:
   
    ; Set up segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFF

    ;; Display kernel banner
    ; mov si, kernel_banner
    ;call print_string
;;.hang:
   ; jmp .hang
    
    call new_line
    call print_prompt

    mov si, kernel_msg
    call print_string


; --- Main Command Loop ---
.main_loop:
    call read_char
    cmp al, 0x08
    je .backspace
    cmp al, 0x0d
    je .process_command

    mov ah, 0x0e
    int 0x10

    movzx bx, byte [buffer_pos]
    mov byte [cmd_buffer + bx], al
    inc byte [buffer_pos]
    jmp .main_loop

.backspace:
    movzx bx, byte [buffer_pos]
    cmp bx, 0
    je .main_loop
    dec byte [buffer_pos]
    mov byte [cmd_buffer + bx - 1], 0

    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .main_loop

.process_command:
    call new_line
    movzx bx, byte [buffer_pos]
    mov byte [cmd_buffer + bx], 0
    call tokenize_input

    mov si, cmd_buffer
    mov di, help_cmd
    call compare_string
    jnc .is_help

    mov di, ls_cmd
    call compare_string
    jnc .is_ls

    mov di, cat_cmd
    call compare_string_space
    jnc .is_cat

    mov di, echo_cmd
    call compare_string_space
    jnc .is_echo

    mov di, clear_cmd
    call compare_string
    jnc .is_clear

    mov si, unknown_cmd
    call print_string
    jmp .reset_prompt

.is_help:
    mov si, help_msg
    call print_string
    jmp .reset_prompt

.is_ls:
    call ls_command
    jmp .reset_prompt

.is_cat:
    mov si, cmd_buffer
    add si, 4
    call cat_command
    jmp .reset_prompt

.is_echo:
    mov si, cmd_buffer
    add si, 5
    call print_string
    call new_line
    jmp .reset_prompt

.is_clear:
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    call new_line
    call print_prompt
    jmp .main_loop

.reset_prompt:
    mov byte [buffer_pos], 0
    call new_line
    call print_prompt
    jmp .main_loop

; --- Constants ---
PROMPT_CHAR          equ '>'
BUFFER_SIZE          equ 128
FILE_TABLE_START     equ 0xA000
FILE_DATA_START      equ 0xC000
DISK_SECTOR_SIZE     equ 512
FAT_TABLE_START      equ 0xB000
MAX_SECTORS          equ 16
EOF_MARKER           equ 0xFF

; --- Variables ---
cmd_buffer           db BUFFER_SIZE dup(0)
buffer_pos           db 0
current_cursor_x     db 0
current_cursor_y     db 1
token_table          dw 10 dup(0)

; --- Subroutines ---
print_prompt:
    mov ah, 0x0e
    mov al, PROMPT_CHAR
    int 0x10
    ret

read_char:
    mov ah, 0x00
    int 0x16
    ret

tokenize_input:
    mov si, cmd_buffer
    mov di, token_table
    xor bx, bx
.next_char:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .skip_space
    mov [di], si
    add di, 2
    inc bx
.skip_token:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    jne .skip_token
    jmp .next_char
.skip_space:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .skip_space
    dec si
    jmp .next_char
.done:
    ret

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    inc byte [current_cursor_x]
    cmp byte [current_cursor_x], 80
    jne .loop
    mov byte [current_cursor_x], 0
    call new_line
    jmp .loop
.done:
    ret

compare_string:
.loop:
    lodsb
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal
    inc di
    jmp .loop
.equal:
    clc
    ret
.not_equal:
    stc
    ret

compare_string_space:
.loop:
    lodsb
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal
    cmp al, ' '
    je .equal
    inc di
    jmp .loop
.equal:
    clc
    ret
.not_equal:
    stc
    ret

compare_string_with_len:
    mov cx, 16
.loop:
    lodsb
    cmp al, [di]
    jne .not_equal
    inc di
    loop .loop
    clc
    ret
.not_equal:
    stc
    ret

new_line:
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    mov al, 0x0a
    int 0x10
    inc byte [current_cursor_y]
    mov byte [current_cursor_x], 0
    ret

ls_command:
    mov si, file_table
    mov cx, 5
.loop:
    mov al, [si]
    cmp al, 0
    je .done_ls
    call new_line
    call print_string
    add si, 16
    loop .loop
.done_ls:
    ret

cat_command:
    push si
    mov di, file_table
    mov cx, 5
.loop:
    push si
    push di
    mov al, [di]
    cmp al, 0
    je .not_found
    call compare_string_with_len
    jc .next_file
    pop di
    pop si
    call new_line
    mov bl, [di+8]
    call read_file_fat
    mov si, FILE_DATA_START
    call print_string
    call new_line
    ret
.next_file:
    pop di
    pop si
    add di, 16
    loop .loop
.not_found:
    pop di
    pop si
    mov si, file_not_found_msg
    call print_string
    call new_line
    ret

read_file_fat:
    mov si, FILE_DATA_START
.read_loop:
    mov ah, 0x02
    mov al, 1
    mov ch, 0x00
    mov cl, bl
    mov dh, 0x00
    mov dl, 0x00
    mov bx, si
    int 0x13
    jc .error
    add si, DISK_SECTOR_SIZE
    mov di, FAT_TABLE_START
    add di, bx
    mov bl, [di]
    cmp bl, EOF_MARKER
    je .done
    jmp .read_loop
.error:
    mov si, disk_error_msg
    call print_string
.done:
    ret





; --- Data ---
kernel_banner:        db 'FoisyOS Kernel Loaded. Type "help" for commands.', 0
help_cmd:             db 'help', 0
ls_cmd:               db 'ls', 0
cat_cmd:              db 'cat', 0
echo_cmd:             db 'echo', 0
clear_cmd:            db 'clear', 0
unknown_cmd:          db 'Unknown command!', 0x0d, 0x0a, 0
help_msg:             db 'Available commands: help, ls, cat <file>, echo <text>, clear', 0x0d, 0x0a, 0
file_not_found_msg:   db 'File not found.', 0x0d, 0x0a, 0
disk_error_msg:       db 'Disk read error!', 0x0d, 0x0a, 0
kernel_msg:           db 'Kernel started!', 0
; --- File Table ---
file_table:
    db 'README.md', 0,0,0,0,0,0,0, 2, 0
    db 'MESSAGE.TXT', 0,0,0,0,0,0, 3, 0
    db 0 ; End of file table marker
    
; --- FAT Table ---
fat_table:
    db 0xFF, 0xFF, 0x03, 0x04, 0xFF
    times MAX_SECTORS - 5 db 0

; --- File Data ---
times 2*DISK_SECTOR_SIZE - ($ - $$) db 0
readme_content:
    db 'This is a README file. You can see me with the `cat` command!', 0

times 3*DISK_SECTOR_SIZE - ($ - $$) db 0
message_content:
    db 'This is a test message. Welcome to the terminal!', 0

; --- Final Padding ---
end_of_kernel_content:
times ((end_of_kernel_content - $$ + DISK_SECTOR_SIZE - 1) / DISK_SECTOR_SIZE) * DISK_SECTOR_SIZE - (end_of_kernel_content - $$) db 0
