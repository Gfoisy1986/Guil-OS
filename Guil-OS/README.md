# Guil-OS
## Bare-Metal Guillaume Foisy OS
 
### Version V0.1-Devel x86_32 bits protected mode

-Currently finish hazzardous pointer n starting integrating FAT32... A New bootloader incoming....


- file/    File_system folder

- rtns/    Routine folder

- docs/    Documentation folder

- asm/     kernel asm section folder



* The bash script build everything and auto create 'file_table.txt'...

* File are 1 sector (512 byte max) & auto null terminate by the bash script...

* Simply add file to 'file' directory whitout any extension it will build whitin automaticaly...

### Build requirement RPI500 aarch64 (MX Linux -debian based)

- BE AWARE path to binary maybe diffrent base on your own distro and architecture...

  May have to edit bash script accordingly....



```bash
sudo apt install nasm
```


```bash
sudo apt install qemu-system-x86
```


### PATH to binary


```bash
/usr/bin/nasm
```


```bash
/usr/bin/qemu-system-i386
```



## 🔧 Execute & Builds MX Linux arm64

```bash
 ./build.sh
```

```bash
/usr/bin/qemu-system-i386 -vga std -drive format=raw,file=os.img
```

## 🔧 Execute & Builds Image on ming-w64 win-11 64 bits...

```bash
cd ~/Guil-OS/Guil-OS/x86/32BITS/Devel/V0.1-Devel
```

```bash
./build.sh
```

```bash
qemu-system-i386 -vga std -drive format=raw,file=os.img
```

### En Devel... (TO DO)

* [DONE] Strippe down bootloader...

* [DONE] Strippe down kernel...

* Comment out every line of bootloader...

* Comment out every line of kernel when the version is done...

* [Done] Repair -cat cmd...

* [DONE] Repair -ls cmd...

* ADD -clear cmd to reset the shell...

* ADD -wait to press enter before returning to shell...

* ADD repair PAGE_UP DOWN & scrolling & SCROLLBAR...

* [HAHAHA omg have to redone i loss data!] Repair hazzardous pointer in the SHELL...

* IF SO add -wrt CMD & -crt CMD (create [-crt]  & write [-wrt] ) ...

* ADD More flexibility in term of size of files add per size instead of sector...

* ADD more option to file_system  name | sector | size | extension maybe...

* ADD compression & encryption...

* ADD UTF8 support to the shell via ...

* Optimize thing out on side of memory usage...
