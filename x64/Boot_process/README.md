64-bit Bootloader and Kernel

This project is a 64-bit bootloader and kernel, rewritten from the ground up to operate in x86-64 Long Mode. It demonstrates the process of transitioning the CPU from 16-bit Real Mode to 64-bit Long Mode.



Architectural Overview

The boot process is significantly more complex than the 16-bit version. The boot.asm file now has two primary jobs:

Load the 64-bit kernel from disk.

Switch the CPU from 16-bit Real Mode, through 32-bit Protected Mode, and into 64-bit Long Mode.

Once the CPU is in Long Mode, control is handed to the 64-bit kernel.asm.



Prerequisites

You will need the following tools:

NASM (for assembling assembly files)

ld (the GNU Linker, for linking the kernel)

cat or copy (to concatenate the bootloader and kernel)

QEMU (for emulation)



File Descriptions
boot.asm: The 16-bit bootloader. It sets up the GDT, page tables, and switches the CPU mode before jumping to the kernel.

kernel.asm: The 64-bit kernel. It contains the long-mode entry point and a simple function to print text directly to the video memory buffer.

disk.img: The final bootable disk image.



Compilation and Execution

Assemble the bootloader:

nasm -f bin boot.asm -o boot.bin

Assemble and link the kernel:
The kernel is now a relocatable object, so it must be assembled and then linked to a specific address.

nasm -f elf64 kernel.asm -o kernel.o

ld -Ttext 0x10000 --oformat binary -o kernel.bin kernel.o

-Ttext 0x10000: This tells the linker to place the kernel code at the address 0x10000. The bootloader is hardcoded to load the kernel to this address.

--oformat binary: This specifies that the output should be a raw binary file, not an ELF executable.

Create the disk image:

The bootloader is 512 bytes, so you must pad it to exactly one sector before concatenating it with the kernel.

dd if=boot.bin of=disk.img bs=512 count=1

dd if=kernel.bin of=disk.img bs=512 seek=1

dd if=boot.bin of=disk.img bs=512 count=1: This creates disk.img and writes boot.bin into its first sector.

dd if=kernel.bin of=disk.img bs=512 seek=1: This appends kernel.bin to the disk.img starting at the second sector (seek=1).

Run in QEMU:

qemu-system-x86_64 -m 128M -boot d -fda disk.img

The -m 128M flag gives the virtual machine 128MB of RAM, which is necessary for a 64-bit kernel.




the procedure to make a bootable ISO from the .img file using xorriso is conceptually the same. The key is that xorriso is a tool for creating ISO 9660 filesystems, and it doesn't care about the architecture of the code within your boot image. Its job is simply to correctly package your .img file so that a BIOS or UEFI can find it and execute it.

The main difference is that a more robust command is typically used to ensure compatibility with both legacy BIOS and modern UEFI systems. Here is a good, general-purpose command that will work for your 64-bit disk.img:

xorriso -as mkisofs -iso-level 3 -o myos.iso -b disk.img -no-emul-boot -boot-load-size 4 .

-b disk.img: This flag is the most important one. It tells xorriso to use your disk.img file as the boot image for the ISO.

-no-emul-boot: This specifies that the boot image should be loaded as a non-emulated device, which is the correct method for a bare-metal bootloader.

-boot-load-size 4: This flag is also crucial. It tells the BIOS that your boot image is 4 sectors (2048 bytes) in size and needs to be loaded entirely into memory, which is necessary since the bootloader itself loads the kernel.

So, while the fundamental idea is the same, this command is more specific and ensures the ISO is properly configured to boot on a modern system.
