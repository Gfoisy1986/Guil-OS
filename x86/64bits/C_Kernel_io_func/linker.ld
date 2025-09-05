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
    
    /* The .rodata section contains read-only data (like string literals). */
    /* We place it immediately after the text section. */
    .rodata : AT(ADDR(.text) + SIZEOF(.text))
    {
        *(.rodata)
    }

    /* The .data section contains initialized global variables. */
    /* We place it immediately after the read-only data section. */
    .data : AT(ADDR(.rodata) + SIZEOF(.rodata))
    {
        *(.data)
    }
    
    /* The .bss section contains uninitialized global variables. */
    /* We place it immediately after the data section. */
    .bss : AT(ADDR(.data) + SIZEOF(.data))
    {
        *(.bss)
        . = ALIGN(4096); /* Align the end of the section to a page boundary. */
    }
}


The key change is the addition of the `AT()` keyword to each section after `.text`. For a raw binary, the final file is a direct representation of the program's memory layout. `AT()` ensures that each section is placed contiguously, one after the other, in the output binary.

* `AT(ADDR(.text) + SIZEOF(.text))`: This tells the linker to place the `.rodata` section at a location in the final binary that is the address of the `.text` section plus its size. This ensures the `.rodata` section is loaded into memory directly after the `.text` section.

This ensures that when your bootloader loads the binary into memory at `0x10000`, the `.text`, `.rodata`, `.data`, and `.bss` sections will all be laid out correctly and contiguously. 

Let me know if you'd like to dive into the assembly startup code that pairs with this linker script!
