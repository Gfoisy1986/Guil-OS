#!/bin/bash
set -e

SECTOR_SIZE=512
IMG=os.img
BOOTLOADER=bootloader.bin
KERNEL=kernel.bin
FILE_DIR=file
FILE_TABLE=file_table.txt
DATA_ASM=asm/data.asm
KERNEL_SIZE_INC=asm/kernel_size.inc





rm -f "$IMG" "$BOOTLOADER" "$KERNEL"


nasm -f bin -o "$KERNEL" kernel.asm



# --- Compute kernel sectors and export to kernel_size.inc ---





nasm -f bin -o "$BOOTLOADER" bootloader.asm
echo "🔧 Assembling bootloader and kernel..."





echo "📦 Creating blank image..."
dd if=/dev/zero of="$IMG" bs=$SECTOR_SIZE count=300 status=none

echo "🚀 Embedding bootloader at LBA 0..."
dd if="$BOOTLOADER" of="$IMG" bs=$SECTOR_SIZE count=1 conv=notrunc status=none

echo "🧠 Embedding kernel at LBA 1..."
dd if="$KERNEL" of="$IMG" bs=$SECTOR_SIZE seek=1 conv=notrunc status=none



echo 
