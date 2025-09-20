import os

SECTOR_SIZE = 512
TOTAL_SECTORS = 300
IMG_SIZE = SECTOR_SIZE * TOTAL_SECTORS
img = bytearray(IMG_SIZE)

# --- Helper: pad binary to sector size ---
def pad_to_sectors(data, sectors):
    return data.ljust(sectors * SECTOR_SIZE, b'\x00')

# --- Load bootloader (sector 0) ---
with open("bootloader.bin", "rb") as f:
    bootloader = f.read()
    if len(bootloader) > SECTOR_SIZE:
        raise ValueError("Bootloader must be ≤ 512 bytes")
    if bootloader[-2:] != b'\x55\xAA':
        bootloader = bootloader[:510] + b'\x55\xAA'
    img[0 : SECTOR_SIZE] = bootloader.ljust(SECTOR_SIZE, b'\x00')

# --- Load kernel (sectors 1–104 = 104 sectors) ---
with open("kernel.bin", "rb") as f:
    kernel = f.read()
    if len(kernel) > SECTOR_SIZE * 115:
        raise ValueError("Kernel exceeds 104 sectors (53,248 bytes)")
    img[SECTOR_SIZE * 1 : SECTOR_SIZE * 110] = pad_to_sectors(kernel, 109)





# --- Write final image ---
with open("os.img", "wb") as f:
    f.write(img)

print("✅ Image built successfully: os.img")
