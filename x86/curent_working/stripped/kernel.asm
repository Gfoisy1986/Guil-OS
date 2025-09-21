[org 0x8000]            ; Kernel load address

;mov ah, 0x0E
;mov al, '!'
;int 0x10
;jmp $
buffer equ 0x90000
data_base equ buffer + 512 * 32

ReservedSectors     equ data_base + 0
NumberOfFATs        equ data_base + 2
FATSize32           equ data_base + 3
RootCluster         equ data_base + 7
SectorsPerCluster   equ data_base + 11
FATStartLBA         equ data_base + 12
DataStartLBA        equ data_base + 16
RootDirLBA          equ data_base + 20
AllocatedCluster    equ data_base + 24



[bits 16]
[default rel]

global protected_mode

start:


	
 

    ; Switch to 32-bit protected mode
    cli                     ; Disable interrupts
    lgdt [gdt_descriptor]   ; Load Global Descriptor Table
   
   
    mov eax, cr0
    or eax, 1               ; Set PE bit (bit 0) to enable protected mode
    mov cr0, eax
    
    

 
    jmp CODE_SEG:protected_mode  ; Far jump to flush pipeline



[BITS 32]
protected_mode:
  
    mov ax, [buffer + 0x0E]
	mov word [ReservedSectors], ax

	mov al, [buffer + 0x10]
	mov byte [NumberOfFATs], al

	mov eax, [buffer + 0x24]
	mov dword [FATSize32], eax

	mov eax, [buffer + 0x2C]
	mov dword [RootCluster], eax

	mov al, [buffer + 0x0D]
	mov byte [SectorsPerCluster], al

   
	mov eax, [RootCluster]
	sub eax, 2
	movzx ecx, byte [SectorsPerCluster]
	mul ecx
	add eax, [DataStartLBA]
	mov dword [RootDirLBA], eax

	mov eax, [RootCluster]
	mov dword [AllocatedCluster], eax


    

    call Clear_screen


.start_shell:

    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x9FF00       ; Stack top
   
	mov es, ax
	mov edi, buffer         ; buffer equ 0x90000
    
    mov esi, msg_pm
    call print_pm

    call read_input_pm
    call parse_command
    jmp .start_shell




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
    
    ; Check for "-wrt"   write a new file static for now
    
    mov esi, input_buffer
    mov edx, cmd_wrt_inline
    mov edi, edx
    mov ecx, 4
    call strncmp32
    cmp al, 1
    je .handler_wrt
    
   ;Read formula
;    DataRegionStart = PartitionStart + ReservedSectors + (NumberOfFATs × FATSize32)
;    RootDirLBA = DataRegionStart + ((RootCluster - 2) × SectorsPerCluster)

    
    
   


    ; Unknown command
    mov si, msg_unknown
    call print_pm
    jmp .advance_cursor




.handler_help:
	;call calculate_root_lba
	
	

   
    
  
	mov eax, 1         ; LBA 1 — first sector after boot
	mov ecx, 100      ; ~55 KB kernel
	mov edi, 0x8000     ; load address
	call read_sectors


	;mov eax, [RootDirLBA]
	;mov ecx, 1
	;mov edi, buffer
	;call read_sectors

   

	

    
    mov esi, msg_help
    call print_pm
    jmp .advance_cursor

.handler_ls:
    
    call list_files
    jmp .advance_cursor


.handler_wrt:
    
    call write_file
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

list_files:
    push esi
    push edi
    push eax
    push ecx
    push edx


	;call calculate_root_lba
	
	mov eax, [RootDirLBA]
	mov ecx, [FATSize32]
	mov edi, buffer
	call read_sectors


	
	
	
	
	


    mov esi, buffer
    xor ebx, ebx                  ; File counter

.loop:
    cmp byte [esi], 0x00          ; End of directory
    je .check_empty

    cmp byte [esi], 0xE5          ; Deleted entry
    je .next

    mov al, [esi + 0x0B]          ; DIR_Attr
    test al, 0x18       ; Skip volume label and directory
    jnz .next


    ; Valid file found
    inc ebx                       ; File counter++
    push esi
    mov edi, 0xB8000
	movzx eax, bx
	imul eax, 160         ; 80 chars × 2 bytes
	add edi, eax


    call print_filename
	mov ah, 0x0F
	mov al, 'F'
	mov [0xB8000], ax

    pop esi

.next:
    add esi, 32
    jmp .loop

.check_empty:
    cmp ebx, 0
    jne .done

    ; No files found
    mov esi, msg_no_files
    call print_pm

.done:
    pop edx
    pop ecx
    pop eax
    pop edi
    pop esi
    ret
    
    

write_sectors:
    ; Inputs:
    ;   EAX = starting LBA
    ;   ECX = number of sectors
    ;   ESI = source buffer (file data)

    pushad                     ; Save all general-purpose registers

.next_sector:
    ; Wait until disk is not busy (BSY = 0)
.wait_bsy:
    mov dx, 0x1F7
    in al, dx
    test al, 0x80
    jnz .wait_bsy

    ; Set sector count = 1
    mov dx, 0x1F2
    mov al, 1
    out dx, al

    ; Set LBA address
    mov ebx, eax               ; Copy LBA
    mov dx, 0x1F3
    mov al, bl
    out dx, al
    mov dx, 0x1F4
    mov al, bh
    out dx, al
    shr ebx, 16
    mov dx, 0x1F5
    mov al, bl
    out dx, al
    mov dx, 0x1F6
    mov al, bh
    and al, 0x0F
    or al, 0xE0                ; LBA mode + master drive
    out dx, al

    ; Issue WRITE SECTORS command (0x30)
    mov dx, 0x1F7
    mov al, 0x30
    out dx, al

    ; Wait for DRQ (bit 3) with timeout
    mov cx, 10000
.wait_drq:
    mov dx, 0x1F7
    in al, dx
    test al, 0x08
    jnz .drq_ready
    loop .wait_drq
    jmp .error

.drq_ready:
    ; Write 256 words (512 bytes)
    mov cx, 256
    mov dx, 0x1F0
.write_loop:
    lodsw                     ; Load word from [ESI] into AX
    out dx, ax                ; Write word to disk
    loop .write_loop

    ; Advance to next sector
    inc eax                   ; Next LBA
    add esi, 512              ; Advance buffer
    dec ecx
    jnz .next_sector

.done:
    popad
    ret

.error:
    ; Optional: show error marker
    mov ah, 0x0C
    mov al, 'W'
    mov [0xB8000], ax
    jmp $





write_file:
    pushad

    ; Step 1: Read FAT and find a free cluster
    mov eax, [FATStartLBA]
    mov ecx, [FATSize32]
    mov edi, buffer
    call read_sectors

    mov esi, msg_help ;buffer
    ;xor ebx, ebx               ; Cluster index
		
	
	
    call print_pm
    ret
.find_free_cluster:
    mov eax, [esi]
    cmp eax, 0x00000000
    je .cluster_found
    add esi, 4
    inc ebx
    cmp ebx, 0x0FFFFFF0
    jl .find_free_cluster
    jmp .no_free_cluster

.cluster_found:
    mov [AllocatedCluster], ebx

    ; Step 2: Write file data to allocated cluster
    mov eax, ebx               ; AllocatedCluster
    sub eax, 2
    movzx edx, byte [SectorsPerCluster]
    imul eax, edx
    add eax, [DataStartLBA]
    mov ecx, edx
    mov edi, file_buffer
    call write_sectors

    ; Step 3: Update FAT entry to mark cluster as EOF
    mov eax, [AllocatedCluster]
    shl eax, 2                 ; FAT32 entry = cluster × 4
    mov esi, buffer
    add esi, eax
    mov dword [esi], 0x0FFFFFFF

    ; Step 4: Write updated FAT to all copies
    mov eax, [FATStartLBA]
    movzx ebx, byte [NumberOfFATs]
    
    mov ah, 0x0F
	mov al, 'C'
	mov [0xB8000], ax

.write_fat_copies:
    mov ecx, [FATSize32]
    mov esi, buffer
    call write_sectors
    add eax, ecx
    dec ebx
    jnz .write_fat_copies

    ; Step 5: Add directory entry
    mov eax, [RootDirLBA]
    movzx ecx, byte [SectorsPerCluster]
    mov edi, buffer
    call read_sectors

    mov esi, buffer
.find_dir_slot:
    cmp byte [esi], 0x00
    je .write_dir_entry
    cmp byte [esi], 0xE5
    je .write_dir_entry
    add esi, 32
    jmp .find_dir_slot

.write_dir_entry:
    ; Copy filename (11 bytes)
    mov edi, filename
    mov ecx, 11
.copy_name_loop:
    mov al, [edi]
    mov [esi], al
    inc edi
    inc esi
    loop .copy_name_loop

    ; Set archive attribute
    mov byte [esi], 0x20
    add esi, 9                 ; Move to offset 20

    ; Write cluster number
    mov ax, [AllocatedCluster]
    mov [esi], ax             ; Cluster low
    add esi, 2
    shr eax, 16
    mov [esi], ax             ; Cluster high
    add esi, 2

    ; Write file size
    mov eax, [FileSize]
    mov [esi], eax

    ; Write updated directory entry
    mov eax, [RootDirLBA]
    movzx ecx, byte [SectorsPerCluster]
    mov esi, buffer
    call write_sectors

.no_free_cluster:
    popad
    ret






dump_buffer_to_vga:
    mov esi, buffer          ; Source: FAT32 buffer
    mov edi, 0xB8000         ; VGA text memory
    mov ecx, 512             ; Number of bytes to display

.dump_loop:
    mov al, [esi]            ; Load byte
    cmp al, 0x20             ; Is it printable?
    jb .dot
    cmp al, 0x7E             ; Is it <= '~'?
    ja .dot

    mov ah, 0x07             ; Attribute: light gray on black
    mov [edi], ax
    jmp .next

.dot:
    mov ax, 0x072E           ; '.' character with attribute
    mov [edi], ax

.next:
    add edi, 2               ; Advance VGA memory
    inc esi
    loop .dump_loop
    ret



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




read_sectors:
    ; Inputs: EAX = starting LBA, ECX = number of sectors, EDI = buffer
    ; Output: read_status = 0 (success), 1 (error)

    pushad

    mov byte [read_status], 0         ; Assume success

.next_sector:
    ; Wait for BSY to clear
    mov dx, 0x1F7
    mov si, 10000
.wait_bsy:
    in al, dx
    test al, 0x80                     ; BSY bit
    jz .bsy_clear
    dec si
    jnz .wait_bsy

    ; BSY timeout
    mov esi, msg_error_bsy
    call print_pm
    mov byte [read_status], 1
    jmp .fail

.bsy_clear:
    ; Set sector count to 1
    mov dx, 0x1F2
    mov al, 1
    out dx, al
    jmp $+2

    ; Send LBA (28-bit)
    mov ebx, eax                      ; Copy LBA
    mov dx, 0x1F3
    mov al, bl
    out dx, al
    mov dx, 0x1F4
    mov al, bh
    out dx, al
    shr ebx, 16
    mov dx, 0x1F5
    mov al, bl
    out dx, al
    mov dx, 0x1F6
    mov al, bh
    and al, 0x0F                      ; Mask upper 4 bits
    or al, 0xE0                       ; Set LBA mode + drive 0
    out dx, al

    ; Issue READ SECTORS command
    mov dx, 0x1F7
    mov al, 0x20
    out dx, al

    ; Wait for DRQ to set
    mov si, 10000
.wait_drq:
    mov dx, 0x1F7
    in al, dx
    test al, 0x08
    jnz .drq_ready
    dec si
    jnz .wait_drq


.drq_ready:
    ; Read 512 bytes (256 words)
    mov cx, 256

.read_loop:
    mov dx, 0x1F0
	in ax, dx
	stosw

    loop .read_loop


    ; Advance to next sector
    inc eax                           ; Next LBA
    add edi, 512                      ; Next buffer offset
    dec ecx
    jnz .next_sector

    mov esi, msg_read_done
    call print_pm
    jmp .done

.fail:
    mov ah, 0x0E
    mov al, 'F'
    int 0x10
    mov esi, msg_read_failed
    call print_pm
    mov byte [read_status], 1
    ret


.done:
    popad
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
print_filename:
    push esi
    push edi
    push ecx
    push ax

    mov ecx, 11              ; FAT32 filename is 11 bytes (8 + 3)
.print_loop:
    mov al, [esi]            ; Load character from filename
    cmp al, 0x20             ; Optional: skip leading spaces
    jb .skip_char
    mov ah, 0x0F             ; White on black
    stosw                    ; Write to VGA
.skip_char:
    inc esi
    loop .print_loop

    pop ax
    pop ecx
    pop edi
    pop esi
    ret



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


;--------------------------------------------------------------------
calculate_root_lba:
    ; Step 1: Calculate DataStartLBA
    mov eax, [FATSize32]
    movzx ebx, byte [NumberOfFATs]
    imul eax, ebx                 ; eax = FATSize32 × NumberOfFATs
    add eax, [ReservedSectors]   ; eax = Reserved + FATs
    add eax, [PartitionStart]    ; eax = DataStartLBA

    ; Step 2: Calculate RootDirLBA
    movzx ebx, byte [SectorsPerCluster]
    mov ecx, [RootCluster]
    sub ecx, 2
    imul ecx, ebx                 ; ecx = (RootCluster - 2) × SectorsPerCluster
    add eax, ecx                  ; eax = RootDirLBA

    mov [RootDirLBA], eax
    ret


    


section .data 








; ----------------------------------------
; Data section (example)
; ----------------------------------------

PartitionStart dd 204800








msg_pm: db "ADMIN @ Guil-OS: ", 0
text_buffer: times 8000 dw 0x0720


scroll_offset db 0                   ; Current top line index
screen_dirty db 1
logical_cursor_row db 0   ; Tracks actual row in the full buffer
current_input:   times 128 db 0           ; Buffer d’entrée courant
cursor_row db 0
cursor_col db 0
input_buffer times 512 db 0



read_status: db 0    ; 0 = success, 1 = error


FileSize            dd 11
filename            db 'HELLO   TXT'      ; 11 bytes, 8.3 format
file_buffer         times 512 db 'hello world', 0


msg_error_bsy:     db "ERROR: Disk BSY timeout", 0
msg_error_drq:     db "ERROR: Disk DRQ timeout", 0
msg_read_failed:   db "ERROR: Read failed", 0
msg_read_done:     db "Read complete", 0


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

file_length: dd 0

cmd_help_inline: db "-help", 0
cmd_ls_inline:   db "-ls", 0
cmd_cat_inline: db "-cat", 0
cmd_wrt_inline: db "-wrt", 0
cmd_ctt: db "-ctt", 0
cmd_ls_create: db "-crt", 0
msg_file_not_found:
db 0x0A
db "Error: File not found", 0x0A
db 0x0A
db 0
msg_no_files:
    db 0x0A
    db "No files on disk", 0x0A
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

align 16
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

