import os

# --- Configuration ---
BOOTLOADER_FILE = "bootloader.bin"
KERNEL_FILE = "kernel.bin"
IMAGE_FILE = "disk.img"
SECTOR_SIZE = 512
TOTAL_SECTORS = 32  # Enough for bootloader + kernel + FAT + files

# --- Create empty disk image ---
with open(IMAGE_FILE, "wb") as f:
    f.write(b"\x00" * SECTOR_SIZE * TOTAL_SECTORS)

# --- Write bootloader to sector 0 ---
with open(IMAGE_FILE, "r+b") as img, open(BOOTLOADER_FILE, "rb") as boot:
    img.seek(0)
    img.write(boot.read(SECTOR_SIZE))  # Bootloader is 512 bytes

# --- Write kernel to sectors 2–11 (10 sectors) ---
with open(IMAGE_FILE, "r+b") as img, open(KERNEL_FILE, "rb") as kernel:
    img.seek(SECTOR_SIZE * 2)  # Sector 2
    img.write(kernel.read(SECTOR_SIZE * 10))  # Kernel is 10 sectors

# --- Write FAT table to sector 1 ---
fat_table = bytearray([0xFF, 0xFF, 0x03, 0x04, 0xFF] + [0x00] * (SECTOR_SIZE - 5))
with open(IMAGE_FILE, "r+b") as img:
    img.seek(SECTOR_SIZE * 1)  # Sector 1
    img.write(fat_table)

# --- Write README.md content to sector 2 ---
readme_content = b"This is a README file. You can see me with the `cat` command!\x00"
readme_sector = readme_content.ljust(SECTOR_SIZE, b"\x00")
with open(IMAGE_FILE, "r+b") as img:
    img.seek(SECTOR_SIZE * 2)
    img.write(readme_sector)

# --- Write MESSAGE.TXT content to sector 3 ---
message_content = b"This is a test message. Welcome to the terminal!\x00"
message_sector = message_content.ljust(SECTOR_SIZE, b"\x00")
with open(IMAGE_FILE, "r+b") as img:
    img.seek(SECTOR_SIZE * 3)
    img.write(message_sector)

print(f"✅ Disk image '{IMAGE_FILE}' created successfully!")

