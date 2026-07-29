#!/bin/bash

# --- Config ---
SECTOR_SIZE=512
START_SECTOR=123
IMG=os.img
FILE_TABLE=file_table.txt
DATA_ASM=asm/data.asm
FILE_DIR=file

# --- Generate data.asm with file_table_start ---
echo "🧠 Generating $DATA_ASM with file_table_start..."

{
    echo "section .data"
    echo "align 512"
    echo ""
    echo "file_table_start:"
} > "$DATA_ASM"

sector=$START_SECTOR

for file in "$FILE_DIR"/*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    filesize=$(stat -c%s "$file")
    sectors=$(( (filesize + SECTOR_SIZE - 1) / SECTOR_SIZE ))

    echo "    db \"${filename}|${sector}\", 0x0A" >> "$DATA_ASM"
    sector=$((sector + sectors))
done

<<<<<<< Updated upstream
echo "    db 0" >> "$DATA_ASM"
echo "" >> "$DATA_ASM"
echo "✅ $DATA_ASM updated successfully."

# --- Clean previous build ---
rm -f "$IMG" "$FILE_TABLE"

# --- Assemble bootloader and kernel ---
echo "🔧 Assembling bootloader and kernel..."
nasm -f bin -o bootloader.bin bootloader.asm || exit 1
nasm -f bin -o kernel.bin kernel.asm || exit 1
=======
echo "🔧 Assembling bootloader and kernel..."
nasm -f bin -o "$KERNEL" kernel.asm



# --- Compute kernel sectors and export to kernel_size.inc ---





nasm -f bin -o "$BOOTLOADER" bootloader.asm

>>>>>>> Stashed changes

# --- Create blank image ---
echo "📦 Creating blank image..."
dd if=/dev/zero of="$IMG" bs=$SECTOR_SIZE count=300

# --- Embed bootloader ---
echo "🚀 Embedding bootloader..."
dd if=bootloader.bin of="$IMG" bs=$SECTOR_SIZE count=1 conv=notrunc

# --- Embed kernel ---
echo "🧠 Embedding kernel..."
dd if=kernel.bin of="$IMG" bs=$SECTOR_SIZE seek=1 conv=notrunc

# --- Embed files and generate file_table.txt ---
echo "📁 Embedding files from $FILE_DIR..."
sector=$START_SECTOR

for file in "$FILE_DIR"/*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    filesize=$(stat -c%s "$file")
    sectors=$(( (filesize + SECTOR_SIZE - 1) / SECTOR_SIZE ))

    echo "✅ $filename → sector $sector ($sectors sectors)"
    dd if="$file" of="$IMG" bs=$SECTOR_SIZE seek=$sector conv=notrunc

    echo "$filename|$sector" >> "$FILE_TABLE"
    sector=$((sector + sectors))
done

# --- Embed file_table.txt at sector 121 ---
echo "📝 Embedding $FILE_TABLE at sector 121..."
echo -e "\n" >> "$FILE_TABLE"
dd if="$FILE_TABLE" of="$IMG" bs=$SECTOR_SIZE seek=121 conv=notrunc

echo "🎉 Build complete: $IMG"
