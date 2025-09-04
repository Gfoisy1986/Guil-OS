; ---------------------------------------------------------------------------------------------------------------------
; This is the main kernel, loaded by the bootloader at 0x8000.
; It contains the terminal, command interpreter, and file system logic.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x8000]

; --- Constants and Data ---
PROMPT_CHAR         equ '>'
BUFFER_SIZE         equ 128
FILE_TABLE_START    equ 0xA000
FILE_DATA_START     equ 0xC000
DISK_SECTOR_SIZE    equ 512

; --- Variables ---
cmd_buffer          db BUFFER_SIZE dup(0)
buffer_pos          db 0
current_cursor_x    db 0
current_cursor_y    db 1 ; Start on the second line

; --- Main Routine ---
start:
    ; Set up the command loop
    call new_line
    call print_prompt
    
.main_loop:
    ; Read a character from the keyboard
    call read_char

    ; Check if it's a backspace (0x08)
    cmp al, 0x08
    je .backspace

    ; Check if it's the Enter key (0x0d)
    cmp al, 0x0d
    je .process_command

    ; Otherwise, echo the character and store it in the buffer
    mov ah, 0x0e
    int 0x10
    movzx ebx, byte [buffer_pos]
    mov byte [cmd_buffer + ebx], al
    inc byte [buffer_pos]
    jmp .main_loop

.backspace:
    movzx ebx, byte [buffer_pos]
    cmp ebx, 0
    je .main_loop
    dec byte [buffer_pos]
    mov byte [cmd_buffer + ebx - 1], 0
    mov ah, 0x0e
    mov al, 0x08 ; Backspace
    int 0x10
    mov ah, 0x0e
    mov al, ' '
    int 0x10
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    jmp .main_loop

.process_command:
    call new_line
    movzx ebx, byte [buffer_pos]
    mov byte [cmd_buffer + ebx], 0 ; Null-terminate the string
    
    ; Compare command with "help"
    mov si, cmd_buffer
    mov di, help_cmd
    call compare_string
    jnc .is_help
    
    ; Compare command with "ls"
    mov si, cmd_buffer
    mov di, ls_cmd
    call compare_string
    jnc .is_ls

    ; Compare command with "cat"
    mov si, cmd_buffer
    mov di, cat_cmd
    call compare_string_space
    jnc .is_cat
    
    ; Compare command with "echo"
    mov si, cmd_buffer
    mov di, echo_cmd
    call compare_string_space
    jnc .is_echo
    
    ; If no match, print "unknown command"
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
    ; Get filename argument
    mov si, cmd_buffer
    add si, 4 ; Skip "cat "
    call cat_command
    jmp .reset_prompt

.is_echo:
    ; Get text argument
    mov si, cmd_buffer
    add si, 5 ; Skip "echo "
    call echo_command
    jmp .reset_prompt
    
.reset_prompt:
    mov byte [buffer_pos], 0 ; Reset buffer position
    call new_line
    call print_prompt
    jmp .main_loop

; --- Subroutines ---

; print_string: Prints a null-terminated string at [si]
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

; new_line: Prints a newline and carriage return
new_line:
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    mov al, 0x0a
    int 0x10
    inc byte [current_cursor_y]
    mov byte [current_cursor_x], 0
    ret

; print_prompt: Prints the terminal prompt
print_prompt:
    mov ah, 0x0e
    mov al, PROMPT_CHAR
    int 0x10
    mov al, ' '
    int 0x10
    mov byte [current_cursor_x], 2
    ret
    
; read_char: Reads a single character and returns it in AL
read_char:
    mov ah, 0x00
    int 0x16
    ret

; compare_string: Compares two strings. Returns carry clear if match, set if no match.
compare_string:
    push si
    push di
    
.loop:
    mov al, [si]
    mov bl, [di]
    or al, al
    jz .done
    cmp al, bl
    jne .mismatch
    inc si
    inc di
    jmp .loop
    
.mismatch:
    stc ; Set carry
    jmp .exit
    
.done:
    cmp byte [di], 0
    jne .mismatch
    clc ; Clear carry for match
    
.exit:
    pop di
    pop si
    ret

; compare_string_space: Compares a string followed by a space
compare_string_space:
    push si
    push di
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .mismatch
    inc si
    inc di
    cmp byte [di], 0
    je .check_space
    jmp .loop
.check_space:
    cmp byte [si], ' '
    jne .mismatch
    clc ; Clear carry for match
    jmp .exit
.mismatch:
    stc ; Set carry
.exit:
    pop di
    pop si
    ret

; --- Command Handlers ---
; ls_command: Lists files in the file table
ls_command:
    mov si, file_table ; Pointer to file table
    mov cx, 5          ; Max number of files
    
.loop:
    mov al, [si]
    cmp al, 0
    je .done_ls ; Reached end of table
    
    call new_line
    call print_string
    
    add si, 16 ; Move to next entry
    loop .loop
    
.done_ls:
    ret

; cat_command: Displays contents of a file
cat_command:
    push si
    mov di, file_table
    mov cx, 5 ; Max files to check
    
.loop:
    push si
    push di
    mov al, [di]
    cmp al, 0
    je .not_found ; No more files
    call compare_string_with_len
    jc .next_file
    
    ; Found the file, now read its data
    pop di
    pop si
    call new_line
    mov bl, [di+8] ; Get starting sector
    mov bh, 0x00   ; Get sector count
    mov cl, [di+9] ; Number of sectors to read
    mov bx, FILE_DATA_START ; Buffer to load data into
    
    ; Read from disk
    mov ah, 0x02
    mov al, cl
    mov ch, 0x00
    mov cl, bl
    mov dh, 0x00
    mov dl, 0x00
    int 0x13
    
    ; Print the file contents
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

; echo_command: Prints the rest of the string
echo_command:
    call print_string
    ret

; compare_string_with_len: Compares a string at [si] to a fixed-length string at [di] (16 bytes)
compare_string_with_len:
    push si
    push di
    push cx
    mov cx, 16
.loop:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .mismatch
    inc si
    inc di
    cmp byte [si-1], 0 ; If we reach the end of the input string...
    je .check_zero_pad ; ...check the file table string padding
    loop .loop

.check_zero_pad:
    cmp byte [di], 0
    jne .mismatch ; File table name has more characters, so mismatch
    clc
    jmp .exit
.mismatch:
    stc
.exit:
    pop cx
    pop di
    pop si
    ret

; --- Data and Messages ---
help_cmd:           db 'help', 0
ls_cmd:             db 'ls', 0
cat_cmd:            db 'cat', 0
echo_cmd:           db 'echo', 0
unknown_cmd:        db 'Unknown command!', 0x0d, 0x0a, 0x00
file_not_found_msg: db 'File not found.', 0x00
help_msg:           db 'Available commands: ', 0x0d, 0x0a, ' ls - List files', 0x0d, 0x0a, ' cat <filename> - View file contents', 0x0d, 0x0a, ' echo <text> - Echo text to screen', 0x0d, 0x0a, 0x00

; --- File System ---
; File table (16 bytes per entry)
; [16-byte filename] [1-byte start sector] [1-byte size in sectors]
file_table:
    db 'README.md', 0,0,0,0,0,0,0, 2, 1 ; README.md, starting at sector 2, size 1
    db 'MESSAGE.TXT', 0,0,0,0,0,0, 3, 1 ; MESSAGE.TXT, starting at sector 3, size 1
    db 0                ; End of file table marker
    
; File data (starts at sector 2)
times 2*DISK_SECTOR_SIZE - ($ - $$) db 0 ; Pad to sector 2

; README.md file content (at sector 2)
readme_content:
    db 'This is a README file. You can see me with the `cat` command!', 0
times 3*DISK_SECTOR_SIZE - ($ - $$) db 0 ; Pad to sector 3

; MESSAGE.TXT file content (at sector 3)
message_content:
    db 'This is a test message. Welcome to the terminal!', 0

; --- Final Padding ---
; This is a more dynamic way to calculate the required padding.
end_of_kernel_content:
    ; This label marks the end of all the code and hardcoded file content.
    ; We can now use it to calculate the required padding to make the binary a multiple of sectors.
times ( (end_of_kernel_content - $$ + DISK_SECTOR_SIZE - 1) / DISK_SECTOR_SIZE ) * DISK_SECTOR_SIZE - (end_of_kernel_content - $$) db 0

; Note: The above calculation is more robust than simply padding to a fixed size.
; It ensures the total size of the binary is a multiple of the sector size,
; no matter how much content you add or remove.

; --- Static Size and Padding ---
; We can also pad to a specific size, e.g., to ensure the kernel is exactly 10 sectors long.
; This is useful for fixed-size images.
; times (10*DISK_SECTOR_SIZE) - ($ - $$) db 0