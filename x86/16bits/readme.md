16-bit Bootloader with Simple Terminal and File System
This project is a basic 16-bit bootloader written in x86 assembly. It includes a simple command-line terminal and a minimal file storage system.

Overview
boot.asm: The initial 512-byte boot sector that is loaded by the BIOS. Its primary role is to set up the environment and load the main kernel from the disk.

kernel.asm: The main part of the "operating system." It contains the terminal logic, command interpreter, and file system functions.

File System: A very simple, flat-file system is implemented. It stores a hardcoded file table and file data directly on the disk after the boot and kernel sectors.

The file table contains entries for each file, including its name, size, and starting sector.

File data is stored in the sectors following the file table.

Compiling and Running
You will need the following tools:

NASM (Netwide Assembler): To assemble the .asm files.

QEMU: A fast and powerful open-source machine emulator and virtualizer.

Step 1: Assemble the files

Open a terminal and run the following commands to assemble the bootloader and kernel.

nasm -f bin boot.asm -o boot.bin
nasm -f bin kernel.asm -o kernel.bin

Step 2: Create a disk image

We need to combine the boot sector and the kernel into a single disk image. The kernel is located on the second sector (LBA 1) of the disk.

cat boot.bin kernel.bin > disk.img

Step 3: Run the disk image in QEMU

This command will boot the disk.img in a virtual machine.

qemu-system-x86_64 disk.img

Creating a Bootable ISO
To create a bootable ISO file, you will need the genisoimage or xorriso tool. The xorriso tool is generally recommended as it is more modern.

Install the ISO Creation Tool

sudo apt-get install xorriso

Create a Directory for ISO Contents

Create a new directory to hold the files that will be placed on the ISO. This is where you will place your bootloader image.

mkdir iso_root
cp disk.img iso_root/

Generate the Bootable ISO Image

Use xorriso to create the ISO. The --mbr-boot-cat and --boot-load-size flags are crucial for making the ISO bootable.

xorriso -as mkisofs -o bootloader.iso \
-b disk.img -no-emul-boot -boot-load-size 4 -boot-info-table iso_root/

-o bootloader.iso: Specifies the name of the output ISO file.

-b disk.img: Sets disk.img as the boot image.

-no-emul-boot: Instructs the BIOS not to emulate a floppy disk.

-boot-load-size 4: Specifies that the BIOS should load 4 sectors (2KB) into memory for booting.

iso_root/: Specifies the root directory of the ISO's file system.

You can now test the ISO image with QEMU:

qemu-system-x86_64 -cdrom bootloader.iso

Supported Commands
Once the bootloader loads and the terminal appears, you can use the following commands:

help: Displays the available commands.

ls: Lists the files in the simple file system.

cat <filename>: Displays the contents of a file.

echo <text>: Echos the provided text to the console.