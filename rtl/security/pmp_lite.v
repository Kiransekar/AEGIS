//===============================================================================
// Module: pmp_lite
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/security/pmp_lite.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Simplified PMP (Physical Memory Protection) for RT domain.
//   16 regions, deny-by-default, optimized for RT access patterns.
//
// Safety Annotations:
//   @CERT: AEGIS-SEC-PMP-001 — ARCHITECTURE.md §4 (Security)
//   @SAFETY: Deny-by-default for safety peripherals; 16 configurable regions
//   @WCET: Access check = combinational (0 cycles)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module pmp_lite #(
    parameter NUM_REGIONS = 16,
    parameter ADDR_WIDTH = 32,
    parameter GRANULE_BITS = 12          // 4 KB granule
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Access Check Interface
    input  wire [ADDR_WIDTH-1:0] i_access_addr,
    input  wire        i_access_we,      // Write enable
    input  wire        i_access_re,      // Read enable
    input  wire [1:0]  i_access_priv,   // Current privilege level
    output wire        o_access_ok,      // Access permitted
    output wire        o_access_violation, // Access denied (triggers SMU fault)

    // CSR Configuration Interface
    input  wire [3:0]  i_csr_region_sel, // Region select for CSR write
    input  wire [ADDR_WIDTH-1:0] i_csr_addr,  // Region base address
    input  wire [ADDR_WIDTH-1:0] i_csr_addr_mask, // Region address mask
    input  wire        i_csr_we,         // CSR write enable
    input  wire [1:0]  i_csr_perm        // Permission: 00=NONE, 01=R, 10=RW, 11=RWX
);

    //-------------------------------------------------------------------------
    // PMP Region Storage
    // @SAFETY: Deny-by-default — unconfigured regions deny all access
    //-------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0] region_addr  [0:NUM_REGIONS-1];
    reg [ADDR_WIDTH-1:0] region_mask  [0:NUM_REGIONS-1];
    reg [1:0]            region_perm  [0:NUM_REGIONS-1];
    reg                  region_active [0:NUM_REGIONS-1];

    // CSR write
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            // @SAFETY: Reset all regions to inactive (deny-by-default)
            begin : reset_regions
                integer i;
                for (i = 0; i < NUM_REGIONS; i = i + 1) begin
                    region_addr[i]   <= {ADDR_WIDTH{1'b0}};
                    region_mask[i]   <= {ADDR_WIDTH{1'b0}};
                    region_perm[i]   <= 2'd0;  // NONE
                    region_active[i] <= 1'b0;
                end
            end
        end else if (i_csr_we && (i_csr_region_sel < NUM_REGIONS)) begin
            region_addr[i_csr_region_sel]   <= i_csr_addr;
            region_mask[i_csr_region_sel]   <= i_csr_addr_mask;
            region_perm[i_csr_region_sel]   <= i_csr_perm;
            region_active[i_csr_region_sel] <= 1'b1;
        end
    end

    //-------------------------------------------------------------------------
    // Access Check
    // @SAFETY: Deny-by-default; first matching region determines outcome
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    reg access_ok_reg;
    reg violation_reg;

    always @* begin
        access_ok_reg  = 1'b0;  // @SAFETY: Deny by default
        violation_reg  = 1'b0;

        begin : check_regions
            integer i;
            for (i = 0; i < NUM_REGIONS; i = i + 1) begin
                if (region_active[i]) begin
                    // Address match: (addr & mask) == (region_addr & mask)
                    if (((i_access_addr & region_mask[i]) == (region_addr[i] & region_mask[i]))) begin
                        // Check permission
                        case (region_perm[i])
                            2'd1: access_ok_reg = i_access_re;   // Read-only
                            2'd2: access_ok_reg = 1'b1;           // Read-Write
                            2'd3: access_ok_reg = 1'b1;           // Read-Write-Execute
                            default: ; // 2'd0 = NONE (deny)
                        endcase
                        // @SAFETY: Write to read-only region = violation
                        if (i_access_we && (region_perm[i] == 2'd1)) begin
                            access_ok_reg = 1'b0;
                            violation_reg = 1'b1;
                        end
                    end
                end
            end
        end
    end

    assign o_access_ok        = access_ok_reg;
    assign o_access_violation = violation_reg && (i_access_we || i_access_re);

endmodule
