32-bit Protected Mode Bootloader and Kernel

This project contains a minimal bootloader and kernel designed to run on a 32-bit x86 architecture. The bootloader is responsible for switching the CPU from 16-bit real mode to 32-bit protected mode before handing control over to the kernel.


Features

Bootloader (16-bit): Loads into memory at 0x7C00. It prepares the CPU for protected mode by setting up a Global Descriptor Table (GDT) and enabling the PE bit in the CR0 register. It then loads the 32-bit kernel from the disk.

Kernel (32-bit): Loads into memory at 0x10000. It sets up its own 32-bit segment registers and provides a basic command-line interface. It uses direct memory writes to display text to the screen, as BIOS interrupts are no longer available in protected mode.

Simple "File System": A basic, hardcoded file system is included in the kernel. You can read these files using the cat command.

Commands: help, cat <filename>.



Prerequisites

To build and run this project, you need the following tools installed on your system:

NASM: The Netwide Assembler.

QEMU: A fast and versatile open-source machine emulator and virtualizer.

GNU Make: A tool to automate the compilation process.

xorriso: A tool to create ISO 9660 filesystems.

You can install these on Ubuntu with the following command:

sudo apt-get install nasm qemu-system-x86 make xorriso



Build Instructions

Assemble the bootloader and kernel:

nasm -f bin boot.asm -o boot.bin

nasm -f bin kernel.asm -o kernel.bin

Create the disk image:

This command concatenates the bootloader and kernel to create a single bootable image.

cat boot.bin kernel.bin > disk.img

Run with QEMU:

qemu-system-i386 -fda disk.img

You should see the bootloader message, a mode switch, and then the kernel prompt >.



ISO Creation


If you want to create a bootable ISO image instead of a floppy disk image, use the following command after creating disk.img:

xorriso -as mkisofs -iso-level 3 -o myos.iso -b disk.img -no-emul-boot -boot-load-size 4 .

You can then run the ISO with QEMU:

qemu-system-i386 -cdrom myos.iso
