
CC=gcc
LD=ld
AS=as
OBJCOPY=objcopy

all: kernel8.img

kernel8.img: bootloader.o kernel.o
	$(LD) -T linker.ld bootloader.o kernel.o -o kernel.elf
	$(OBJCOPY) -O binary kernel.elf kernel8.img

bootloader.o: bootloader.S
	$(AS) bootloader.S -o bootloader.o

kernel.o: kernel.c
	$(CC) -c kernel.c -o kernel.o -nostdlib -nostartfiles -ffreestanding

clean:
	rm -f *.o *.elf *.img
