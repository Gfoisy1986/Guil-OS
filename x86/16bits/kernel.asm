[org 0x8000]
; This directive sets the origin address for the code to 0x8000.
; This is the same address the bootloader uses to load the kernel into memory.

; --- Constants and Data ---
PROMPT_CHAR         equ '>'
; Defines the character used for the command prompt.

BUFFER_SIZE         equ 128
; Sets the maximum size for the command input buffer.

FILE_TABLE_START    equ 0xA000
; This constant defines the starting memory address for the file system's file table.

FILE_DATA_START     equ 0xC000
; This constant defines the memory address where file data will be loaded from the disk.

DISK_SECTOR_SIZE    equ 512
; The standard size of a disk sector in bytes.

; --- Variables ---
cmd_buffer          db BUFFER_SIZE dup(0)
; Defines a buffer in memory to store user input. It's initialized with zeros.

buffer_pos          db 0
; A counter to keep track of the current position within the `cmd_buffer`.

current_cursor_x    db 0
current_cursor_y    db 1 ; Start on the second line
; These variables store the current cursor position on the screen, used for text output.


start:
    ; Set up the command loop
    call new_line
; Calls the `new_line` subroutine to move the cursor to the start of a new line.

    call print_prompt
; Calls the `print_prompt` subroutine to display the command prompt character.
    
.main_loop:
    ; Read a character from the keyboard
    call read_char
; Calls the `read_char` subroutine to wait for and read a single keystroke. The character is returned in the AL register.

    ; Check if it's a backspace (0x08)
    cmp al, 0x08
    je .backspace
; Compares the input character (in AL) with the ASCII code for backspace. If it matches, it jumps to the backspace handler.

    ; Check if it's the Enter key (0x0d)
    cmp al, 0x0d
    je .process_command
; Compares the input character with the ASCII code for Enter. If it matches, it jumps to the command processing logic.

    ; Otherwise, echo the character and store it in the buffer
    mov ah, 0x0e
; Sets the AH register to 0x0e for the BIOS teletype output service.

    int 0x10
; Calls the BIOS video interrupt to print the character currently in AL to the screen.

    movzx ebx, byte [buffer_pos]
; Moves the value of `buffer_pos` into the EBX register, zero-extending it to 32 bits. This is a good practice for modern assemblers and makes addressing easier.

    mov byte [cmd_buffer + ebx], al
; Stores the typed character (in AL) into the `cmd_buffer` at the position indicated by `buffer_pos`.

    inc byte [buffer_pos]
; Increments the `buffer_pos` to prepare for the next character.

    jmp .main_loop
; Jumps back to the start of the main loop to wait for the next keystroke.

.backspace:
    movzx ebx, byte [buffer_pos]
    cmp ebx, 0
    je .main_loop
; Checks if the buffer is empty. If so, it does nothing and returns to the loop.

    dec byte [buffer_pos]
; Decrements the `buffer_pos` to erase the last character.

    mov byte [cmd_buffer + ebx - 1], 0
; Nulls out the last character in the buffer, effectively erasing it.

    mov ah, 0x0e
    mov al, 0x08 ; Backspace
    int 0x10
; Prints a backspace character to the screen, moving the cursor back one position.

    mov ah, 0x0e
    mov al, ' '
    int 0x10
; Prints a space character to the screen, effectively erasing the character that was just backspaced over.

    mov ah, 0x0e
    mov al, 0x08
    int 0x10
; Prints another backspace to move the cursor back again, so it's ready for the next character.

    jmp .main_loop
; Jumps back to the main loop to continue accepting input.

.process_command:
    call new_line
; Moves the cursor to a new line before processing the command.

    movzx ebx, byte [buffer_pos]
    mov byte [cmd_buffer + ebx], 0 ; Null-terminate the string
; Adds a null terminator (0x00) to the end of the input string, which is necessary for string-handling subroutines.
    
    ; The following sections compare the input string with known commands like "help", "ls", "cat", and "echo".
    ; It uses the `compare_string` and `compare_string_space` subroutines to check for matches.
    ; `jnc` (Jump if No Carry) is used to check for a match, as the compare functions clear the carry flag on a match.
    
    mov si, cmd_buffer
    mov di, help_cmd
    call compare_string
    jnc .is_help
    
    ; ... (similar logic for ls, cat, and echo) ...
   
    ; If no match, print "unknown command"
    mov si, unknown_cmd
    call print_string
    jmp .reset_prompt
; If none of the command comparisons match, this block executes, printing an error message.

.is_help:
    mov si, help_msg
    call print_string
    jmp .reset_prompt
; If "help" matches, it prints the help message and then jumps to the prompt reset.

.is_ls:
    call ls_command
    jmp .reset_prompt
; If "ls" matches, it calls the `ls_command` subroutine.

.is_cat:
    mov si, cmd_buffer
    add si, 4 ; Skip "cat "
    call cat_command
    jmp .reset_prompt
; If "cat" matches, it adjusts the `si` pointer to point to the filename argument and calls `cat_command`.

.is_echo:
    mov si, cmd_buffer
    add si, 5 ; Skip "echo "
    call echo_command
    jmp .reset_prompt
; If "echo" matches, it adjusts the `si` pointer to point to the text argument and calls `echo_command`.

.reset_prompt:
    mov byte [buffer_pos], 0 ; Reset buffer position
    call new_line
    call print_prompt
    jmp .main_loop
; This section is executed after every command. It clears the buffer, prints a new line, and displays the prompt.


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
; This subroutine prints a string byte by byte. It includes logic to handle line wrapping by checking if the cursor reaches the 80th column.

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
; Prints a carriage return (0x0d) and a line feed (0x0a) to move the cursor to the beginning of the next line.

; ls_command: Lists files in the file table
ls_command:
    mov si, file_table ; Pointer to file table
    mov cx, 5          ; Max number of files
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
; This subroutine iterates through the `file_table` array, printing each file name until it finds a null terminator (0).

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
; This part of the code searches for the filename in the `file_table`. If found, it proceeds.

    ; Found the file, now read its data
    pop di
    pop si
    call new_line
    mov bl, [di+8] ; Get starting sector
    mov bh, 0x00   ; Get sector count
    mov cl, [di+9] ; Number of sectors to read
    mov bx, FILE_DATA_START ; Buffer to load data into
; Once the file is found, this section loads the file's metadata (start sector and size) from the `file_table` into registers.

    mov ah, 0x02
    mov al, cl
    mov ch, 0x00
    mov cl, bl
    mov dh, 0x00
    mov dl, 0x00
    int 0x13
; This sequence of instructions prepares and calls the BIOS disk read interrupt (int 0x13, ah=0x02) to load the file's data from the disk into the `FILE_DATA_START` buffer.

    mov si, FILE_DATA_START
    call print_string
    call new_line
    ret
; After the disk read, it prints the contents of the loaded file to the screen.

.not_found:
    pop di
    pop si
    mov si, file_not_found_msg
    call print_string
    call new_line
    ret
; If the loop finishes without finding the file, this code prints an error message.



; --- Data and Messages ---
help_cmd:           db 'help', 0
; ... (other command strings) ...
unknown_cmd:        db 'Unknown command!', 0x0d, 0x0a, 0x00
; ... (other messages) ...
; These sections define the strings for commands and messages used by the kernel.
; The `0x0d, 0x0a, 0x00` sequence is for carriage return, line feed, and null terminator.

; --- File System ---
; File table (16 bytes per entry)
; [16-byte filename] [1-byte start sector] [1-byte size in sectors]
file_table:
    db 'README.md', 0,0,0,0,0,0,0, 2, 1 ; README.md, starting at sector 2, size 1
    db 'MESSAGE.TXT', 0,0,0,0,0,0, 3, 1 ; MESSAGE.TXT, starting at sector 3, size 1
    db 0                ; End of file table marker
; This is a simple, hardcoded file table. Each entry is 16 bytes: the filename (padded with zeros), the starting sector on the disk, and the size in sectors. The final 'db 0' acts as a sentinel to mark the end of the table.

; File data (starts at sector 2)
times 2*DISK_SECTOR_SIZE - ($ - $$) db 0 ; Pad to sector 2
; This command ensures the `readme_content` is placed at the correct offset to simulate being in sector 2 of the disk image.

readme_content:
    db 'This is a README file. You can see me with the `cat` command!', 0
times 3*DISK_SECTOR_SIZE - ($ - $$) db 0 ; Pad to sector 3
; This section contains the actual data for the README.md file. It is followed by padding to simulate the start of the next sector.

message_content:
    db 'This is a test message. Welcome to the terminal!', 0
; This contains the data for the MESSAGE.TXT file.

; --- Final Padding ---
end_of_kernel_content:
times ( (end_of_kernel_content - $$ + DISK_SECTOR_SIZE - 1) / DISK_SECTOR_SIZE ) * DISK_SECTOR_SIZE - (end_of_kernel_content - $$) db 0
; This is a robust calculation to ensure the entire kernel binary is a multiple of the disk sector size (512 bytes). This is crucial for the bootloader to read the entire file correctly.
