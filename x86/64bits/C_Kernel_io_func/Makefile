# Makefile for the 64-bit bare-metal C kernel

# Toolchain settings
CC = gcc
AS = nasm
LD = ld

# Flags for the C compiler
# -ffreestanding: Tells GCC we are not linking against a standard C library.
# -nostdlib: Don't link against the standard C library.
# -I.: Include the current directory for header files.
# -c: Compile only, do not link.
# -m64: Generate 64-bit code.
CFLAGS = -ffreestanding -nostdlib -I. -m64 -c

# Flags for the assembler
# -f elf64: Generate 64-bit ELF object files.
ASFLAGS = -f elf64

# Flags for the linker
# -T: Use the specified linker script.
# -nostdlib: Don't link against the standard C library.
# -m elf_x86_64: Specify the target architecture.
LDFLAGS = -T linker.ld -nostdlib -m elf_x86_64

# Files
BOOT_SRC = boot.asm
KERNEL_SRC = kernel.c io.c
IO_ASM_SRC = io_asm.asm
LINKER_SCRIPT = linker.ld

BOOT_BIN = boot.bin
KERNEL_OBJS = kernel.o io.o io_asm.o
KERNEL_BIN = kernel.bin
DISK_IMG = disk.img
ISO_IMG = myos.iso

.PHONY: all clean iso

all: $(DISK_IMG)

$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	@echo "Creating disk image..."
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(DISK_IMG)
	@echo "Disk image created: $(DISK_IMG)"

$(BOOT_BIN): $(BOOT_SRC)
	@echo "Assembling bootloader..."
	$(AS) $(BOOT_SRC) -o $(BOOT_BIN)

$(KERNEL_BIN): $(KERNEL_OBJS) $(LINKER_SCRIPT)
	@echo "Linking kernel..."
	$(LD) $(LDFLAGS) $(KERNEL_OBJS) -o $(KERNEL_BIN)

%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) $< -o $@

io_asm.o: $(IO_ASM_SRC)
	@echo "Assembling $<..."
	$(AS) $(ASFLAGS) $(IO_ASM_SRC) -o $@

iso: $(DISK_IMG)
	@echo "Creating ISO image..."
	xorriso -as mkisofs -iso-level 3 -o $(ISO_IMG) -b $(DISK_IMG) -no-emul-boot -boot-load-size 4 .

clean:
	@echo "Cleaning up..."
	rm -f $(BOOT_BIN) $(KERNEL_OBJS) $(KERNEL_BIN) $(DISK_IMG) $(ISO_IMG)
