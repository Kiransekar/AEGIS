/*==============================================================================
 * AEGIS-RV Boot Validation Main
 * Purpose: Phase 1 verification — prove deterministic reset → main() → output
 *============================================================================*/

#include <stdint.h>

#define UART_BASE 0x40000000
volatile uint32_t *uart_tx = (uint32_t *)UART_BASE;

/* GPIO base for status output */
#define GPIO_BASE 0x40001000
volatile uint32_t *gpio_out = (uint32_t *)GPIO_BASE;

static void uart_puts(const char *s) {
    while (*s) {
        *uart_tx = (uint32_t)*s;
        s++;
    }
}

int main(void) {
    /* Signal that main() was reached */
    uart_puts("main_reached\n");

    /* Write BOOT_OK to GPIO for testbench detection */
    *gpio_out = 0xB0070000;  /* BOOT_OK magic value */

    /* UART confirmation */
    uart_puts("BOOT_OK\n");

    /* Write pass marker to known TCM address for RTL testbench */
    volatile uint32_t *result_addr = (volatile uint32_t *)0x0001FFFC;
    *result_addr = 0x00000001;  /* 1 = all tests passed */

    /* Halt */
    while (1) {
        asm volatile("wfi");
    }

    return 0;
}
