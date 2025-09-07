[org 0x8000]
start:

    mov si, kernel_banner ; Load address of banner string into SI
    call print_string     ; Print the banner string
    call new_line                   ; Print newline
    call print_prompt               ; Display command prompt
; --- Main Command Loop ---
.main_loop:

    
    
    call read_char                  ; Wait for keypress
    cmp al, 0x08                    ; Check for backspace
    je .backspace                   ; Jump if backspace
    cmp al, 0x0d                    ; Check for Enter key
    je .process_command             ; Jump if Enter

    mov ah, 0x0e                    ; BIOS teletype output
    int 0x10                        ; Print character in AL

    movzx bx, byte [buffer_pos]     ; Load buffer position into BX
    mov byte [cmd_buffer + bx], al ; Store character in command buffer
    inc byte [buffer_pos]          ; Increment buffer position
    jmp .main_loop                  ; Repeat loop

.backspace:
    movzx bx, byte [buffer_pos]     ; Load buffer position
    cmp bx, 0                       ; Check if buffer is empty
    je .main_loop                   ; Skip if nothing to delete
    dec byte [buffer_pos]          ; Decrement buffer position
    mov byte [cmd_buffer + bx - 1], 0 ; Clear last character

    mov ah, 0x0e                    ; BIOS teletype output
    mov al, 0x08                    ; Backspace character
    int 0x10                        ; Print backspace
    mov al, ' '                     ; Space to erase character
    int 0x10                        ; Print space
    mov al, 0x08                    ; Backspace again
    int 0x10                        ; Move cursor back
    jmp .main_loop                  ; Continue loop

.process_command:
   
    

    

    call new_line                   ; Print newline
    movzx bx, byte [buffer_pos]     ; Load buffer position
    mov byte [cmd_buffer + bx], 0  ; Null-terminate command
    
    mov si, cmd_buffer          ; Point SI to command buffer     
    call tokenize_input             ; Split command into tokens
    call new_line          ; Newline
    

    mov si, [token_table + 0]         ; First token
    mov di, help_cmd                ; Load "help" string into DI
    call compare_string             ; Compare input with "help"
    jnc .is_help                    ; Jump if match

    mov si, [token_table + 0]         ; First token
    mov di, ls_cmd                  ; Load "ls" string
    call compare_string             ; Compare input
    jnc .is_ls                      ; Jump if match



    mov si, [token_table + 0]
    mov di, cat_cmd                   ; Load "cat" string
    call compare_string               ; Compare with space tolerance
    jnc .is_cat                       ; Jump if match

    mov si, cmd_buffer              ; Load command buffer into SI
    mov di, echo_cmd                ; Load "echo" string
    call compare_string             ; Compare with space tolerance
    jnc .is_echo                    ; Jump if match

    mov si, cmd_buffer              ; Load command buffer into SI
    mov di, clear_cmd               ; Load "clear" string
    call compare_string             ; Compare input
    jnc .is_clear                   ; Jump if match

    mov si, unknown_cmd             ; Load unknown command message
    call print_string               ; Print error message
    jmp .reset_prompt               ; Reset prompt

.is_help:
    
    mov si, help_msg                ; Load help message
    call print_string              ; Print help
    jmp .reset_prompt               ; Reset prompt

.is_ls:
    mov si, [token_table]           ; Load command buffer
    call ls_command                 ; Execute ls command
    jmp .reset_prompt               ; Reset prompt

.is_cat:

   
    call cat_command                 ; Execute cat command
    jmp .reset_prompt                ; Reset prompt

.is_echo:
    mov si, cmd_buffer              ; Load command buffer
    add si, 5                       ; Skip "echo " prefix
    call print_string               ; Print message
    call new_line                   ; Newline after echo
    jmp .reset_prompt               ; Reset prompt

.is_clear:
    mov ah, 0x00                    ; BIOS set video mode
    mov al, 0x03                    ; 80x25 text mode
    int 0x10                        ; Clear screen
    call new_line                   ; Print newline
    call print_prompt               ; Show prompt
    jmp .main_loop                  ; Resume loop

.reset_prompt:
    mov byte [buffer_pos], 0       ; Reset buffer position
    call new_line                   ; Print newline
    call print_prompt               ; Show prompt
    jmp .main_loop                  ; Resume loop

; --- Constants ---
PROMPT_CHAR          equ '>'              ; Character used for the command prompt
BUFFER_SIZE          equ 128              ; Size of the input buffer
FILE_TABLE_START     equ 0xA000           ; Memory address where the file table begins
FILE_DATA_START      equ 0xC000           ; Memory address where file contents are loaded
DISK_SECTOR_SIZE     equ 512              ; Size of one disk sector in bytes
FAT_TABLE_START      equ 0xB000           ; Memory address where the FAT table begins
MAX_SECTORS          equ 16               ; Maximum number of sectors supported
EOF_MARKER           equ 0xFF             ; Marker indicating end of file in FAT

; --- Variables ---
cmd_buffer           db BUFFER_SIZE dup(0) ; Input buffer for storing typed command
buffer_pos           db 0                 ; Current position in the input buffer
current_cursor_x     db 0                 ; Cursor X position (column)
current_cursor_y     db 1                 ; Cursor Y position (row)
token_table          dw 10 dup(0)         ; Table to store up to 10 token pointers

; --- Subroutines ---
print_prompt:
    mov ah, 0x0e                          ; BIOS teletype output function
    mov al, PROMPT_CHAR                  ; Load prompt character into AL
    int 0x10                             ; Print character to screen
    ret                                  ; Return from subroutine

read_char:
    mov ah, 0x00                          ; BIOS keyboard input function
    int 0x16                             ; Wait for keypress and store result in AL
    ret                                  ; Return from subroutine

tokenize_input:
   

   
    mov di, token_table        ; Start of token table
    xor bx, bx                 ; Token counter

.next_token:
    cmp byte [si], 0
    je .done

.skip_spaces:
    cmp byte [si], ' '
    jne .store_token
    inc si
    cmp byte [si], 0
    je .done
    jmp .skip_spaces

.store_token:
    mov [di], si               ; Store pointer to start of token
    add di, 2                  ; Move to next slot
    inc bx                     ; Increment token count

.scan_token:
    cmp byte [si], 0
    je .done
    cmp byte [si], ' '
    je .terminate_token
    inc si
    jmp .scan_token

.terminate_token:
    mov byte [si], 0       ; Replace space with null
    inc si
    jmp .next_token


.done:
   
    ret




print_string:
   mov ah, 0x0e                         ; BIOS teletype output function

.loop:
    lodsb                                ; Load next byte from [SI] into AL
    or al, al                            ; Check if AL is zero
    jz .done                             ; If zero, end of string
    int 0x10                             ; Print character
    inc byte [current_cursor_x]         ; Move cursor to next column
    cmp byte [current_cursor_x], 80     ; Check if end of line
    jne .loop                            ; If not, continue printing
    mov byte [current_cursor_x], 0      ; Reset cursor X
    call new_line                        ; Move to next line
    jmp .loop                            ; Continue printing
.done:
    ret                                  ; Return from subroutine

compare_string:
.loop:
   
    lodsb                                ; Load byte from [SI] into AL
    cmp al, [di]                         ; Compare with byte at [DI]
    jne .not_equal                       ; If not equal, exit
    cmp al, 0                            ; Check for null terminator
    je .equal                            ; If both are null, strings match
    inc di                               ; Move to next byte in DI
    jmp .loop                            ; Continue comparison
.equal:
    clc                                  ; Clear carry flag (match)
    ret                                  ; Return
.not_equal:
    stc                                  ; Set carry flag (no match)
    ret                                  ; Return

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
    
    
.loop:
    lodsb                               ; Load byte from [SI] into AL
    cmp al, [di]                        ; Compare AL with byte at [DI]
    jne .not_equal                      ; If not equal, jump to .not_equal
    cmp al, 0                           ; Check for null terminator
    je .match                           ; If null, strings match
    inc di                              ; Move to next byte in DI
    loop .loop                          ; Repeat until CX = 0
.match:
    clc                                 ; Clear carry flag (strings match)
    ret                                 ; Return
.not_equal:
    stc                                 ; Set carry flag (strings don't match)
    ret                                 ; Return

 

new_line:
    mov ah, 0x0e                         ; BIOS teletype output function
    mov al, 0x0d                         ; Carriage return
    int 0x10                             ; Print CR
    mov al, 0x0a                         ; Line feed
    int 0x10                             ; Print LF
    inc byte [current_cursor_y]         ; Move cursor to next row
    mov byte [current_cursor_x], 0      ; Reset cursor X
    ret                                  ; Return from subroutine

ls_command:


 mov di, file_table        ; Start of file table
mov cx, 5                 ; Max entries (or loop until empty)
.loop:
    mov al, [di]          ; First byte of entry
    cmp al, 0             ; Is entry empty?
    je .done              ; If yes, stop listing
    push di








    call print_string     ; Print filename  project faire un parameter to print_string !
    call new_line
    pop di
    call print_string     ; Print filename again for clarity
    call new_line
    add di, 16            ; Move to next entry
    call print_string










    
    loop .loop
.done:
    ret


cat_command:

    mov si, [token_table + 2]       ; Load second token (filename) into SI
    call print_string               ; Print filename for debugging
    call new_line                   ; Newline for clarity
    push si                         ; Save SI
    mov di, file_table              ; Point DI to start of file table
    mov cx, 5                       ; Set loop counter to 5 entries
.loop:
    push si                         ; Save SI again for nested loop
    push di                         ; Save DI
    mov al, [di]                    ; Load first byte of current file entry
    cmp al, 0                       ; Check if entry is empty
    je .not_found                   ; If empty, file not found
    call compare_string_with_len    ; Compare input filename with current entry
    jc .next_file                   ; If not equal, try next file
    pop di                          ; Restore DI
    pop si                          ; Restore SI
    call new_line                   ; Print a newline
    mov bl, [di+8]                  ; Load starting sector from file entry
    call read_file_fat              ; Read file data using FAT
    mov si, FILE_DATA_START         ; Point SI to loaded file data
    call print_string               ; Print file contents
    call new_line                   ; Print newline after file
    ret                               ; Return from subroutine
.next_file:
    pop di                          ; Restore DI
    pop si                          ; Restore SI
    add di, 16                      ; Move to next file entry
    loop .loop                      ; Repeat for remaining entries
.not_found:
    pop di                          ; Restore DI
    pop si                          ; Restore SI
    mov si, file_not_found_msg      ; Load error message
    call print_string               ; Print error message
    call new_line
    ret                               ; Return from subroutine

read_file_fat:
    mov si, FILE_DATA_START         ; SI = buffer start for file data
    call new_line                   ; Newline for clarity
    call print_string               ; Debug: Indicate file read start
    call new_line                   ; Newline for clarity
    
.next_sector:
    mov ah, 0x02                    ; BIOS: Read sector
    mov al, 1                       ; Read 1 sector
    mov ch, 0x00                    ; Cylinder 0
    mov dh, 0x00                    ; Head 0
    mov cl, bl                      ; Sector number (from BL)
    inc cl                          ; BIOS sectors start at 1
    mov dl, 0x80                    ; Drive 0x80 = first hard disk
    mov bx, si                      ; Buffer to load sector into
    int 0x13                        ; BIOS disk read
    jc .error                       ; Jump if read failed

    add si, DISK_SECTOR_SIZE        ; Move buffer pointer forward

    ; Get next sector from FAT
    mov di, FAT_TABLE_START         ; DI = start of FAT
    mov al, bl                      ; AL = current sector
    xor ah, ah                      ; AX = sector number
    add di, ax                      ; DI = FAT + sector index
    mov bl, [di]                    ; BL = next sector

    cmp bl, EOF_MARKER              ; End of file?
    je .done                        ; If yes, we're done
    jmp .next_sector                ; Otherwise, read next sector

.error:
    mov si, disk_error_msg
    call print_string
.done:
    ret



; --- Data ---
kernel_banner:        db 'FoisyOS Kernel Loaded. Type "help" for commands.', 0 ; Startup banner
help_cmd:             db 'help', 0              ; Command string for "help"
ls_cmd:               db 'ls', 0                ; Command string for "ls"
cat_cmd:              db 'cat', 0               ; Command string for "cat"
echo_cmd:             db 'echo', 0              ; Command string for "echo"
clear_cmd:            db 'clear', 0             ; Command string for "clear"
unknown_cmd:          db 'Unknown command!', 0x0d, 0x0a, 0 ; Error message for unknown command
help_msg:             db 'Available commands: help, ls, cat <file>, echo <text>, clear', 0 ; Help message
file_not_found_msg:   db 'File not found.', 0x0d, 0x0a, 0 ; Error message for missing file
disk_error_msg:       db 'Disk read error!', 0x0d, 0x0a, 0 ; Error message for disk failure
kernel_msg:           db 'Kernel started!', 0   ; Confirmation message after boot



; --- File Table ---
file_table:
    db 'readme', 0,0,0,0,0,0,0, 11, 0             ; File entry for "readme", starts at sector 11
    db 'message', 0,0,0,0,0,0, 12, 0              ; File entry for "message", starts at sector 12
    db 0                                         ; End of file table marker

; --- FAT Table ---
fat_table:
    times 11 db 0xFF      ; sectors 0–10
    db 0xFF               ; sector 11 = EOF
    db 0xFF               ; sector 12 = EOF
    times MAX_SECTORS - 13 db 0 ; pad remaining entries





; --- Final Padding ---

end_of_kernel_content:
times ((end_of_kernel_content - $$ + DISK_SECTOR_SIZE - 1) / DISK_SECTOR_SIZE) * DISK_SECTOR_SIZE - (end_of_kernel_content - $$) db 0
