; ---------------------------------------------------------------------------------------------------------------------
; A simple 32-bit protected mode kernel with a basic command-line interface.
; This kernel is loaded by the bootloader at address 0x10000.
; ---------------------------------------------------------------------------------------------------------------------

[org 0x10000]                   ; The origin address of the kernel in memory.
[bits 32]                       ; The kernel runs in 32-bit protected mode.

DISK_SECTOR_SIZE equ 512        ; A constant representing the size of a disk sector in bytes.
MAX_CMD_LENGTH equ 64           ; Maximum number of characters for a user command.

; --- File System Data Structure ---
; This is a simple, hardcoded file table. Each entry is a file.
; Format: [8-byte filename] [1-byte starting sector] [1-byte size in sectors]
file_table:
    db 'README  ', 2, 1         ; 'README' file, starts at sector 2, 1 sector long.
    db 'MESSAGE ', 3, 1         ; 'MESSAGE' file, starts at sector 3, 1 sector long.
    db 0,0,0,0,0,0,0,0,0,0      ; Null entry to mark the end of the file table.

; --- Kernel Code ---
start_kernel:
    ; Set up the segment registers. In protected mode, they are loaded with a selector
    ; that points to a descriptor in the GDT, not a linear address.
    mov eax, 0x10               ; Load the data segment selector (0x10) into EAX.
    mov ds, eax                 ; Set the Data Segment register.
    mov es, eax                 ; Set the Extra Segment register.
    mov fs, eax                 ; Set the FS Segment register.
    mov gs, eax                 ; Set the GS Segment register.
    mov ss, eax                 ; Set the Stack Segment register.
    mov esp, 0x1F000            ; Set the 32-bit stack pointer to a safe address.

    ; Call the subroutine to display the prompt.
    call new_line_and_prompt

; --- The Main Command Loop ---
command_loop:
    call read_command           ; Read user input from the keyboard.
    call new_line_and_prompt    ; Display a new line and the prompt for the next command.
    jmp command_loop            ; Loop back to read the next command.

; --- Subroutine to Print a Null-Terminated String to the VGA Text Buffer ---
; In protected mode, we write directly to video memory instead of using BIOS interrupts.
; The VGA text buffer is located at physical address 0xB8000.
; Input: ESI = Address of the string.
print_string:
    mov edi, 0xB8000            ; Load the physical address of the VGA text buffer into EDI.
.loop:
    lodsb                       ; Load a byte from the string (pointed to by ESI) into AL and increment ESI.
    or al, al                   ; Perform a bitwise OR of AL with itself. This sets the zero flag if AL is 0.
    jz .done                    ; If AL is 0 (zero flag is set), the string has ended, so jump to .done.
    
    ; Place the character and its attribute (color) into the video memory.
    mov ah, 0x0F                ; Set the character attribute to 0x0F (white on black).
    mov [edi], ax               ; Move the 16-bit character-attribute pair to the video buffer.
    
    add edi, 2                  ; Move to the next character position in the video buffer (2 bytes per character).
    jmp .loop                   ; Loop back to print the next character.
.done:
    ret                         ; Return from the subroutine.

; --- Subroutine to Print a New Line and Prompt ---
new_line_and_prompt:
    ; Note: This simple example does not handle scrolling, but it moves the cursor for a new line.
    mov esi, new_line_str       ; Load the address of the new line string into ESI.
    call print_string           ; Print the new line.
    mov esi, prompt_str         ; Load the address of the prompt string.
    call print_string           ; Print the prompt.
    ret

; --- Subroutine to Read a Command from the Keyboard ---
; We still use BIOS interrupt 0x16, as it's a simple way to get keystrokes without writing a full driver.
read_command:
    xor edi, edi                ; Clear the EDI (Destination Index) register. It will be our buffer index.
    mov esi, command_buffer     ; Set ESI to the start of the command buffer.
.loop:
    mov ah, 0x00                ; BIOS Function: Get Keystroke.
    int 0x16                    ; Call the BIOS interrupt to get a character from the keyboard.
    
    cmp al, 0x08                ; Check if the character is the backspace key (ASCII 8).
    je .backspace               ; If so, jump to the backspace handler.
    
    cmp al, 0x0d                ; Check if the character is the enter key (ASCII 13).
    je .done                    ; If so, jump to .done to process the command.
    
    cmp edi, MAX_CMD_LENGTH     ; Check if the command buffer is full.
    jae .loop                   ; If it is, ignore the character and loop back.
    
    mov [esi], al               ; Store the character in the command buffer.
    inc esi                     ; Increment the buffer pointer.
    mov ah, 0x0e                ; BIOS Function: Teletype Output (to echo the character to the screen).
    int 0x10                    ; Print the character.
    inc edi                     ; Increment our buffer index.
    jmp .loop
    
.backspace:
    cmp edi, 0                  ; Check if the buffer is empty.
    jz .loop                    ; If it is, ignore the backspace.
    
    dec esi                     ; Decrement the buffer pointer.
    dec edi                     ; Decrement the buffer index.
    
    mov al, 0x08                ; Load the backspace character into AL.
    mov ah, 0x0e                ; BIOS Function: Teletype Output.
    int 0x10                    ; Print the backspace.
    
    mov al, ' '                 ; Load a space character.
    int 0x10                    ; Print a space to erase the character.
    
    mov al, 0x08                ; Load another backspace.
    int 0x10                    ; Print another backspace to move the cursor back.
    jmp .loop
    
.done:
    mov byte [esi], 0           ; Add a null terminator to the end of the command string.
    
    mov esi, command_buffer     ; Load the address of the command string into ESI.
    call process_command        ; Jump to the command processing subroutine.
    ret                         ; Return to the main command loop.

; --- Subroutine to Process the Command ---
process_command:
    ; Process the 'help' command.
    mov esi, command_buffer     ; Load the command buffer address into ESI.
    mov edi, help_cmd           ; Load the 'help' command string into EDI.
    call string_compare         ; Compare the two strings.
    jc .is_help                 ; If they are equal, jump to the help handler.
    
    ; Process the 'cat' command.
    mov esi, command_buffer
    mov edi, cat_cmd
    call string_compare
    jc .is_cat                  ; If they are equal, jump to the cat handler.
    
    jmp .command_not_found      ; If no command matched, jump to the 'not found' handler.

.is_help:
    mov esi, help_msg           ; Load the help message string.
    call print_string           ; Print it to the screen.
    ret
    
.is_cat:
    mov esi, command_buffer + 4 ; Skip the 'cat ' part of the command.
    call find_file              ; Find the file on the disk.
    cmp eax, 0                  ; Check if the file was found. EAX will be 0 if not.
    jz .file_not_found          ; If not, jump to the 'file not found' handler.
    
    ; If the file was found, EAX now contains the starting sector and ECX has the size in sectors.
    mov ebx, 0x12000            ; Load the file into a temporary buffer at 0x12000.
    mov al, cl                  ; AL = number of sectors to read.
    mov ch, ah                  ; CH = cylinder number.
    mov cl, al                  ; CL = starting sector number.
    
    mov ah, 0x02                ; BIOS Function: Read Sectors.
    mov dh, 0x00                ; Head 0.
    mov dl, 0x00                ; Drive A:.
    int 0x13
    
    mov esi, 0x12000            ; Load the address of the buffer into ESI.
    call print_string           ; Print the file's contents.
    ret
    
.file_not_found:
    mov esi, file_not_found_msg ; Load the file not found message.
    call print_string           ; Print the message.
    ret

.command_not_found:
    mov esi, not_found_msg      ; Load the 'not found' message.
    call print_string           ; Print the message.
    ret

; --- Subroutine to Find a File in the File Table ---
; Input: ESI = Pointer to the filename string to find.
; Output: EAX = starting sector of the file, ECX = size in sectors. EAX = 0 if not found.
find_file:
    mov edi, file_table         ; Load the address of the file table.
    xor eax, eax                ; Clear EAX. This will be our return value for 'not found'.
.loop:
    cmp byte [edi], 0           ; Check if we've reached the end of the file table.
    jz .done                    ; If so, the file was not found, so jump to .done.

    push esi                    ; Save ESI and EDI to the stack.
    push edi
    mov ecx, 8                  ; Loop counter for the filename comparison.
    repne cmpsb                 ; Compare 8 bytes of the filename strings.
    
    pop edi                     ; Restore EDI.
    pop esi                     ; Restore ESI.
    
    je .found                   ; If the strings matched, jump to .found.
    
    add edi, 10                 ; Move to the next file entry in the file table (8 byte filename + 2 bytes for size and start sector).
    jmp .loop
    
.found:
    mov al, [edi+8]             ; Load the starting sector of the file into AL.
    mov ah, [edi+9]             ; Load the size of the file into AH.
    mov eax, 0x0002
    mov ecx, 0x0001
    
    ret                         ; Return.

.done:
    xor eax, eax                ; Clear EAX to indicate 'not found'.
    xor ecx, ecx                ; Clear ECX.
    ret

; --- Subroutine to Compare Two Strings ---
; Input: ESI = First string, EDI = Second string.
; Output: Carry flag is set if strings are equal.
string_compare:
    push esi                    ; Save ESI and EDI to the stack.
    push edi
    
    xor ecx, ecx                ; Clear ECX.
    mov cl, [esi]               ; Get the length of the string to compare.
    repz cmpsb                  ; Compare the strings until a difference is found or the end of the string.
    
    pop edi
    pop esi
    
    ret

; --- Data Section ---
new_line_str db 0x0d, 0x0a, 0       ; Carriage return, line feed, and null terminator.
prompt_str db '>', 0
not_found_msg db 'Command not found.', 0x0d, 0x0a, 0
help_msg db 'Commands: help, cat <file>', 0x0d, 0x0a, 0
file_not_found_msg db 'File not found.', 0x0d, 0x0a, 0
command_buffer times MAX_CMD_LENGTH+1 db 0   ; Buffer to store user input. +1 for the null terminator.
help_cmd db 'help', 0
cat_cmd db 'cat ', 0

; --- Hardcoded File Content ---
; This is a simple, hardcoded file system. Files are not 'created' or 'deleted' at runtime.
; Their content is placed directly into the binary when it's compiled.
times 2*DISK_SECTOR_SIZE - ($ - $$) db 0   ; Pad to the start of the 'README' file at sector 2.
readme_content db 'This is a README file. It describes the simple kernel.', 0
times 3*DISK_SECTOR_SIZE - ($ - $$) db 0   ; Pad to the start of the 'MESSAGE' file at sector 3.
message_content db 'This is a test message. Welcome to the kernel!', 0

; --- Final Padding ---
times (10*DISK_SECTOR_SIZE) - ($ - $$) db 0 ; Pad the entire kernel to 10 sectors (5120 bytes).