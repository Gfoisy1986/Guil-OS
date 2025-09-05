void kernel_main(void) {
    volatile unsigned int *gpio = (unsigned int *)0xFE200000; // GPIO base for Pi 5
    gpio[1] = (gpio[1] & ~(7 << 18)) | (1 << 18); // Set GPIO pin 6 as output
    gpio[7] = 1 << 6; // Set GPIO pin 6 high

    while (1) {
        // Blink or loop forever
    }
}
