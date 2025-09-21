# Guil-OS
## Bare-Metal Guillaume Foisy OS
 
-Source Directory...


- dd if=/dev/zero of=myos.img bs=1M count=500

- sudo losetup -fP myos.img

-sudo gparted /dev/loop0

-Create a new MS-DOS (MBR) partition table.

Create your FAT32 partition with 99 preceding mb and rest for fat32 partition

- nasm -f bin -o bootloader.bin bootloader.asm

- nasm -f bin -o kernel.bin kernel.asm

- dd if=bootloader.bin of=myos.img bs=512 count=1 conv=notrunc

- dd if=kernel.bin of=myos.img bs=512 seek=1 conv=notrunc

-  qemu-system-x86_64 -drive format=raw,file=myos.img
