/* A custom linker script for our 64-bit bare-metal kernel. */

/* Define the entry point of the kernel. The bootloader will jump to this symbol. */
ENTRY(main)

/* We specify that the linker should output a raw binary, without any ELF headers. */
OUTPUT_FORMAT(binary)

/* Define the base address of the kernel in memory.
   The bootloader loads the kernel binary to this address. */
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
    
    /* The .data section contains initialized global variables. */
    .data :
    {
        *(.data)
    }

    /* The .rodata section contains read-only data (like string literals). */
    .rodata :
    {
        *(.rodata)
    }
    
    /* The .bss section contains uninitialized global variables. */
    .bss :
    {
        *(.bss)
        . = ALIGN(4096); /* Align the end of the section to a page boundary. */
    }
}

