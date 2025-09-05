# =====================================================================================================================
# Makefile for a 64-bit Bare-Metal C Kernel
# This makefile automates the entire build process, from assembling and compiling to linking and creating the final
# bootable disk image.
# =====================================================================================================================

# Define variables for the tools and file names.
NASM = nasm
GCC = gcc
LD = ld
OBJCOPY = objcopy
QEMU = qemu-system-x86_64

BOOT_ASM = boot.asm
KERNEL_C = kernel.c
IO_C = io.c
IO_ASM = io_asm.asm
LINKER = linker.ld

BOOT_BIN = boot.bin
KERNEL_O = kernel.o
IO_O = io.o
IO_ASM_O = io_asm.o
KERNEL_ELF = kernel.elf
KERNEL_BIN = kernel.bin
DISK_IMG = disk.img

# Default target: builds the entire project.
.PHONY: all
all: $(DISK_IMG)

# Rule to build the final disk image.
$(DISK_IMG): $(BOOT_BIN) $(KERNEL_BIN)
	@echo "Creating bootable disk image..."
	# Combine the bootloader and kernel into a single image.
	# The bootloader is 512 bytes, so we place the kernel directly after it.
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(DISK_IMG)
	@echo "Disk image created successfully: $(DISK_IMG)"

# Rule to link the kernel.
$(KERNEL_BIN): $(KERNEL_ELF)
	@echo "Converting ELF to a flat binary..."
	# Use objcopy to strip the ELF headers and create a flat binary.
	$(OBJCOPY) -O binary $< $@

$(KERNEL_ELF): $(KERNEL_O) $(IO_O) $(IO_ASM_O) $(LINKER)
	@echo "Linking kernel..."
	# -T linker.ld: Use our custom linker script.
	# -nostdlib: Do not link the standard C libraries (like glibc).
	# -m elf_x86_64: Specify the 64-bit ELF output format.
	$(LD) -T $(LINKER) -nostdlib -m elf_x86_64 $(KERNEL_O) $(IO_O) $(IO_ASM_O) -o $(KERNEL_ELF)

# Rule to compile the C files.
$(KERNEL_O): $(KERNEL_C)
	@echo "Compiling $(KERNEL_C)..."
	# -ffreestanding: Compile in a freestanding environment (no OS).
	# -nostdlib: Do not link the standard C libraries.
	# -m64: Compile for 64-bit architecture.
	# -I.: Include the current directory for header files.
	$(GCC) -ffreestanding -nostdlib -I. -m64 -c $(KERNEL_C) -o $(KERNEL_O)

$(IO_O): $(IO_C)
	@echo "Compiling $(IO_C)..."
	$(GCC) -ffreestanding -nostdlib -I. -m64 -c $(IO_C) -o $(IO_O)

# Rule to assemble the assembly files.
$(BOOT_BIN): $(BOOT_ASM)
	@echo "Assembling $(BOOT_ASM)..."
	# -o boot.bin: Output the binary file.
	$(NASM) $(BOOT_ASM) -o $(BOOT_BIN)

$(IO_ASM_O): $(IO_ASM)
	@echo "Assembling $(IO_ASM)..."
	# -f elf64: Create a 64-bit ELF object file.
	$(NASM) -f elf64 $(IO_ASM) -o $(IO_ASM_O)

# Rule to clean the build directory.
.PHONY: clean
clean:
	@echo "Cleaning up..."
	rm -f $(BOOT_BIN) $(KERNEL_O) $(IO_O) $(IO_ASM_O) $(KERNEL_ELF) $(KERNEL_BIN) $(DISK_IMG)

