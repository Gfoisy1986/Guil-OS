[org 0x20000]
[BITS 16]
global protected_mode
db 'GOS!'

; ============================
; 16‑bit entry
; ============================
start:
    mov si, message
    call print
    call newline
    call newline

    mov si, message2
    call print

    ; ENABLE A20
    in  al, 0x92
    or  al, 2
    out 0x92, al

    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or  eax, 1
    mov cr0, eax

    jmp CODE_SEG:protected_mode


; ============================
; 32‑bit code
; ============================
[BITS 32]
protected_mode:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov esp, 0x9FC00

    lidt [idt_descriptor]

    call remap_pic
    call install_timer_irq
    call install_keyboard_irq
    sti

    call enter_long_mode

.hang32:
    jmp .hang32


; ============================
; Long mode setup (still in 32‑bit)
; ============================
gdt64_start:
gdt64_null: dq 0

gdt64_code:
    dw 0x0000
    dw 0x0000
    db 0x00
    db 10011010b
    db 00100000b
    db 0x00

gdt64_data:
    dw 0x0000
    dw 0x0000
    db 0x00
    db 10010010b
    db 00000000b
    db 0x00

gdt64_end:

gdt64_descriptor:
    dw gdt64_end - gdt64_start - 1
    dd gdt64_start

CODE64_SEG equ 0x08
DATA64_SEG equ 0x10

align 4096
pml4:
    dq pdpt + 0x03

align 4096
pdpt:
    dq pd + 0x03

align 4096
pd:
    dq 0x00000000 + (1 << 7) + 0x03

pml4_phys equ pml4

align 16
long_mode_stack:
    times 4096 db 0
long_mode_stack_top equ long_mode_stack + 4096

enter_long_mode:
    mov eax, cr4
    or  eax, (1 << 5)
    mov cr4, eax

    mov eax, pml4_phys
    mov cr3, eax

    mov ecx, 0xC0000080
    rdmsr
    or  eax, (1 << 8)
    wrmsr

    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax

    lgdt [gdt64_descriptor]

    jmp CODE64_SEG:long_mode_entry


; ============================
; 64‑bit entry
; ============================
[BITS 64]
long_mode_entry:
    mov ax, DATA64_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax

    mov rsp, long_mode_stack_top

    jmp start_shell64


global start_shell64
start_shell64:
    jmp $


; ============================
; Retour en 32‑bit pour le reste
; ============================
[BITS 32]

; ============================================================
; IDT / ISR / PIC / clavier
; ============================================================

global isr_default
global isr_keyboard
global isr_timer

idt_start:
    times 256*8 db 0
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start

isr_default:
    cli
.hang:
    hlt
    jmp .hang

xor eax, eax
mov ecx, 256

.init_idt_loop:
    mov edx, isr_default
    mov bx, CODE_SEG
    mov cl, 0x8E
    call set_idt_entry

    inc eax
    loop .init_idt_loop

set_idt_entry:
    push eax
    push edx
    push ebx
    push ecx

    mov edi, idt_start
    shl eax, 3
    add edi, eax

    mov ax, dx
    mov [edi], ax

    mov [edi+2], bx

    mov byte [edi+4], 0

    mov [edi+5], cl

    shr edx, 16
    mov ax, dx
    mov [edi+6], ax

    pop ecx
    pop ebx
    pop edx
    pop eax
    ret

remap_pic:
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    mov al, 0x20
    out 0x21, al

    mov al, 0x28
    out 0xA1, al

    mov al, 0x04
    out 0x21, al

    mov al, 0x02
    out 0xA1, al

    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    mov al, 0b11111100
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al
    ret

isr_timer:
    mov al, 0x20
    out 0x20, al
    iretd

install_timer_irq:
    mov eax, 0x20
    mov edx, isr_timer
    mov bx, CODE_SEG
    mov cl, 0x8E
    call set_idt_entry

    mov al, 0x36
    out 0x43, al

    mov ax, 11932
    out 0x40, al
    mov al, ah
    out 0x40, al
    ret

install_keyboard_irq:
    mov eax, 0x21
    mov edx, isr_keyboard
    mov bx, CODE_SEG
    mov cl, 0x8E
    call set_idt_entry
    ret

isr_keyboard:
    pushad

    in   al, 0x60
    mov  bl, al

    test bl, 0x80
    jnz  .eoi

    cmp bl, 0x58
    ja  .eoi

    movzx ebx, bl
    mov   al, [scancode_table + ebx]

    cmp byte [shift_state], 0
    je  .store

    movzx ebx, bl
    mov   al, [scancode_shifted + ebx]

.store:
    movzx ecx, byte [keyboard_head]
    mov [keyboard_buf    + ecx], al
    mov [keyboard_buf_sc + ecx], bl

    inc cl
    and cl, 0x7F
    mov [keyboard_head], cl

.eoi:
    mov al, 0x20
    out 0x20, al
    popad
    iretd

get_key_pm:
    movzx eax, byte [keyboard_head]
    movzx ecx, byte [keyboard_tail]

    cmp eax, ecx
    je .no_key

    mov al, [keyboard_buf    + ecx]
    mov bl, [keyboard_buf_sc + ecx]

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


; ============================================================
; GDT 16‑bit / messages / données
; ============================================================
[BITS 16]

gdt_start:
gdt_null:
    dd 0
    dd 0

gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x9A
    db 0xCF
    db 0x00

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0x92
    db 0xCF
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

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

message  db 'Kernel loaded...', 0
message2 db 'Kernel up n running!...', 0

CODE_SEG equ 0x08
DATA_SEG equ 0x10

row dw 0
col dw 0


[BITS 32]
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
msg_pm:  db "ADMIN @ Guil-OS: ", 0

text_buffer: times 8000 dw 0x0720

logical_cursor_row  dw 0
scroll_offset       dw 0
cursor_row          db 0
cursor_col          db 0

screen_dirty db 1
current_input:   times 128 db 0
input_buffer:    times 512 db 0
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

file_length:   dd 0
load_filename: db "hello.txt", 0

cmd_help_inline: db "-help", 0
cmd_ls_inline:   db "-ls", 0
cmd_cat_inline:  db "-cat", 0

msg_file_not_found:
    db 0x0A
    db "Error: File not found", 0x0A
    db 0x0A
    db 0

msg_lss_detected: db "LSS command detected", 0

db_file: times 512 db 0x55

shift_state db 0
ctrl_state  db 0
alt_state   db 0

keyboard_buf:     times 128 db 0
keyboard_buf_sc:  times 128 db 0
keyboard_head:    db 0
keyboard_tail:    db 0

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
    db 0,  0x1B,0x31,0x32,0x33,0x34,0x35,0x36
    db 0x37,0x38,0x39,0x30,0x2D,0x3D,0x08,0x09
    db 0x71,0x77,0x65,0x72,0x74,0x79,0x75,0x69
    db 0x6F,0x70,0x5B,0x5D,0x0D,0,    0x61,0x73
    db 0x64,0x66,0x67,0x68,0x6A,0x6B,0x6C,0x3B
    db 0x27,0x60,0,    0x5C,0x7A,0x78,0x63,0x76
    db 0x62,0x6E,0x6D,0x2C,0x2E,0x2F,0,    0x2A
    db 0,    0x20,0,    0,    0,    0,    0,    0
    times 64 db 0

scancode_shifted:
    db 0,  0x1B,0x21,0x40,0x23,0x24,0x25,0x5E
    db 0x26,0x2A,0x28,0x29,0x5F,0x2B,0x08,0x09
    db 0x51,0x57,0x45,0x52,0x54,0x59,0x55,0x49
    db 0x4F,0x50,0x7B,0x7D,0x0D,0,    0x41,0x53
    db 0x44,0x46,0x47,0x48,0x4A,0x4B,0x4C,0x3A
    db 0x22,0x7E,0,    0x7C,0x5A,0x58,0x43,0x56
    db 0x42,0x4E,0x4D,0x3C,0x3E,0x3F,0,    0x2A
    db 0,    0x20,0,    0,    0,    0,    0,    0
    times 64 db 0


; ============================
; PADDING FINAL — DERNIÈRE LIGNE
; ============================

KERNEL_SECTORS equ 267
times (KERNEL_SECTORS * 512) - ($ - $$) db 0
