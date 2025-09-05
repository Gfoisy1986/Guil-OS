#include "io.h"

// The assembly function that writes a single character to video memory.
extern void put_char_asm(char c);

// The assembly function that writes a string to video memory.
extern void put_string_asm(const char* str);

// The assembly function that clears the screen.
extern void clear_screen_asm();

/**
 * @brief Prints a single character to the screen.
 * @param c The character to print.
 */
void print_char(char c) {
    put_char_asm(c);
}

/**
 * @brief Prints a null-terminated string to the screen.
 * @param str The string to print.
 */
void print_string(const char* str) {
    put_string_asm(str);
}

/**
 * @brief Clears the screen.
 */
void clear_screen() {
    clear_screen_asm();
}

