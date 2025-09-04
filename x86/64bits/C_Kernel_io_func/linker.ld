/* A custom linker script for our 64-bit bare-metal kernel.
 * This script tells the linker how to lay out the final binary file.
 */

ENTRY(main)                      /* The entry point of our kernel is the `main` function. */

SECTIONS {
    /* Set the base address of the kernel in memory.
     * The bootloader loads the kernel at `0x10000`.
     */
    . = 0x10000;

    /* The `.text` section contains our executable code.
     * We want this section to be the first part of our binary.
     */
    .text : {
        *(.text)
    }

    /* The `.data` section contains initialized global variables. */
    .data : {
        *(.data)
    }

    /* The `.rodata` section contains read-only data (like string literals). */
    .rodata : {
        *(.rodata)
    }

    /* The `.bss` section contains uninitialized global variables. */
    .bss : {
        *(.bss)
    }
}
