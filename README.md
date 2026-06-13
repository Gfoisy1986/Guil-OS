# **Guil‑OS — A Minimalist, Modular, Bare‑Metal x86 Operating System**

Guil‑OS is a lightweight, modular, and fully hand‑crafted operating system designed for retro x86_64 hardware.  

---

## 🚀 **Features**


### ** Brand new Bootloader**
- Now scan if Guil-OS is present on drive...

### **🧠 Protected Mode Kernel**
- Custom GDT  
- Custom IDT (256 entries)  
- PIC remapping  
- IRQ0 (timer) + IRQ1 (keyboard)  
- Clean interrupt handlers  
- Fully 32‑bit environment  

### **⌨️ Modern Keyboard Driver (IRQ‑Driven)**
- Scancode → ASCII translation  
- Shift / Ctrl / Alt state tracking  
- Backspace, Enter, Tab  
- Extended keys (0xE0)  
- Arrow keys (left/right/up/down)  
- Circular input buffer  
- No polling — fully interrupt‑driven  

### **🖥️ Text‑Mode Terminal**
- 80×25 VGA text mode  
- Custom text buffer  
- Cursor management  
- Line editing (backspace, redraw)  
- Shell input system  

### **🧩 Modular Architecture**
- Clear separation of kernel, drivers, and userland  
- Minimal dependencies  
- Clean, readable assembly  
- Designed for future scripting integration (GF-Lang)



---

## 🛠️ **Build & Run**

### **Requirements**
- NASM  
- QEMU or real hardware  
- A bootloader (included or external)  

### **Build**
```bash
nasm -f bin kernel.asm -o kernel.bin
```

### **Run in QEMU**
```bash
qemu-system-i386 -kernel kernel.bin
```

### **Run on real hardware**
Flash to USB or floppy image and boot directly.

---

## 🧭 **Project Goals**

### **Short‑Term**
- Finalize keyboard driver  
- Add TTY switching (Alt+F1/F2/F3)  
- Improve shell input  
- Add timer‑based features  
- Scheduler
- File I/O
- Drivers..._
- Retrofacto Kernel

### **Long‑Term**
- Full network stack (GF‑NetStack)  
- GF-Lang scripting + compiler
- Graphical terminal  
- Mobile light web browser
- Isometric 2D engine
- Lightweight window system  

---

## 📚 **Philosophy**

Guil‑OS is built on three principles:

### **1. Modularity**
Every component is small, isolated, and understandable.

### **2. Maintainability**
Readable code > clever hacks.  
Future contributors should feel at home.

### **3. Ecological Computing**
Old hardware deserves a second life.  
Software should empower, not consume.

---

## 🤝 **Contributing**

Contributions are welcome!  
Whether you want to fix a bug, add a driver, or improve documentation, feel free to open an issue or submit a pull request.

---

## 📜 **License**

MIT License — simple, permissive, contributor‑friendly.

---

## 🧑‍💻 **Author**

**Guillaume Foisy** — Architect and technical lead of Guil‑OS  
Passionate about retro hardware, modular design, and ethical computing.

---

