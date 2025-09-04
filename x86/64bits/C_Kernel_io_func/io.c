#include "io.h"

// The assembly function that writes a string to video memory.
// It is defined in io_asm.asm and linked with this file.
extern void put_string_asm(const char* str);

// The assembly function that writes a character to video memory.
extern void put_char_asm(char c);

// Prints a null-terminated string to the screen.
void print_string(const char* str) {
    put_string_asm(str);
}

// Clears the screen by writing spaces to every character position.
void clear_screen() {
    // The video memory starts at 0xB8000.
    char* video_memory = (char*)0xB8000;

    // Each character and color attribute pair is 2 bytes.
    // A standard 80x25 screen is 2000 characters.
    for (int i = 0; i < 2000; i++) {
        *video_memory = ' ';         // Write a space character.
        *(video_memory + 1) = 0x07;  // Write the color attribute (light gray).
        video_memory += 2;           // Move to the next character position.
    }
}
