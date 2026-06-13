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



    lidt [idt_descriptor]

    call remap_pic
    call install_timer_irq
    call install_keyboard_irq
    sti

    ; puis ton shell :
     jmp .start_shell


.start_shell:
    
    call Clear_screen
    

    mov esi, msg_help
    call print_pm

    call clear_keyboard_buffer
    call clear_input_line
   
	

    
    ; place cursor after prompt
    mov byte [cursor_row], 24
    mov byte [cursor_col], 0   ; adjust to real prompt length
    call set_cursor_input_pm
    
    call read_input_pm           ; read user input on row 24

    call newline_pm              ; add newline to scroll area
   
    
    call parse_command           ; execute command
    call wait_for_enter
    jmp .start_shell






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

    mov esi, input_buffer
    
    mov edx, cmd_ls_inline
    mov edi, edx
    mov ecx, 3
    call strncmp32
    cmp al, 1
    je .handler_ls


      ; Check for "-cat"

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
   
    
    
    
    call newline_pm
    mov esi, file_table_start
    call print_pm
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
    call get_key_pm              ; AL = ASCII, BL = scancode
    test bl, bl
    jz .wait

    ; ----------------------------
    ; ENTER
    ; ----------------------------
    cmp bl, 0x1C
    je .enter
    
.enter:

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


; ============================================================
; read_sectors_ata_pm
; EAX = LBA (28-bit)
; ECX = number of sectors
; EDI = destination buffer
; ============================================================

read_sectors_ata_pm:
    pushad

.next_sector:
    ; ----------------------------
    ; 1) Sector count
    ; ----------------------------
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; ----------------------------
    ; 2) LBA low byte
    ; ----------------------------
    mov dx, 0x1F3
    mov al, al            ; AL = LBA[7:0]
    out dx, al

    ; ----------------------------
    ; 3) LBA mid byte
    ; ----------------------------
    mov dx, 0x1F4
    mov al, ah            ; AH = LBA[15:8]
    out dx, al

    ; ----------------------------
    ; 4) LBA high byte
    ; ----------------------------
    mov dx, 0x1F5
    shr eax, 16
    mov al, al            ; AL = LBA[23:16]
    out dx, al

    ; ----------------------------
    ; 5) Drive + LBA bits 24–27
    ; ----------------------------
    mov dx, 0x1F6
    mov al, 0xE0          ; 0xE0 = LBA mode + master
    or  al, ah            ; AH = LBA[27:24]
    out dx, al

    ; ----------------------------
    ; 6) Command: READ SECTORS (0x20)
    ; ----------------------------
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

.wait_drq:
    in al, dx
    test al, 8            ; DRQ set?
    jz .wait_drq

    ; ----------------------------
    ; 7) Read 512 bytes = 256 words
    ; ----------------------------
    mov dx, 0x1F0
    mov ebx, 256

.read_word:
    in ax, dx
    mov [edi], ax
    add edi, 2
    dec ebx
    jnz .read_word

    ; Next sector?
    dec ecx
    jnz .next_sector

    popad
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
    ; EDI = command string
    ; ECX = number of chars to compare

.loop:
    cmp ecx, 0
    je .equal

    mov al, [esi]
    test al, al
    jz .not_equal        ; input shorter than expected

    mov bl, [edi]
    cmp al, bl
    jne .not_equal

    inc esi
    inc edi
    dec ecx
    jmp .loop

.not_equal:
    xor al, al
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
    mov ebx, esi                   ; EBX = pointer to filename (input)

.next_line:
    mov esi, ecx                   ; ESI = start of current line
    mov edi, ebx                   ; EDI = filename pointer

.compare_loop:
    mov al, [esi]

    cmp al, 0
    je .not_found

    cmp al, 0x0A
    je .advance_line

    cmp al, '|'
    je .match_check

    mov dl, [edi]
    cmp dl, al
    jne .advance_line

    inc esi
    inc edi
    jmp .compare_loop

.match_check:
    mov dl, [edi]
    cmp dl, 0
    jne .advance_line

    ; -----------------------------------------
    ; ICI : ESI pointe sur le '|' de la bonne ligne
    ; -----------------------------------------

    inc esi              ; maintenant ESI pointe sur le premier chiffre
    call parse_number    ; EAX = numéro de secteur

    ; -----------------------------------------
    ; Conversion secteur → adresse RAM
    ; -----------------------------------------

    mov ebx, 0x00008000        ; base RAM des 128 secteurs
    sub eax, 2                 ; secteur 2 = offset 0
    imul eax, eax, 512         ; offset = (S - 2) * 512
    add eax, ebx               ; adresse RAM du secteur S

    mov esi, eax               ; adresse RAM du secteur
	mov byte [esi + 511], 0    ; termine la string
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
    mov esi, msg_file_not_found
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
    cmp al, 0x7F          ; Set 2 max useful range
    ja  .unknown

    movzx ebx, al
    mov   al, [scancode_table + ebx]
    ret

.unknown:
    xor al, al
    ret

clear_input_buffer:
    mov edi, input_buffer   ; effacer avec EDI (32 bits)
    mov ecx, 128
    xor eax, eax
    rep stosb

    mov esi, input_buffer   ; ← IMPORTANT : remettre ESI au début
    xor bx, bx              ; compteur de caractères
    ret


clear_input_line:
    movzx ecx, byte [logical_cursor_row]
    imul ecx, 80
    mov edi, text_buffer
    shl ecx, 1
    add edi, ecx
    mov ax, 0x0720        ; ' ' avec attribut
    mov cx, 80
.clear_loop:
    stosw
    loop .clear_loop
    ret
    

; ---------------------------------------------------------
; read_input_pm
; Reads user input on fixed bottom line (row 24)
; Uses:
;   input_buffer   = typed characters
;   input_len      = number of characters typed
; ---------------------------------------------------------

read_input_pm:

    mov esi, input_buffer
    xor ebx, ebx                 ; EBX = input_len
    

.loop:
.wait_key:
    call get_key_pm              ; AL = ASCII, BL = scancode
    test bl, bl
    jz .wait_key

    ; ----------------------------
    ; ENTER
    ; ----------------------------
    cmp bl, 0x1C
    je .enter

    ; ----------------------------
    ; BACKSPACE
    ; ----------------------------
    cmp bl, 0x0E
    je .backspace

    ; ----------------------------
    ; PRINTABLE ASCII
    ; ----------------------------
    cmp al, 0x20
    jb .loop
    cmp al, 0x7F
    jae .loop

    ; store character
	mov [esi], al
	inc esi
	inc ebx
    mov byte [cursor_col], 18
	mov byte [esi], 0
    call print_pm
	
	jmp .loop


; ----------------------------
; BACKSPACE
; ----------------------------
.backspace:
    dec ebx
	dec esi
	mov byte [esi], 0
	;mov byte [input_len], bl      ; ✔ update length

	call draw_input_line_pm
	call set_cursor_input_pm
	call redraw_screen
	jmp .loop


; ----------------------------
; ENTER
; ----------------------------
.enter:
   
	mov byte [esi], 0
	mov esi, input_buffer
	call print_pm
	ret


print_string_char_pm:
    ; ESI = pointeur vers la string
.next:
    mov al, [esi]
    test al, al
    jz .done

    call print_char_pm

    inc esi
    jmp .next

.done:
    ret
    
    
print_char_pm:
    ; AL = caractère ASCII
    ; utilise logical_cursor_row et cursor_col

    push eax
    push edi

    ; calcul adresse dans text_buffer
    movzx eax, byte [logical_cursor_row]
    imul eax, 80
    movzx edi, byte [cursor_col]
    add eax, edi
    shl eax, 1
    mov edi, [text_buffer]
    add edi, eax

    mov ah, 0x07        ; attribut
    mov [edi], ax       ; écrire caractère + attribut

    ; avancer le curseur
    inc byte [cursor_col]
    cmp byte [cursor_col], 80
    jb .done

    mov byte [cursor_col], 18
    inc byte [logical_cursor_row]

.done:
    pop edi
    pop eax
    ret
    
    
; check_auto_scroll
check_auto_scroll:
    movzx eax, word [logical_cursor_row]
    movzx ecx, word [scroll_offset]
    sub eax, ecx
    cmp eax, 24
    jb .no_scroll

    inc word [scroll_offset]
    mov byte [screen_dirty], 1
    call redraw_screen
.no_scroll:
    ret

set_cursor_input_pm:
    ; cursor_row = 24
    mov al, 24
    mov [cursor_row], al

    ; cursor_col = 18 + input_len
    movzx eax, byte [input_len]
    add al, 0
    mov [cursor_col], al

    ; compute VGA offset = row*80 + col
    movzx eax, byte [cursor_row]
    imul eax, 80
    movzx edx, byte [cursor_col]
    add eax, edx
    mov bx, ax

    ; send high byte
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    mov al, bh
    out dx, al

    ; send low byte
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    mov al, bl
    out dx, al

    ret
    
; set_cursor_pm
set_cursor_pm:
    movzx eax, word [logical_cursor_row]
    movzx ecx, word [scroll_offset]
    sub eax, ecx

    cmp eax, 24
    jae .skip_cursor_update

    imul eax, 80
    movzx edx, byte [cursor_col]
    add eax, edx
    mov bx, ax
    ; ... same as you had ...
.skip_cursor_update:
    ret




Clear_screen:
    ; Clear VRAM
    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

    ; Clear logical buffer
    mov edi, text_buffer
    mov ax, 0x0720
    mov ecx, 80 * 25
    rep stosw

    ; Reset state
    mov byte [cursor_col], 0
    mov word [logical_cursor_row], 0
    mov word [scroll_offset], 0
    mov byte [screen_dirty], 1

    call redraw_screen
    ret

redraw_screen:
    cmp byte [screen_dirty], 0
    je .skip_redraw

    mov byte [screen_dirty], 0

    push esi
    push edi
    push ecx
    push eax

    ; ---------------------------------------------------------
    ; Draw scrollable region (rows 0–23)
    ; ---------------------------------------------------------
    movzx eax, byte [scroll_offset]
    imul eax, 160                  ; 80 chars * 2 bytes
    mov esi, text_buffer
    add esi, eax                   ; ESI = start of visible buffer

    mov edi, 0xB8000               ; Video memory
    mov ecx, 24                    ; 24 scrollable lines

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

    ; ---------------------------------------------------------
    ; Draw scrollbar (still 25 rows tall)
    ; ---------------------------------------------------------
    call draw_scrollbar

    ; ---------------------------------------------------------
    ; Draw input line at row 24 (bottom)
    ; ---------------------------------------------------------
    mov edi, 0xB8000
    add edi, 24 * 160              ; row 24 start

    mov esi, input_buffer
    mov ecx, 80

.draw_input:
    lodsb
    test al, al
    jz .fill_rest
    mov ah, 0x07
    stosw
    loop .draw_input

.fill_rest:
    mov ax, 0x0720
.fill_loop:
    stosw
    loop .fill_loop

    ; ---------------------------------------------------------
    ; Restore registers and exit
    ; ---------------------------------------------------------
    pop eax
    pop ecx
    pop edi
    pop esi

.skip_redraw:
    ret


draw_scrollbar:
    mov edi, 0xB8000
    add edi, 79 * 2                 ; Last column
    mov ecx, 24

.draw_line:
    mov ax, 0x0720                  ; Light gray space
    stosw
    add edi, (80 - 1) * 2           ; Move to next line's last column
    loop .draw_line

    ; Draw thumb
    movzx eax, byte [scroll_offset]
    mov bl, 100 - 24                ; Max scroll
    mul bl
    mov bl, 24         ; divisor
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
print_pm:
    push esi

    movzx eax, word [logical_cursor_row]
    movzx ecx, word [scroll_offset]
    sub eax, ecx
    imul eax, 80
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    mov ah, 0x07
    call print_string_pm
    call update_cursor_row
    call set_cursor_pm
    mov byte [screen_dirty], 1
    call redraw_screen
    pop esi
    ret



; ---------------------------------------------------------
; draw_input_line_pm
; Draws the shell prompt + input buffer on visible row 24
; ---------------------------------------------------------
; Requires:
;   msg_pm        = prompt string ("admin @ Guil-OS : ")
;   input_buffer  = user-typed characters
;   input_len     = number of characters in input_buffer
; ---------------------------------------------------------

draw_input_line_pm:

    ; --- Set EDI to row 24 in VGA memory ---
    mov edi, 0xB8000
    add edi, 24 * 160          ; row 24 start (80*2 bytes)

    ; --- Draw prompt ---
    mov esi, msg_pm
.draw_prompt:
    lodsb
    test al, al
    jz .after_prompt
    mov ah, 0x07
    stosw
    jmp .draw_prompt

.after_prompt:

    ; --- Draw input buffer ---
    mov esi, input_buffer
    movzx ecx, byte [input_len]

.draw_input:
    test ecx, ecx
    jz .fill_rest
    lodsb
    mov ah, 0x07
    stosw
    dec ecx
    jmp .draw_input

.fill_rest:
    ; --- Fill the rest of the line with spaces ---
    mov ax, 0x0720

    mov ecx, 80                ; total columns
    sub ecx, 18               ; prompt length
    movzx edx, byte [input_len]
    sub ecx, edx               ; subtract input length

.fill_loop:
    stosw
    loop .fill_loop

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
    push esi                        ; sauvegarde du pointeur de chaîne

.next_char:
    lodsb                           ; AL = prochain caractère, ESI++
    test al, al                     ; fin de chaîne (AL = 0) ?
    jz .done                        ; oui → sortir

    cmp al, 0x0A                    ; '\n' ?
    je .newline                     ; oui → aller à la ligne

    ; --- écrire caractère dans text_buffer ---
    mov ah, 0x07                    ; attribut (gris sur noir)
    mov [edi], ax                   ; écrire caractère + attribut
    add edi, 2                      ; avancer d'une cellule (2 octets)
    inc byte [cursor_col]           ; avancer la colonne logique

    cmp byte [cursor_col], 80       ; fin de ligne ?
    jl .next_char                   ; non → continuer

    ; --- fin de ligne → passer à la suivante ---
    call .advance_line
    jmp .next_char

.newline:
    ; --- gestion explicite du '\n' ---
    call .advance_line
    jmp .next_char

.advance_line:
    inc byte [logical_cursor_row]   ; avancer la ligne logique

    ; --- scroll si nécessaire ---
    call check_auto_scroll          ; peut modifier scroll_offset

    ; --- calculer la ligne visible = logical - scroll_offset ---
    movzx eax, byte [logical_cursor_row]
    movzx ecx, byte [scroll_offset]
    sub eax, ecx                    ; EAX = ligne visible

    ; --- convertir en offset dans text_buffer ---
    imul eax, 80                    ; ligne * 80 colonnes
    shl eax, 1                      ; *2 (caractère + attribut)

    mov edi, text_buffer            ; base du buffer texte
    add edi, eax                    ; EDI = nouvelle position d'écriture

    mov byte [cursor_col], 0        ; retour colonne = 0
    ret

.done:
    pop esi                         ; restaurer ESI
    ret


update_cursor_row:
    movzx eax, word [logical_cursor_row]
    movzx ecx, word [scroll_offset]
    sub eax, ecx
    cmp eax, 24
    jae .offscreen
    mov [cursor_row], al
    ret
.offscreen:
    mov byte [cursor_row], 24
    ret


newline_pm:
    inc word [logical_cursor_row]
    mov byte [cursor_col], 0

    call check_auto_scroll

    movzx eax, word [logical_cursor_row]
    movzx ecx, word [scroll_offset]
    sub eax, ecx
    imul eax, 80
    shl eax, 1
    mov edi, text_buffer
    add edi, eax
    ret



; ----------------------------------------
; Data section (example)
; ----------------------------------------


section .data
align 512

file_table_start:
    db "elie|124", 0x0A
    db "gui|125", 0x0A
    db "hello|126", 0x0A
    db "humm|127", 0x0A
    db 0



dap_packet:
    db 0x10
    db 0
dap_count:
    dw 0
dap_buffer:
    dd 0
dap_lba:
    dq 0






msg_pm1: db "press enter to open shell", 0
msg_pm: db "ADMIN @ Guil-OS: ", 0
text_buffer: times 8000 dw 0x0720

logical_cursor_row  dw 0
scroll_offset       dw 0
cursor_row          db 0
cursor_col          db 0



;scroll_offset db 0                   ; Current top line index
screen_dirty db 1
;logical_cursor_row db 0   ; Tracks actual row in the full buffer
current_input:   times 128 db 0           ; Buffer d’entrée courant
;cursor_row db 0
;cursor_col db 0
input_buffer times 512 db 0
input_len db 0   
msg_help:
db 0x0A
db "  cmd:  -help <list command>", 0x0A
db 0x0A
db "  cmd:  -ls <list file>", 0x0A
db 0x0A
db "  cmd:  -cat 'filename' <print specified file>", 0x0A
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

keyboard_buf:
    times 128 db 0      ; ASCII
keyboard_buf_sc:
    times 128 db 0      ; scancode
keyboard_head: db 0
keyboard_tail: db 0

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
    ; 00–0F
    db 0,  0x1B,0x31,0x32,0x33,0x34,0x35,0x36
    db 0x37,0x38,0x39,0x30,0x2D,0x3D,0x08,0x09

    ; 10–1F
    db 0x71,0x77,0x65,0x72,0x74,0x79,0x75,0x69
    db 0x6F,0x70,0x5B,0x5D,0x0D,0,    0x61,0x73

    ; 20–2F
    db 0x64,0x66,0x67,0x68,0x6A,0x6B,0x6C,0x3B
    db 0x27,0x60,0,    0x5C,0x7A,0x78,0x63,0x76

    ; 30–3F
    db 0x62,0x6E,0x6D,0x2C,0x2E,0x2F,0,    0x2A
    db 0,    0x20,0,    0,    0,    0,    0,    0

    ; 40–7F
    times 64 db 0


scancode_shifted:
    ; 00–0F
    db 0,  0x1B,0x21,0x40,0x23,0x24,0x25,0x5E
    db 0x26,0x2A,0x28,0x29,0x5F,0x2B,0x08,0x09

    ; 10–1F
    db 0x51,0x57,0x45,0x52,0x54,0x59,0x55,0x49
    db 0x4F,0x50,0x7B,0x7D,0x0D,0,    0x41,0x53

    ; 20–2F
    db 0x44,0x46,0x47,0x48,0x4A,0x4B,0x4C,0x3A
    db 0x22,0x7E,0,    0x7C,0x5A,0x58,0x43,0x56

    ; 30–3F
    db 0x42,0x4E,0x4D,0x3C,0x3E,0x3F,0,    0x2A
    db 0,    0x20,0,    0,    0,    0,    0,    0

    ; 40–7F
    times 64 db 0

    
[BITS 32]

idt_start:
times 256*8 db 0          ; 256 entrées de 8 octets
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start
    
    
global isr_default
global isr_keyboard
global isr_timer

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
.init_idt_loop:
    mov edx, isr_default    ; base
    mov bx, CODE_SEG        ; selector
    mov cl, 0x8E            ; present, ring0, 32-bit interrupt gate
    call set_idt_entry

    inc eax
    loop .init_idt_loop
    
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
    ; --- Étape 1 : Initialisation (ICW1) ---
    ; 0x11 = démarrage + mode cascade + ICW4 suivra
    mov al, 0x11
    out 0x20, al        ; PIC maître
    out 0xA0, al        ; PIC esclave

    ; --- Étape 2 : Définir les vecteurs d'interruptions (ICW2) ---
    ; Le PIC maître enverra IRQ0–7 sur INT 0x20–0x27
    mov al, 0x20
    out 0x21, al

    ; Le PIC esclave enverra IRQ8–15 sur INT 0x28–0x2F
    mov al, 0x28
    out 0xA1, al

    ; --- Étape 3 : Chaînage maître/esclave (ICW3) ---
    ; Le maître a un esclave connecté sur IRQ2 → bit 2 = 1 → 0x04
    mov al, 0x04
    out 0x21, al

    ; L’esclave est connecté sur la ligne IRQ2 du maître → valeur = 2
    mov al, 0x02
    out 0xA1, al

    ; --- Étape 4 : Mode 8086/88 (ICW4) ---
    ; 0x01 = mode processeur 8086 (obligatoire pour OS modernes)
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; --- Étape 5 : Masques d'interruptions (OCW1) ---
    ; 0x00 = tout démasquer (autoriser toutes les IRQ)
    ; Tu pourras remasquer plus tard (timer, clavier, etc.)
    mov al, 0x00
    out 0x21, al        ; masque maître
    out 0xA1, al        ; masque esclave

    ret
    
    


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
    


; ============================================================
; IRQ1 - Keyboard ISR (Set 1, US, ASCII only)
; ============================================================

isr_keyboard:
    pushad

    ; Lire scancode brut (Set 1)
    in   al, 0x60
    mov  bl, al                ; garder scancode

    ; Ignorer break codes (bit 7 = 1)
    test bl, 0x80
    jnz  .eoi

    ; Ignorer codes hors plage
    cmp bl, 0x58               ; max Set 1 = 0x58
    ja  .eoi

    ; Conversion ASCII (non-shift)
    movzx ebx, bl
    mov   al, [scancode_table + ebx]

    ; SHIFT actif ?
    cmp byte [shift_state], 0
    je  .store

    ; SHIFTED ASCII
    movzx ebx, bl
    mov   al, [scancode_shifted + ebx]
    
    
    
.store:
    ; Stockage ASCII + SCANCODE dans buffer circulaire
    movzx ecx, byte [keyboard_head]
    mov [keyboard_buf + ecx], al
    mov [keyboard_buf_sc + ecx], bl

    inc cl
    and cl, 0x7F
    mov [keyboard_head], cl
    
    

.eoi:
    mov al, 0x20
    out 0x20, al
    popad
    iretd



    
; ============================================================
; get_key_pm
; Sorties :
;   AL = ASCII (0 si non imprimable)
;   BL = scancode brut (toujours utile)
; ============================================================
; ------------------------------------------------------------
; get_key_pm (final fortified)
;  AL = ASCII imprimable ou 0
;  BL = scancode make (0 si aucune touche)
; ------------------------------------------------------------
; AL = ASCII ou 0 si aucune touche
; BL = 0 (tu pourras plus tard y mettre un scancode si tu stockes ça aussi)
; AL = ASCII (0 si aucune touche)
; BL = scancode (0 si aucune touche)
get_key_pm:
    movzx eax, byte [keyboard_head]
    movzx ecx, byte [keyboard_tail]

    cmp eax, ecx
    je .no_key

    mov al, [keyboard_buf + ecx]   ; ASCII
    mov bl, [keyboard_buf_sc    + ecx]   ; SCANCODE

    inc cl
    and cl, 0x7F
    mov [keyboard_tail], cl
    
    ret

.no_key:
    xor al, al
    xor bl, bl
    ret


clear_keyboard_buffer:
    mov byte [keyboard_head], 0
    mov byte [keyboard_tail], 0
    ret
    
         
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

