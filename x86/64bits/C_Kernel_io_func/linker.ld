/*
 * A custom linker script for our 64-bit bare-metal kernel.
 * This script is designed to produce an ELF executable, which is then
 * converted to a flat binary by objcopy.
 */

/* The entry point of the kernel, called by the bootloader. */
ENTRY(main)

/* We do NOT specify a binary output format here,
 * allowing the linker to create a full ELF file. */

/* Define the base address of the kernel in memory.
 * This will be the virtual address in the ELF file. */
BASE_ADDRESS = 0x10000;

SECTIONS
{
    /* The .text section contains the code. */
    .text :
    {
        /* The `.` symbol represents the current location counter.
           We set it to our base address. */
        . = BASE_ADDRESS;
        
        /* Put all the executable code into this section. */
        KEEP(*(.text.main))
        *(.text)
    }

    /* The .rodata section contains read-only data (like string literals). */
    .rodata :
    {
        *(.rodata)
    }

    /* The .data section contains initialized global variables. */
    .data :
    {
        *(.data)
    }
    
    /* The .bss section contains uninitialized global variables. */
    .bss :
    {
        *(.bss)
        . = ALIGN(4096); /* Align the end of the section to a page boundary. */
    }
}

