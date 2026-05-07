/*==============================================================================
 * AEGIS-RV RT Core Test Firmware
 * Purpose: Sanity tests for interrupt, TCLS, ECC
 *============================================================================*/

#include <stdint.h>

/* CSR Addresses (from gen_csr_map.py output) */
#define CSR_AEGIS_RT_CFG        0x7C0
#define CSR_AEGIS_RT_STATUS     0x7C1
#define CSR_WATCHDOG_CFG        0x7C2
#define CSR_WATCHDOG_STATUS     0x7C3
#define CSR_ECC_SCRUB_CFG       0x7C4
#define CSR_ECC_SCRUB_STATUS    0x7C5
#define CSR_XDRONE_CFG          0x7C6
#define CSR_XDRONE_STATUS       0x7C7
#define CSR_SMU_FAULT_CODE      0x7C8
#define CSR_SMU_CTRL            0x7C9
#define CSR_POWER_CFG           0x7CA
#define CSR_POWER_STATUS        0x7CB

/* CSR Access Macros */
#define csr_read(csr) ({ \
    uint32_t val; \
    asm volatile("csrr %0, " #csr : "=r"(val)); \
    val; \
})

#define csr_write(csr, val) ({ \
    asm volatile("csrw " #csr ", %0" : : "r"(val)); \
})

/* Test Result Codes */
#define TEST_PASS 0x1
#define TEST_FAIL 0x0

/* Test: Watchdog Configuration */
int test_watchdog(void) {
    uint32_t cfg = (1 << 15) | 10000;  /* Enable + 10000 cycle timeout */
    csr_write(CSR_WATCHDOG_CFG, cfg);

    /* Read back and verify */
    uint32_t rdback = csr_read(CSR_WATCHDOG_CFG);
    if (rdback == cfg) {
        return TEST_PASS;
    }
    return TEST_FAIL;
}

/* Test: ECC Scrubber Configuration */
int test_ecc_scrub(void) {
    uint32_t cfg = (1 << 15) | 50000;  /* Enable + 50000 cycle interval */
    csr_write(CSR_ECC_SCRUB_CFG, cfg);

    uint32_t rdback = csr_read(CSR_ECC_SCRUB_CFG);
    if (rdback == cfg) {
        return TEST_PASS;
    }
    return TEST_FAIL;
}

/* Test: SMU Fault Code Read */
int test_smu_status(void) {
    uint32_t fault = csr_read(CSR_SMU_FAULT_CODE);
    /* After reset, no faults should be latched */
    if (fault == 0) {
        return TEST_PASS;
    }
    return TEST_FAIL;
}

/* Test: Power Status Read */
int test_power_status(void) {
    uint32_t status = csr_read(CSR_POWER_STATUS);
    /* After reset, should be in RUN state (0x1) */
    if ((status & 0xF) == 0x1) {
        return TEST_PASS;
    }
    return TEST_FAIL;
}

/* TCM Write/Read Test */
int test_tcm_access(void) {
    volatile uint32_t *test_addr = (volatile uint32_t *)0x00010000;
    *test_addr = 0xDEADBEEF;
    if (*test_addr == 0xDEADBEEF) {
        return TEST_PASS;
    }
    return TEST_FAIL;
}

/* Main Test Entry */
int main(void) {
    int results = 0;

    results += test_watchdog();
    results += test_ecc_scrub();
    results += test_smu_status();
    results += test_power_status();
    results += test_tcm_access();

    /* Write results to known TCM address for RTL testbench verification */
    volatile uint32_t *result_addr = (volatile uint32_t *)0x0001FFFC;
    *result_addr = (uint32_t)results;

    /* Halt */
    while (1) {
        asm volatile("wfi");
    }

    return 0;
}
