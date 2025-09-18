[bits 16]
org 0x7C00

start:
    

    ; Setup stack and segments
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Print welcome message
    mov si, msg
    call print_string

    ; Step 1: Read boot sector
    call read_sector

    ; Step 2: Parse BPB
    call parse_bpb

    ; Step 3: Read FAT table into memory
    call read_fat_table
    call combine_32bit
    ; Step 4: Load STAGE2.BIN by cluster chain
    mov ax, [root_cluster]      ; start cluster
.next_cluster:
    call cluster_to_sector      ; convert to sector
    call read_sector            ; read into memory (e.g., 0x1000)
    call get_next_cluster       ; get next cluster from FAT
    cmp ax, 0xFFFF              ; end of chain?
    je .done
    jmp .next_cluster

.done:

    jmp 0x0000:0x1000
    ; jump to second-stage bootloader




; Input: AX = current cluster number
; Output: AX = next cluster number

get_next_cluster:
    push bx
    push cx
    push dx

    mov bx, ax           ; EBX = cluster number
    shl bx, 2              ; FAT32 = 4 bytes per entry

    mov si, 0x0800          ; FAT loaded here
    add si, bx              ; SI = address of FAT entry

    mov ax, [si]            ; low word
    mov dx, [si + 2]        ; high word
    ; combine into 32-bit value
    ; (you can use EAX if you're in 32-bit mode later)

    ; check for end-of-chain
    cmp ax, 0xFFF8
    jae .end_of_chain

    pop dx
    pop cx
    pop bx
    ret

.end_of_chain:
    mov ax, 0xFFFF          ; signal end
    pop dx
    pop cx
    pop bx
    ret

combine_32bit:
    mov ax, [sectors_per_fat_low]
    mov dx, [sectors_per_fat_high]
    ; Now DX:AX = full 32-bit value
    ; You can store it in a 32-bit register if switching to 32-bit mode
    ret

; Input: AX = sector number
;        BX = buffer address
read_sector:
    push ax
    push bx

    ; Convert LBA to CHS (simplified for small disks)
    mov dx, ax
    mov cx, dx
    and cx, 0x3F                ; Sector = bits 0–5
    mov ah, 0x02        ; BIOS function: read sectors
    ; Before calling read_sector:
    mov al, 0x58        ; or however many sectors you want


    mov ch, 0x00        ; Cylinder
    mov cl, 0x02        ; Sector (starts at 1, so 2 = second sector)
    mov dh, 0x00        ; Head
    mov dl, 0x80        ; First hard disk
    mov bx, 0x1000      ; Load STAGE2.BIN at 0x0000


    int 0x13

    jc print_error      ; Jump if carry flag set (error)


    pop bx
    pop ax
    ret

read_fat_table:
    mov ax, [reserved_sectors]  ; FAT starts after reserved sectors
    mov cx, [sectors_per_fat]   ; Number of sectors to read
    mov bx, 0x0800              ; Destination buffer

.read_loop:
    push ax
    call read_sector            ; Read sector AX into BX
    pop ax
    inc ax
    add bx, 512                 ; Next buffer position
    loop .read_loop
    ret



; Inputs:
;   AX = cluster number
; Outputs:
;   AX = sector number

cluster_to_sector:
    push bx
    push cx
    push dx

    ; Step 1: Calculate (cluster - 2) * sectors_per_cluster
    sub ax, 2
    mov cx, [sectors_per_cluster]
    mul cx                  ; AX = offset from data start

    mov bx, ax              ; Save offset in BX

    ; Step 2: Calculate FirstDataSector = reserved + (num_fats × sectors_per_fat)
    mov ax, [sectors_per_fat]
    mov cx, 0               ; clear CX
    mov cl, [num_fats]
    mul cx                 ; AX = num_fats * sectors_per_fat

    add ax, [reserved_sectors]   ; AX = FirstDataSector

    ; Step 3: Add cluster offset
    add ax, bx             ; AX = final sector

    pop dx
    pop cx
    pop bx
    ret


parse_bpb:
    mov si, 0x0600         ; Boot sector buffer

    mov ax, [si + 0x0B]    ; Bytes per sector
    mov [bytes_per_sector], ax

    mov al, [si + 0x0D]    ; Sectors per cluster
    mov [sectors_per_cluster], al

    mov ax, [si + 0x0E]    ; Reserved sectors
    mov [reserved_sectors], ax

    mov al, [si + 0x10]    ; Number of FATs
    mov [num_fats], al

    mov ax, [si + 0x24]        ; low word of sectors_per_fat
    mov dx, [si + 0x26]        ; high word
    mov [sectors_per_fat_low], ax
    mov [sectors_per_fat_high], dx

    mov ax, [si + 0x2C]        ; low word of root_cluster
    mov dx, [si + 0x2E]        ; high word
    mov [root_cluster_low], ax
    mov [root_cluster_high], dx


    ret


kernel:
mov si, msg2
call print_string
jmp $

print_error:
    mov si, error_message
    call print_string
    jmp $

print_string:
    pusha
.next_char:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .next_char
.done:
    popa
    ret



error_message db 'Disk read error!', 0
msg db 'heya', 0
msg2 db 'heya2', 0
kern_msg db "switch to 0x1000", 0
bytes_per_sector dw 0
sectors_per_cluster db 0
reserved_sectors dw 0
num_fats db 0
sectors_per_fat dd 0
root_cluster dd 0
sectors_per_fat_low dw 0
sectors_per_fat_high dw 0
root_cluster_low dw 0
root_cluster_high dw 0


times 510 - ($ - $$) db 0
dw 0xAA55


