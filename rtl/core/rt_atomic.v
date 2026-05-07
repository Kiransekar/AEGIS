//===============================================================================
// Module: rt_atomic
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_atomic.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   RV32A atomic memory operations unit (LR.W / SC.W).
//   Implements load-reserved / store-conditional semantics with
//   reservation set tracking for deterministic atomic access.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-ATOM-001 — ARCHITECTURE.md §3 (A Extension)
//   @WCET: LR.W = 1 cycle; SC.W = 1 cycle (success/fail combinational)
//   @SAFETY: Reservation set invalidated on any write to reserved address
//   @SAFETY: SC.W fail returns 1 (non-zero) per RISC-V spec
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_atomic #(
    parameter ADDR_WIDTH = 19
) (
    input  wire                        i_clk,
    input  wire                        i_rst_n,

    // Atomic operation interface
    input  wire                        i_lr_req,       // LR.W request
    input  wire                        i_sc_req,       // SC.W request
    input  wire [ADDR_WIDTH-1:0]       i_addr,         // Memory address
    input  wire [31:0]                 i_sc_data,      // SC.W write data
    output reg  [31:0]                 o_lr_data,      // LR.W read data
    output reg                         o_sc_success,   // SC.W success (0=pass, 1=fail per spec)
    output reg                         o_valid,        // Operation complete

    // Memory interface (for reservation tracking)
    input  wire [31:0]                 i_mem_rdata,    // Memory read data
    output wire [ADDR_WIDTH-1:0]       o_mem_addr,     // Memory address
    output wire                        o_mem_re,       // Memory read enable
    output wire [31:0]                 o_mem_wdata,    // Memory write data
    output wire                        o_mem_we,       // Memory write enable

    // Reservation invalidation from external writes
    input  wire                        i_ext_write,    // External write occurred
    input  wire [ADDR_WIDTH-1:0]       i_ext_write_addr // External write address
);

    //-------------------------------------------------------------------------
    // Reservation Set
    // @SAFETY: Single-entry reservation set (sufficient for RT single-core)
    //-------------------------------------------------------------------------
    reg                        reservation_valid;
    reg [ADDR_WIDTH-1:0]       reservation_addr;

    //-------------------------------------------------------------------------
    // LR.W: Load Reserved
    // @WCET: 1 cycle — read memory + set reservation
    // @SAFETY: Sets reservation on current address
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            reservation_valid <= 1'b0;
            reservation_addr  <= {ADDR_WIDTH{1'b0}};
            o_valid           <= 1'b0;
            o_lr_data         <= 32'd0;
            o_sc_success      <= 1'b1;  // Default: fail
        end else begin
            o_valid <= 1'b0;

            if (i_lr_req) begin
                // Set reservation
                reservation_valid <= 1'b1;
                reservation_addr  <= i_addr;
                o_lr_data         <= i_mem_rdata;
                o_valid           <= 1'b1;
                o_sc_success      <= 1'b1;  // Not applicable for LR
            end else if (i_sc_req) begin
                if (reservation_valid && (reservation_addr == i_addr)) begin
                    // @SAFETY: Reservation matches — SC succeeds
                    o_sc_success      <= 1'b0;  // Success (0 per RISC-V spec)
                    reservation_valid <= 1'b0;  // Clear reservation
                end else begin
                    // @SAFETY: No reservation or address mismatch — SC fails
                    o_sc_success <= 1'b1;  // Fail (1 per RISC-V spec)
                end
                o_valid <= 1'b1;
            end

            // @SAFETY: Invalidate reservation on external write to same address
            if (i_ext_write && reservation_valid) begin
                // Word-aligned comparison
                if (i_ext_write_addr[ADDR_WIDTH-1:2] == reservation_addr[ADDR_WIDTH-1:2]) begin
                    reservation_valid <= 1'b0;
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Memory interface pass-through
    //-------------------------------------------------------------------------
    assign o_mem_addr  = i_addr;
    assign o_mem_re    = i_lr_req;
    assign o_mem_wdata = i_sc_data;
    assign o_mem_we    = i_sc_req && reservation_valid && (reservation_addr == i_addr);

endmodule
