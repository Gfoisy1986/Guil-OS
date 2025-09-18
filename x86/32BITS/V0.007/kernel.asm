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

    ; Load file table from disk
    mov eax, 111                  ; LBA start of file table
    mov ecx, 2                    ; Number of sectors to read
    mov edi, 0x80000              ; Destination buffer
    call read_sectors

    call Clear_screen

.start_shell:
    mov esi, msg_pm
    call print_pm
    call check_auto_scroll
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


      ; Check for "-cat"

    mov si, input_buffer
    mov esi, input_buffer
    mov edx, cmd_cat_inline
    mov edi, edx
    mov ecx, 4
    call strncmp32
    cmp al, 1
    je .handler_cat


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

.handler_cat:
    call tokenize32  ; tokenize fichier label in this case file of cat(-
    call load_and_print_file


    jmp .advance_cursor


.advance_cursor:
    call clear_input_buffer
    ; Move to next line
    inc byte [logical_cursor_row]
    mov byte [cursor_col], 0
    call set_cursor_pm



    ret

tokenize32:
    ; Input: ESI = pointer to input buffer (e.g., "-cat index.txt")
    ; Output:
    ;   - input buffer modified in-place: "-cat\0index.txt"
    ;   - EBX = pointer to argument ("index.txt")
    mov esi, input_buffer
    ;call print_pm
    add esi, 5                ; Skip first 5 characters ("-cat ")
    ;call print_pm
    mov ebx, esi
    ret

tokenize:
    mov bx, si
.loop:
    mov al, [bx]
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



load_and_print_file:

    ; Input: ESI = pointer to filename
    ; Output: prints file contents to screen

    mov edi, file_table           ; EDI = start of file table
    mov ecx, 2                  ; Max number of entries

.search_loop:
    push esi                     ; preserve filename pointer
    push edi                     ; preserve current entry pointer

    mov edx, edi                 ; EDX = current file table entry
    call strcmp32                ; compare ESI (filename) with EDX (entry)

    pop edi
    pop esi
    cmp al, 1
    je .found

    add edi, 32                  ; move to next entry
    dec ecx
    jnz .search_loop

.not_found:
    mov si, msg_file_not_found
    call print_pm
    ret

.found:
    ; EDI points to matching entry
    mov eax, [edi + 16]          ; start_sector
    mov ecx, [edi + 20]          ; sector_count
    mov edi, 0x1000000



    call read_sectors           ; Load file into memory

    pop esi
    mov esi, 0x1000000         ; Print file contents


    call print_pm



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
print_pm:    ;  32bits print command-------------------------------
    ; ESI = pointer to string
    push esi

    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax

    mov ah, 0x07
    call print_string_pm

    push esi
    call string_length
    pop esi
    add byte [cursor_col], cl

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
    inc ecx
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

print_esi:    ;  32bits print command-------------------------------
    ; ESI = pointer to string
    push esi

    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax

    mov ah, 0x07
    call print_string_esi

    push esi
    call string_length_esi
    pop esi
    add byte [cursor_col], cl

    call update_cursor_row
    call set_cursor_pm
    mov byte [screen_dirty], 1
    call redraw_screen

    pop esi
    ret


print_string_esi:
    push esi

.next_char:
    lodsb
    test al, al
    jz .done

    cmp al, 0x0A           ; Check for newline
    je .newline

    ; Calculate buffer position
    movzx eax, byte [logical_cursor_row]
    imul eax, 80           ; Row * 80 chars
    movzx ecx, byte [cursor_col]
    add eax, ecx           ; Column offset
    shl eax, 1             ; Move to the correct buffer location
    mov edi, text_buffer
    add edi, eax

    mov ah, 0x07           ; White on black attribute
    mov [edi], ax          ; Store character at buffer location

    inc byte [cursor_col]  ; Move cursor right
    cmp byte [cursor_col], 80
    jb .next_char

    ; Wrap to next line if end of row is reached
    mov byte [cursor_col], 0
    inc byte [logical_cursor_row]
    jmp .next_char

.newline:
    inc byte [logical_cursor_row]   ; Move to next line for newline
    mov byte [cursor_col], 0        ; Reset column
    jmp .next_char

.done:
    pop esi
    ret

; ----------------------------------------
; Data section (example)
; ----------------------------------------

section .data
align 512

file_table:

 hello:
    db 'hello.txt', 0
    times 16 - ($ - hello) db 0
    dd 114                      ; start_sector
    dd 1                          ; sector_count
    times 8 db 0

 index:
    db 'index.txt', 0
    times 16 - ($ - index) db 0
    dd 115
    dd 1
    times 8 db 0

    ; Fill remaining entries with zeros
    times (32 * 32 - 64) db 0


msg_pm: db "ADMIN @ Guil-OS: ", 0
text_buffer: times 8000 dw 0x0720


scroll_offset db 0                   ; Current top line index
screen_dirty db 1
logical_cursor_row db 0   ; Tracks actual row in the full buffer
current_input:   times 128 db 0           ; Buffer d’entrée courant
cursor_row db 0
cursor_col db 0
input_buffer times 512 db 0
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
cmd_help_inline: db "-help", 0
cmd_ls_inline:   db "-ls", 0
cmd_cat_inline: db "-cat", 0
msg_file_not_found: db "Error: File not found", 0
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

