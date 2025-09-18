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


# --- Define file entries ---
def make_entry(name, start_sector, sector_count):
    entry = bytearray(32)
    name_bytes = name.encode('ascii')[:15] + b'\x00'
    entry[0:16] = name_bytes.ljust(16, b'\x00')
    entry[16:20] = start_sector.to_bytes(4, 'little')
    entry[20:24] = sector_count.to_bytes(4, 'little')
    return entry

# --- Embed files ---
files = [
    ("hello.txt", 114),
    ("index.txt", 115),
]

file_entries = []
for filename, sector in files:
    with open(filename, "rb") as f:
        data = f.read()
        sector_count = (len(data) + SECTOR_SIZE - 1) // SECTOR_SIZE
        file_entries.append(make_entry(filename, sector, sector_count))
        img[SECTOR_SIZE * sector : SECTOR_SIZE * (sector + sector_count)] = pad_to_sectors(data, sector_count)

# --- Build file table (sectors 105–106) ---
file_table = b''.join(file_entries)
file_table = file_table.ljust(SECTOR_SIZE * 2, b'\x00')
img[SECTOR_SIZE * 111 : SECTOR_SIZE * 113] = file_table



# --- Write final image ---
with open("os.img", "wb") as f:
    f.write(img)

print("✅ Image built successfully: os.img")
