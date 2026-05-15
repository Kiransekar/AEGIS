/*==============================================================================
 * AEGIS-RV System Calls — Minimal UART output for boot validation
 *============================================================================*/

#include <stdint.h>

#define UART_BASE 0x40000000

volatile uint32_t *uart_tx = (uint32_t *)UART_BASE;

void _write(int fd, const char *buf, int len) {
    for (int i = 0; i < len; i++) {
        *uart_tx = (uint32_t)buf[i];
    }
}

int _read(int fd, char *buf, int len) {
    return -1;
}

void _exit(int status) {
    while (1);
}
