.section .text
.global _start

_start:
    // Set up stack
    ldr x0, =stack_top
    mov sp, x0

    // Call kernel_main
    bl kernel_main

    // Hang
hang:
    wfe
    b hang

.section .bss
    .align 12
stack:
    .skip 4096
stack_top:
