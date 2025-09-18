# Guil-OS

- 16bits bootloader + 32bits protected_mode kernel + Shell with -help & -ls command + Auto-scrolling &
navigation (up n down) + auto cursor repositioning at end of shell...

- introduce -cat command and tools relate to this....

-next still working on fat32 filesystem thinking of ext2 maybe to see

-next shell are limited to 8000 char want to make -term <option # char>
   to modify the  limitation of the shell but will require more ram maybe
   add autoscolling  !   and a register of page of the shell pass 100 rows it will make page 1 to ...
   back n forth using page up down +CTRL maybe as pageup n down use to scroll up n down the current term shell
   

-nasm -f bin -o bootloader.bin bootloader.asm
-nasm -g bin -o kernel.bin kernel.asm
-python3 pypy.py 
-qemu-system-i386 -hda os.img
-qemu maybe different im on aarch_v8 pi os 64bits -qemu ...


