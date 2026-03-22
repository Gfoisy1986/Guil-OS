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

    ; ============================
    ; ENABLE A20 LINE (required)
    ; ============================
    in al, 0x92
    or al, 2
    out 0x92, al

    ; ============================
    ; Load GDT (still in 16-bit)
    ; ============================
    cli
    lgdt [gdt_descriptor]

    ; ============================
    ; Enable Protected Mode
    ; ============================
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp CODE_SEG:protected_mode


; -------------------------------------------------
; À partir d’ici : code 32 bits
; -------------------------------------------------
[BITS 32]

protected_mode:
    ; segments 32-bit
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; stack 32-bit
    mov esp, 0x9FC00

    ; --- init IDT: toutes les entrées -> isr_default ---
    xor eax, eax            ; eax = index = 0
    mov ecx, 256            ; 256 entrées

.init_idt_loop:
    mov edx, isr_default    ; base
    mov bx, CODE_SEG        ; selector
    mov cl, 0x8E            ; present, ring0, 32-bit interrupt gate
    call set_idt_entry

    inc eax
    loop .init_idt_loop

    lidt [idt_descriptor]

    call remap_pic
     call install_timer_irq
     call install_keyboard_irq
     sti

    ; puis ton shell :
     jmp .start_shell


.start_shell:






    mov esi, msg_pm
    call print_pm


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

    ; Check for "-lsss"

    mov si, input_buffer
    mov edx, cmd_ls_inline
    mov edi, edx
    mov ecx, 4
    call strncmp32
    cmp al, 1
    je .handler_ls


      ; Check for "-cat"

    mov si, input_buffer
    mov esi, input_buffer
    mov edx, cmd_cat_inline
    mov edi, edx
    mov ecx, 3
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


    ; Recalculate EDI for top-left of screen
    mov edi, text_buffer

    call newline_pm
    call print_file_table_pm
    jmp .advance_cursor

.handler_cat:
    ; Tokenize input to extract filename

    call tokenize32         ; Assumes result is stored in [fichier] label

    ; Reset cursor position

    mov edi, text_buffer

    ; Print a couple of newlines for spacing

    call newline_pm

    ; Load and print the file


    call load_and_print_file


    ; Wait for user to press Enter
    call newline_pm

    call wait_for_enter

    jmp .advance_cursor



.advance_cursor:

    call clear_input_buffer
    ret




wait_for_enter:
.wait:
    call get_key_pm        ; AL = caractère ou 0 si rien
    test al, al
    jz .wait               ; rien reçu → attendre

    cmp al, 0x0D           ; ASCII Enter = 0x0D
    jne .wait

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
    add edi, 512         ; Advance buffer
    jmp .next_sector

.done:
    ret

strcmp32:
    ; ESI = input string
    ; EDI = file table entry (filename)

.next_char:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .not_equal
    test al, al
    je .equal
    inc esi
    inc edi
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


parse_number:
    xor eax, eax            ; Clear result

.next_digit:
    mov bl, [esi]           ; Load next character
    cmp bl, 0
    je .done
    cmp bl, 0x0A            ; Newline? End of number
    je .done

    sub bl, '0'             ; Convert ASCII to digit
    cmp bl, 9
    ja .done                ; Invalid digit, stop parsing

    imul eax, eax, 10
    movzx edx, bl           ; Zero-extend bl to 32-bit
    add eax, edx            ; Add digit to result

    inc esi
    jmp .next_digit

.done:
    ret



load_and_print_file:
    mov ecx, file_table_start      ; ECX = pointer to file table
    mov ebx, esi                   ; EBX = pointer to filename (e.g., "hello.txt")

.next_line:
    mov esi, ecx                   ; ESI = start of current line
    mov edi, ebx                   ; EDI = reset filename pointer

.compare_loop:
    mov al, [esi]
    cmp al, '|'
    je .match_check

    cmp al, 0
    je .not_found

    cmp al, 0x0A
    je .advance_line

    mov dl, [edi]
    cmp dl, al
    jne .advance_line

    inc esi
    inc edi
    jmp .compare_loop

.match_check:
    mov dl, [edi]
    cmp dl, 0
    jne .advance_line             ; Filename not fully matched

    ; Match found — ESI points to sector string
    inc esi
    call parse_number             ; EAX = sector number

    mov ecx, 1                    ; Load 1 sector
    mov edi, db_file              ; Destination buffer
    call read_sectors
    mov byte [db_file + 512], 0

    mov si, db_file
    call print_pm
    ret

.advance_line:
.skip_loop:
    mov al, [esi]
    cmp al, 0
    je .not_found
    cmp al, 0x0A
    je .next_start
    inc esi
    jmp .skip_loop

.next_start:
    inc esi
    mov ecx, esi
    jmp .next_line

.not_found:
    mov si, msg_file_not_found
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

flush_keyboard:
    mov dx, 0x64
.wait:
    in al, dx
    test al, 1
    jz .done
    in al, 0x60
    jmp .wait
.done:
    ret


read_input_pm:
    mov si, input_buffer
    xor bx, bx                      ; character count

.read_key:
    ; Lire une touche depuis le buffer IRQ
    call get_key_pm                 ; AL = caractère ou 0 si rien
    test al, al
    jz .read_key                    ; rien → attendre

    ; Gérer Enter (ASCII 0x0D)
    cmp al, 0x0D
    je .done

    ; Gérer Backspace (ASCII 0x08 si tu veux, ou tu peux mapper autrement)
    cmp al, 0x08
    je .backspace

    ; Stocker le caractère dans input_buffer
    mov [si], al
    inc si
    inc bx

    ; Préparer AX pour affichage
    mov ah, 0x07
    movzx eax, al
    or ax, 0x0700

    ; Calculer position dans text_buffer
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
    inc byte [cursor_col]
    call set_cursor_pm
    call redraw_screen
    jmp .read_key

.backspace:
    cmp bx, 0
    je .read_key
    dec bx
    dec si
    cmp byte [cursor_col], 0
    je .read_key
    dec byte [cursor_col]

    ; Effacer le caractère à l’écran
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

.done:
    ; Optionnel : null‑terminate input_buffer
    mov byte [si], 0
    ret

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
    ;mov byte [si], 0         ; Null-terminate input

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
    mov byte [cursor_col], 0
    mov byte [logical_cursor_row], 0
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


print_file_table_pm:
    mov esi, file_table_start      ; ESI = pointer to file table


    ; Calculate initial EDI position
    movzx eax, byte [logical_cursor_row]
    imul eax, 80                   ; 80 columns per row
    shl eax, 1                     ; 2 bytes per character
    mov edi, text_buffer
    add edi, eax

.next_char:
    lodsb                          ; Load next byte from [ESI] into AL
    test al, al
    jz .done                       ; End of table (null terminator)

    cmp al, '|'
    je .print_space

    cmp al, 0x0A
    je .newline

    ; Print regular character
    mov ah, 0x07                   ; White on black
    mov [edi], ax
    add edi, 2
    inc byte [cursor_col]
    jmp .next_char

.print_space:
    mov al, ' '
    mov ah, 0x07
    mov [edi], ax
    add edi, 2
    inc byte [cursor_col]
    jmp .next_char

.newline:
    inc byte [logical_cursor_row]
    mov byte [cursor_col], 0

    ; Recalculate EDI for new row
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    jmp .next_char

.done:
    ; Final EDI position based on row and col
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    add eax, [cursor_col]
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    ret




print_string_pm:
    push esi

.next_char:
    lodsb                      ; Load byte from [ESI] into AL
    test al, al                ; Check for null terminator
    jz .done

    cmp al, 0x0A               ; Newline?
    je .newline

    ; Write character to [EDI] with attribute
    mov ah, 0x07               ; Light gray on black
    mov [edi], ax              ; Write character and attribute
    add edi, 2                 ; Advance EDI by 2 bytes
    inc byte [cursor_col]      ; Advance column

    ; Check for column overflow
    cmp byte [cursor_col], 80
    jl .next_char              ; If still within line, continue

    ; Wrap to next line
    call .advance_line
    jmp .next_char

.newline:
    call .advance_line
    jmp .next_char

.advance_line:
    inc byte [logical_cursor_row]
    cmp byte [logical_cursor_row], 25
    jl .recalc_edi

    ; Wrap to top if row exceeds screen height
    mov byte [logical_cursor_row], 0

.recalc_edi:
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    mov byte [cursor_col], 0
    movzx ecx, byte [cursor_col]
    add eax, ecx
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    ret

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



; ----------------------------------------
; Data section (example)
; ----------------------------------------


section .data
align 512
%include "asm/data.asm"











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
db "  cmd:  -lss <list file>", 0x0A
db 0x0A
db "  cmd:  -cat <require file>", 0x0A
db 0x0A
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
file_length: dd 0
load_filename: db "hello.txt", 0
cmd_help_inline: db "-help", 0
cmd_ls_inline: db "-ls", 0
cmd_cat_inline: db "-cat", 0
msg_file_not_found:
db 0x0A
db "Error: File not found", 0x0A
db 0x0A
db 0
msg_lss_detected: db "LSS command detected", 0
db_file times 512 db 0x55   ; Fill 512 bytes with 0x55

shift_state db 0
ctrl_state  db 0
alt_state   db 0

keyboard_head db 0
keyboard_tail db 0
keyboard_buf  times 128 db 0

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
    db 0x08 ; 0x0E - Backspace (CORRIGÉ)
    db 0x09 ; 0x0F - Tab (CORRIGÉ)
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
    db 0x0D ; 0x1C - Enter (ASCII CR)
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

[BITS 32]

idt_start:
times 256*8 db 0          ; 256 entrées de 8 octets
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start
    
    
global isr_default

isr_default:
    cli
.hang:
    hlt
    jmp .hang
    
; void set_idt_entry(int num, uint32_t base, uint16_t sel, uint8_t flags)
; num  = eax
; base = edx
; sel  = bx
; flags = cl

set_idt_entry:
    push eax
    push edx
    push ebx
    push ecx

    mov edi, idt_start
    shl eax, 3              ; num * 8
    add edi, eax

    ; base low
    mov ax, dx
    mov [edi], ax

    ; selector
    mov [edi+2], bx

    ; zero
    mov byte [edi+4], 0

    ; flags
    mov [edi+5], cl

    ; base high
    shr edx, 16
    mov ax, dx
    mov [edi+6], ax

    pop ecx
    pop ebx
    pop edx
    pop eax
    ret
    
remap_pic:
    ; init
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    ; vecteurs de base
    mov al, 0x20        ; master -> 0x20–0x27
    out 0x21, al
    mov al, 0x28        ; slave -> 0x28–0x2F
    out 0xA1, al

    ; chaînage
    mov al, 0x04        ; master a un slave sur IRQ2
    out 0x21, al
    mov al, 0x02        ; slave est sur IRQ2
    out 0xA1, al

    ; mode 8086
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; unmask tout pour l’instant (tu pourras affiner)
    mov al, 0x00
    out 0x21, al
    out 0xA1, al
    ret
    
    
global isr_timer

isr_timer:
    ; EOI au PIC
    mov al, 0x20
    out 0x20, al
    iretd

install_timer_irq:
    ; Installer handler IRQ0 dans IDT[0x20]

    mov eax, 0x20            ; numéro d’entrée IDT
    mov edx, isr_timer       ; adresse du handler
    mov bx, CODE_SEG         ; segment code
    mov cl, 0x8E             ; present, ring0, 32-bit interrupt gate
    call set_idt_entry

    ; Configurer le PIT à 100 Hz (valeur standard)
    mov al, 0x36             ; Channel 0, lobyte/hibyte, mode 3
    out 0x43, al

    mov ax, 11932            ; 1193182 / 100 Hz ≈ 11932
    out 0x40, al             ; low byte
    mov al, ah
    out 0x40, al             ; high byte

    ret

install_keyboard_irq:
    mov eax, 0x21            ; IDT entry for IRQ1
    mov edx, isr_keyboard
    mov bx, CODE_SEG
    mov cl, 0x8E
    call set_idt_entry
    ret
    
global isr_keyboard

isr_keyboard:
    ; Lire scancode brut
    in al, 0x60
    mov bl, al

    ; Ignorer les releases (bit 7 = 1)
    test bl, 0x80
    jnz .eoi

    ; Gérer scancode étendu 0xE0
    cmp bl, 0xE0
    je .extended

    ; --- GESTION SHIFT ---
    cmp bl, 0x2A        ; Left Shift down
    je .shift_down
    cmp bl, 0x36        ; Right Shift down
    je .shift_down

    ; --- GESTION CTRL ---
    cmp bl, 0x1D        ; Ctrl down
    je .ctrl_down

    ; --- GESTION ALT ---
    cmp bl, 0x38        ; Alt down
    je .alt_down

    ; Convertir scancode → ASCII
    movzx ebx, bl
    mov al, [scancode_table + ebx]

    ; Si 0 → touche non gérée
    test al, al
    jz .eoi

    ; --- Appliquer SHIFT si lettre ---
    cmp byte [shift_state], 1
    jne .store_char

    cmp al, 'a'
    jb .store_char
    cmp al, 'z'
    ja .store_char
    sub al, 32          ; minuscule → majuscule

.store_char:
    ; Ajouter dans buffer circulaire
    movzx ecx, byte [keyboard_head]
    mov [keyboard_buf + ecx], al
    inc byte [keyboard_head]
    and byte [keyboard_head], 127

    jmp .eoi

; ============================
; TOUCHES ÉTENDUES (0xE0)
; ============================
.extended:
    in al, 0x60
    mov bl, al

    cmp bl, 0x4B
    je .arrow_left
    cmp bl, 0x4D
    je .arrow_right
    cmp bl, 0x48
    je .arrow_up
    cmp bl, 0x50
    je .arrow_down

    jmp .eoi

.arrow_left:
    mov al, 0x81        ; code spécial flèche gauche
    jmp .store_char

.arrow_right:
    mov al, 0x82
    jmp .store_char

.arrow_up:
    mov al, 0x83
    jmp .store_char

.arrow_down:
    mov al, 0x84
    jmp .store_char

; ============================
; TOUCHES DE MODIFICATEURS
; ============================
.shift_down:
    mov byte [shift_state], 1
    jmp .eoi

.ctrl_down:
    mov byte [ctrl_state], 1
    jmp .eoi

.alt_down:
    mov byte [alt_state], 1
    jmp .eoi

; ============================
; FIN D’INTERRUPTION
; ============================
.eoi:
    mov al, 0x20
    out 0x20, al
    iretd
    
    
      
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

