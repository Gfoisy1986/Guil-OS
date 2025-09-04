Incomplete currently on test bench...


64-bit Bare-Metal Bootloader and C Kernel
This project contains a minimal bootloader and a simple C kernel for the x86-64 architecture. The bootloader handles the critical mode switch from 16-bit to 64-bit, then jumps to the C kernel's entry point.

Project Structure
boot.asm: The 16-bit assembly bootloader. Handles mode switching and loads the kernel.

kernel.c: The main C kernel. Contains the main function and higher-level logic.

io.c: A simple C library containing I/O functions.

io.h: Header file for io.c, defining function prototypes.

io_asm.asm: An assembly file with a function for writing to the screen, callable from C.

linker.ld: A custom linker script that defines where the kernel's code and data will be placed in memory.

Makefile: Automates the entire build process, including compiling C code and linking it with assembly.

Features
Bootloader (16-bit): Switches the CPU to 64-bit Long Mode.

Kernel (64-bit): Written in C, it provides a basic command-line interface.

Custom C Library: Demonstrates how to create a simple library that calls assembly code for hardware interaction.

Prerequisites
You need the following tools installed on your system:

NASM: The Netwide Assembler.

QEMU: A machine emulator.

GCC (x86_64-elf): A cross-compiler for 64-bit bare-metal development.

GNU Make: A build automation tool.

Setup and Build Instructions
Install tools:

sudo apt-get install nasm qemu-system-x86 make


Compile the C files and assemble the assembly file:

make

Run with QEMU:

qemu-system-x86_64 -fda disk.img

You should see the bootloader's message followed by the C kernel's welcome message and a prompt.

ISO Creation
To create a bootable ISO image:

make iso

Then run the ISO with QEMU:

qemu-system-x86_64 -cdrom myos.iso
