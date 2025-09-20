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








    ; Load file table from disk
    mov eax, 40                  ; LBA start
	mov ecx, 44                  ; Number of sectors
	mov edi, 0x18000             ; Load entire block (FAT + file table + data)
	
    
	


    call Clear_screen

.start_shell:

    mov esi, msg_pm
    call print_pm
    
     
    
    call read_input_pm            ; Read user input
    call parse_command            ; Parse and execute
    jmp .start_shell              ; Loop back





;-------------------------------------------------------------------


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
    mov esi, input_buffer
    je .handler_ls


    ; Check for "-cat"
    
    ;mov esi, input_buffer
    ;mov edx, cmd_cat_inline
    ;mov edi, edx
    ;mov ecx, 4
    ;call strncmp32
    ;cmp al, 1
    ;je .handler_cat
    
    
    
    ; Check for "-ctt"
    mov esi, input_buffer
    mov edx, cmd_ctt
    mov edi, edx
    mov ecx, 4
    push esi
    push edi
    call strncmp32
    pop esi
    pop edi
    cmp al, 1
    je .handler_tt
    jne .advance_cursor
    
    
    ; create file
    mov esi, input_buffer
    mov edi, cmd_ls_create
    push esi
    push edi
    mov ecx, 4
    call strncmp32
    cmp al, 1
    pop esi
    pop edi
    je .handler_cc
    jne .advance_cursor


    ; Unknown command
    mov si, msg_unknown
    call print_pm
    jmp .advance_cursor




.handler_help:
    mov esi, msg_help
    call print_pm
    jmp .advance_cursor

.handler_ls:
    
    call list_files
    jmp .advance_cursor

.handler_tt:
    call tokenize2 ; tokenize fichier label in this case file of cat(-
    call load_and_print_file2
    jmp .advance_cursor
    
    
    
.handler_cc:
    mov esi, file_name_ptr
    push esi
    call create_file
    pop esi
    mov esi, echo_input         ; pointer to string
    mov edi, file_name_ptr   ; pointer to file entry
    push esi
    push edi
    call echo_to_file
    pop edi
    pop esi
    mov esi, good_file_create
    call print_pm
    jmp .advance_cursor
    
    
.advance_cursor:
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor si, si
    xor di, di
    xor bp, bp
    call newline_pm
    call clear_input_buffer
    ret
    
    
;-----------------------------------------------------------------
file:
	mov esi, file_name_ptr   ; pointer to "myfile.txt"
	mov ecx, 4096            ; 4KB file
	call create_file
	; eax = file index or -1

tokenize2:
	mov esi, input_buffer     ; ESI points to "-ctt hahaha"
	add esi, 5                ; Skip "-ctt " (5 bytes)
	;call print_pm             ; Print "hahaha"


tokenize:
    mov ebx, esi
.loop:
    mov al, [ebx]
    cmp al, ' '
    je .split
    cmp al, 0
    je .done
    inc bx
    jmp .loop

.split:
    mov byte [bx], 0     ; null-terminate command
    inc bx               ; BX now points to filename
.done:
    ret

read_sectors2:
    ; Inputs:
    ;   EAX = LBA sector number
    ;   ECX = number of sectors to read
    ;   EDI = destination address

    push eax
    push ecx

.next_sector:

    mov ebx, eax            ; Copy LBA
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    mov dx, 0x1F3
    mov al, bl
    out dx, al

    mov dx, 0x1F4
    mov al, bh
    out dx, al

    mov edx, eax
    shr edx, 16

    mov dx, 0x1F5
    mov al, dl
    out dx, al

    mov dx, 0x1F6
    mov al, 0xE0
    or al, dh
    out dx, al

    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

.wait_drq:
    mov dx, 0x1F7
    in al, dx
    test al, 0x08
    jz .wait_drq

    mov cx, 256
    mov dx, 0x1F0
.read_loop:
    in ax, dx
    stosw
    loop .read_loop
    pop eax
    pop ecx
    dec ecx
    jz .done

    inc eax
    add edi, 512
    jmp .next_sector

.done:

    ret




read_sectors:
    ; Inputs:
    ;   EAX = LBA sector number
    ;   ECX = number of sectors to read
    ;   EDI = destination address in memory

.next_sector:
    push eax
    push ecx

    ; Extract LBA bytes
    mov ebx, eax
    mov dx, 0x1F2         ; Sector count
    mov al, 1
    out dx, al

    mov dx, 0x1F3         ; LBA bits 0–7
    mov al, bl
    out dx, al

    mov dx, 0x1F4         ; LBA bits 8–15
    mov al, bh
    out dx, al

    shr ebx, 16
    mov dx, 0x1F5         ; LBA bits 16–23
    mov al, bl
    out dx, al

    mov dx, 0x1F6         ; Drive/head + LBA bits 24–27
    mov al, 0xE0
    or al, bh             ; LBA bits 24–27
    out dx, al

    mov dx, 0x1F7         ; Command port
    mov al, 0x20          ; Read sectors (PIO)
    out dx, al

.wait:
    mov dx, 0x1F7
    in al, dx

    test al, 0x08         ; DRQ bit
    jz .wait

    ; Read 256 words (512 bytes)
    mov cx, 256
    mov dx, 0x1F0
.read_loop:
    in ax, dx
    stosw
    loop .read_loop

    pop ecx
    pop eax
    dec ecx
    jz .done

    inc eax               ; Next LBA sector
    add edi, 512          ; Advance buffer
    jmp .next_sector

.done:
    ret

echo_to_file:
    ; Inputs:
    ;   ESI = pointer to null-terminated string
    ;   EDI = pointer to file_entry
    ; Output:
    ;   Writes string into file memory

    push edi
    push esi

    mov ebx, [edi + 36]       ; .ptr → destination buffer
    mov ecx, [edi + 32]       ; .size → max bytes allowed

.write_loop:
    lodsb
    cmp al, 0
    je .done
    cmp ecx, 0
    je .done                 ; prevent overflow

    mov [ebx], al
    inc ebx
    inc esi
    dec ecx
    jmp .write_loop

.done:
    pop esi
    pop edi
    ret


strcmp32:
    ; ESI = input string
    ; EDX = file table entry (filename)

.next_char:
    mov al, [esi]
    mov bl, [edx]
    cmp al, bl
    jne .not_equal
    test al, al
    je .equal
    inc esi
    inc edx
    jmp .next_char

.equal:
    mov al, 1
    ret

.not_equal:
    mov al, 0
    ret

strncmp32:
    ; ESI = input string
    ; EDX = file table entry
    ; ECX = number of characters to compare

.loop:
    mov al, [esi]
    mov bl, [edx]
    cmp al, bl
    jne .not_equal
    dec ecx
    je .equal
    inc esi
    inc edx
    jmp .loop

.not_equal:
    mov al, 0
    ret

.equal:
    mov al, 1
    ret


load_and_print_file2:
    push eax
    push ecx
    push edi
    push esi

    ; Find file entry by name
    mov edi, file_table_start2
    xor ecx, ecx

.find:
    cmp ecx, file_table_max2
    jae .not_found

    mov esi, file_name_ptr
    push esi
    push edi
    call strcmp
    pop edi
    pop esi
    cmp al, 1
    je .found

    add edi, file_entry_size2
    inc ecx
    jmp .find

.found:
    mov eax, [edi + 40]         ; .start_sector
    mov ecx, [edi + 44]         ; .sector_count
    mov edi, file_data_start    ; Destination buffer
    call read_sectors2

    ; Print file contents
    mov esi, file_data_start
.print_loop:
    mov al, [esi]
    cmp al, 0
    je .done
    call print_pm
    inc esi
    jmp .print_loop

.done:
    call newline_pm
    jmp .exit

.not_found:
    mov esi, msg_file_not_found
    call print_pm

.exit:
    pop esi
    pop edi
    pop ecx
    pop eax
    ret



strcmptt:    ;si <--
.next_char:

    mov al, cmd_ctt
    mov bl, [di]
    cmp al, bl
    jne .not_equal
    test al, al
    je .check_end
    inc si
    inc di
    jmp .next_char

.check_end:
    mov al, [di]
    test al, al
    jne .not_equal
    mov al, 1
    ret

.not_equal:
    mov al, 0
    ret


strcmp:    ;si <--
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
    rep lodsb
    xor bx, bx
    ret

read_input_pm:
    mov si, input_buffer
    xor bx, bx                      ; character count

.read_key:
    in al, 0x64
    test al, 1
    jz .read_key

    in al, 0x60                     ; read scancode
    cmp al, 0xE0
    je .read_extended

    test al, 0x80                   ; skip key releases
    jnz .read_key

    cmp al, 0x1C                    ; Enter
    je .done

    cmp al, 0x0E                    ; Backspace
    je .backspace

    ; Convert scancode to ASCII
    call scancode_to_ascii
    mov [si], al
    inc si
    inc bx

    ; Prepare AX for printing
    mov ah, 0x07
    movzx eax, al
    or ax, 0x0700

    ; Calculate buffer position
    movzx ecx, byte [logical_cursor_row]
    imul ecx, 80
    movzx edx, byte [cursor_col]
    add ecx, edx
    shl ecx, 1
    mov edi, text_buffer
    add edi, ecx

    stosw
    mov byte [screen_dirty], 1
    call update_cursor_row
    call set_cursor_pm
    call redraw_screen


    inc byte [cursor_col]
    call set_cursor_pm
    jmp .read_key

.backspace:
    cmp bx, 0
    je .read_key
    dec bx
    dec si
    cmp byte [cursor_col], 0
    je .read_key
    dec byte [cursor_col]

    ; Erase character in buffer
    mov ax, 0x0720
    movzx ecx, byte [logical_cursor_row]
    imul ecx, 80
    movzx edx, byte [cursor_col]
    add ecx, edx
    shl ecx, 1
    mov edi, text_buffer
    add edi, ecx
    stosw

    mov byte [screen_dirty], 1
    call update_cursor_row
    call set_cursor_pm
    call redraw_screen
    jmp .read_key


.read_extended:
    in al, 0x60                     ; read second byte
    cmp al, 0x51                    ; Page Down
    je .scroll_down
    cmp al, 0x49                    ; Page Up
    je .scroll_up
    jmp .read_key

.scroll_up:
    cmp byte [scroll_offset], 0
    je .read_key
    dec byte [scroll_offset]
    mov byte [screen_dirty], 1
    call redraw_screen
    jmp .read_key

.scroll_down:
    cmp byte [scroll_offset], 75   ; 100 - 25
    je .read_key
    inc byte [scroll_offset]
    mov byte [screen_dirty], 1
    call redraw_screen
    jmp .read_key

.done:
    mov byte [si], 0
    ret


check_auto_scroll:    ;xfer that in16 bits
    movzx eax, byte [logical_cursor_row]
    movzx ecx, byte [scroll_offset]
    sub eax, ecx
    cmp eax, 25
    jb .no_scroll
    inc byte [scroll_offset]
    mov byte [screen_dirty], 1
    call redraw_screen
.no_scroll:
    ret


set_cursor_pm:   ;16bits !!
    movzx eax, byte [logical_cursor_row]
    movzx ecx, byte [scroll_offset]
    sub eax, ecx                    ; EAX = visible row

    cmp eax, 25
    jae .skip_cursor_update         ; If off-screen, skip

    imul eax, 80                    ; row * 80
    movzx edx, byte [cursor_col]
    add eax, edx                    ; final offset
    mov bx, ax                      ; BX = cursor position

    ; Send high byte
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al

    ; Send low byte
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al

.skip_cursor_update:
    ret




Clear_screen:
 ; Clear screen only once? Or move this to init
    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw
    ret

redraw_screen:
    cmp byte [screen_dirty], 0
    je .skip_redraw

    mov byte [screen_dirty], 0

    push esi
    push edi
    push ecx
    push eax

    movzx eax, byte [scroll_offset]
    imul eax, 160                  ; 80 chars * 2 bytes
    mov esi, text_buffer
    add esi, eax                   ; ESI = start of visible buffer

    mov edi, 0xB8000               ; Video memory
    mov ecx, 25                    ; 25 lines

.redraw_loop:
    push ecx
    mov ecx, 80                    ; 80 characters per line

.copy_char:
    mov ax, [esi]
    mov [edi], ax
    add esi, 2
    add edi, 2
    loop .copy_char
    pop ecx
    loop .redraw_loop

    call draw_scrollbar

    pop eax
    pop ecx
    pop edi
    pop esi

.skip_redraw:
    ret



draw_scrollbar:
    mov edi, 0xB8000
    add edi, 79 * 2                 ; Last column
    mov ecx, 25

.draw_line:
    mov ax, 0x0720                  ; Light gray space
    stosw
    add edi, (80 - 1) * 2           ; Move to next line's last column
    loop .draw_line

    ; Draw thumb
    movzx eax, byte [scroll_offset]
    mov bl, 100 - 25                ; Max scroll
    mul bl
    mov bl, 25         ; divisor
    movzx ebx, bl      ; zero-extend to 32-bit
    xor edx, edx       ; clear high bits for division
    div ebx            ; eax = eax / ebx

    movzx ecx, al
    mov edi, 0xB8000
    mov eax, ecx        ; Copy ECX to EAX
    imul eax, 160       ; 80 chars * 2 bytes per char = 160 bytes per line
    add edi, eax        ; Add result to EDI
    add edi, 79 * 2
    mov ax, 0x07DB                  ; █ character
    stosw
    ret

; --- Protected Mode Print Routine ---
print_pm:    ; 32-bit print command
    ; ESI = pointer to string
    ; ECX = length of string

    push esi

    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx edx, byte [cursor_col]
    add eax, edx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax

    mov ah, 0x07
    call print_string_pm   ; assumes ECX = length

    add byte [cursor_col], cl  ; update cursor column by length

    call update_cursor_row
    call set_cursor_pm
    mov byte [screen_dirty], 1
    call redraw_screen

    pop esi
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
    inc cl
    jmp .next_char
.done:

    pop esi
    ret


string_length_esi:
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
    inc byte [logical_cursor_row]
    mov byte [cursor_col], 0

    ; Recalculate EDI for logical buffer
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax

    jmp .next_char



.done:
    pop esi
    ret

update_cursor_row:
    movzx eax, byte [logical_cursor_row]
    movzx ecx, byte [scroll_offset]
    sub eax, ecx
    cmp eax, 25
    jae .offscreen
    mov [cursor_row], al
    ret

.offscreen:
    mov byte [cursor_row], 24      ; Clamp to bottom
    ret


newline_pm:

 inc byte [logical_cursor_row]
    mov byte [cursor_col], 0

    ; Recalculate EDI for logical buffer
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    ret

print_number:
    push eax
    push ebx
    push ecx
    push edx

    mov ecx, 0              ; digit count
    mov ebx, 10             ; divisor

    ; Special case for zero
    cmp eax, 0
    jne .convert
    mov si, '0'
    call print_pm
    jmp .done

.convert:
    ; Convert number to ASCII digits (in reverse)
    .loop:
        xor edx, edx
        div ebx             ; eax / 10 → eax, remainder → edx
        add si, '0'         ; convert to ASCII
        push si             ; save digit
        inc ecx
        cmp eax, 0
        jne .loop

    ; Print digits in correct order
    .print_loop:
        pop dx


        call print_pm
        loop .print_loop

.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret


; Inputs:
;   esi = pointer to null-terminated file name
;   ecx = file size in bytes
; Outputs:
list_files:
    push esi
    push edi
    push eax
    push ecx
    push edx

    mov edi, file_table_start2   ; Start of file table
    xor ecx, ecx                 ; File index = 0

.loop:
    cmp ecx, file_table_max2     ; Reached max entries?
    jae .done                    ; If yes, exit

    mov edx, [edi + 32]          ; Load .size
    cmp edx, 0
    je .next                     ; Skip empty entry

    ; Print file name
    mov esi, edi                 ; .name pointer
    call print_pm                ; Print null-terminated name

    ; Print separator
    ;mov esi, sep_str
    ;call print_pm

    ; Print file size
    ;mov eax, edx                 ; .size
    ;call print_number        ; Print EAX as decimal

    ; Print newline
    call newline_pm

.next:
    add edi, file_entry_size2    ; Move to next entry
    inc ecx                      ; Increment index
    jmp .loop

.done:
    pop edx
    pop ecx
    pop eax
    pop edi
    pop esi
    ret


  




create_file:
    push ebx
    push edx
    push edi

    ; Find empty slot in file table
    mov edi, file_table_start2
    xor eax, eax

.find_slot:
    mov edx, [edi + 32]      ; .size
    cmp edx, 0
    je .found_slot
    add edi, file_entry_size2
    inc eax
    cmp eax, file_table_max2
    jae .fail
    jmp .find_slot

.found_slot:
    ; Copy file name
    mov ebx, edi
    mov edx, 32
.copy_name:
    mov al, [esi]
    mov [ebx], al
    inc esi
    inc ebx
    dec edx
    test al, al
    je .name_done
    cmp edx, 0
    je .name_done
    jmp .copy_name
.name_done:

    ; Allocate sectors via FAT
    mov ecx, 1                  ; Number of sectors (for now, 1)
    call allocate_sectors      ; Returns start sector in eax
    cmp eax, -1
    je .fail

    mov [edi + 40], eax         ; .start_sector
    mov [edi + 44], ecx         ; .sector_count
    mov dword [edi + 32], 512        ; .size = 1 sector

    ; Write data to sector
    mov esi, echo_input         ; Source
    mov edi, file_data_start    ; Temp buffer
    mov ecx, 512
.copy_data:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    dec ecx
    jnz .copy_data

    ; Write to disk
    mov eax, [edi + 40]         ; .start_sector
    mov ecx, 1
    mov edi, file_data_start
    call echo_to_file

    pop edi
    pop edx
    pop ebx
    ret

.fail:
    mov eax, -1
    pop edi
    pop edx
    pop ebx
    ret



; Simple bump allocator
current_ptr dd file_buffer_start

allocate_file_space:
    ; Input: size in eax
    ; Output: pointer in ebx
    mov ebx, [current_ptr]
    add [current_ptr], eax
    ret
    
    
    
allocate_sectors:
    ; Input: ecx = number of sectors
    ; Output: eax = start sector, or -1 if failed

    mov esi, fat_table_start
    xor eax, eax              ; sector index
    xor ebx, ebx              ; count of allocated
    mov edx, -1               ; end marker

.find:
    cmp ebx, ecx
    je .done

    mov edi, esi
    add edi, eax
    shl edi, 2                ; edi = FAT[eax]

    mov dword [edi], edx      ; mark as used
    inc ebx
    inc eax
    jmp .find

.done:
    mov eax, 0                ; return first allocated sector
    ret



free_sectors:
    ; Input: eax = start_sector
.loop:
    mov edi, fat_table_start
    add edi, eax
    shl edi, 2
    mov ebx, [edi]
    mov dword [edi], 0        ; mark as free
    cmp ebx, -1
    je .done
    mov eax, ebx
    jmp .loop
.done:
    ret



struc file_entry
    .name         resb 32     ; offset 0
    .size         resd 1      ; offset 32
    .ptr          resd 1      ; offset 36 (optional if using sectors)
    .start_sector resd 1      ; offset 40
    .sector_count resd 1      ; offset 44
endstruc






; ----------------------------------------
; Data section (example)
; ----------------------------------------


echo_input: db "heya this is good", 0
msg_pm: db "ADMIN @ Guil-OS: ", 0
text_buffer: times 8000 dw 0x0720


scroll_offset db 0                   ; Current top line index
screen_dirty db 1
logical_cursor_row db 0   ; Tracks actual row in the full buffer
current_input:   times 128 db 0           ; Buffer d’entrée courant
cursor_row db 0
cursor_col db 0
input_buffer times 512 db 0
; Example: Reserve 1GB starting at 0x100000
fat_table_start     equ 0x18000         ; Start of FAT table
fat_entry_size      equ 4               ; Each FAT entry is 4 bytes
fat_sector_count    equ 44              ; Total sectors available
fat_table_size      equ fat_sector_count * fat_entry_size   ; 176 bytes

file_table_start2   equ fat_table_start + fat_table_size    ; 0x180B0
file_entry_size2    equ 52              ; Corrected size of file_entry
file_table_max2     equ 128             ; Number of file entries (≈6.5 KB)

file_data_start     equ file_table_start2 + file_entry_size2 * file_table_max2

file_buffer_start equ 0x18000
file_buffer_ptr   dd file_buffer_start

sep_str db " - ", 0
newline_str db 13, 10, 0
file_name_ptr: db "myflie.txt", 0
msg_help:
db 0x0A
db "  cmd:  -help <list command>", 0x0A
db 0x0A
db "  cmd:  -ls <list file>", 0x0A
db 0
msg_ls:
db 0x0A
db "  bootloader.bin", 0x0A
db "  kernel.bin", 0x0A
db 0x0A
db 0
msg_unknown:
db 0x0A
db "  unknow command! ", 0x0A
db 0x0A
db 0
good_file_create:
db 0x0A
db "File was Created sucessfuly! ", 0x0A
db 0x0A
db 0
file_length: dd 0

cmd_help_inline: db "-help", 0
cmd_ls_inline:   db "-ls", 0
cmd_cat_inline: db "-cat", 0
cmd_ctt: db "-ctt", 0
cmd_ls_create: db "-crt", 0
msg_file_not_found:
db 0x0A
db "Error: File not found", 0x0A
db 0x0A
db 0
db_file: dd 0x00005555
db_file2: dd 0x18000


start_file:
db 0x0A
db "start of files", 0x0A
db 0x0A
db 0
end_file:
db 0x0A
db "end of files", 0x0A
db 0x0A
db 0
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
times 55808 - ($ - $$) db 0

