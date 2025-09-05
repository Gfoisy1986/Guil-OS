#include "io.h"

// Define a simple struct for a command, not used but shows a concept
typedef struct {
    char* name;
    void (*handler)();
} command_t;

// The main entry point of our C kernel.
// This function is called by the assembly bootloader.
void main() {
    clear_screen();
    print_string("Welcome to my C Kernel!\n");
    print_string("Type 'help' for a list of commands.\n\n");
    print_string("> ");

    // The main command loop would go here in a more advanced kernel.
    while (1) {
        // Here, we would read user input and process commands.
        // For now, we simply loop indefinitely.
    }
}

