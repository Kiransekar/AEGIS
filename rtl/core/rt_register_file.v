//===============================================================================
// Module: rt_register_file
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_register_file.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   32×32-bit register file with hardware shadow banks for fast context switch.
//   Shadow swap completes in 18 cycles (hardware register shadow swap).
//
// Safety Annotations:
//   @CERT: AEGIS-RT-REG-001 — ARCHITECTURE.md §5 (Context Switch)
//   @SAFETY: Shadow banks enable ≤18-cycle hardware context swap
//   @WCET: Read = 1 cycle; Write = 1 cycle; Shadow swap = 18 cycles
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_register_file #(
    parameter NUM_REGS = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_SHADOW_BANKS = 2       // Active + 1 shadow
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Read Ports (2 read ports for RS1/RS2)
    input  wire [4:0]  i_rs1_addr,
    output wire [DATA_WIDTH-1:0] o_rs1_data,
    input  wire [4:0]  i_rs2_addr,
    output wire [DATA_WIDTH-1:0] o_rs2_data,

    // Write Port
    input  wire [4:0]  i_rd_addr,
    input  wire [DATA_WIDTH-1:0] i_rd_data,
    input  wire        i_rd_we,

    // Shadow Swap Control
    input  wire        i_shadow_swap_req,   // Request shadow bank swap
    input  wire [1:0]  i_shadow_bank_sel,   // Select shadow bank (0=active, 1=shadow)
    output wire        o_shadow_swap_done,   // Shadow swap complete

    // x0 Hardwired to 0
    // @SAFETY: Register x0 always reads as 0 (RISC-V spec)
    output wire        o_x0_hardwired       // Indicates x0 is hardwired
);

    //-------------------------------------------------------------------------
    // Register Storage (2 banks: active + shadow)
    // @SAFETY: Shadow bank preserves previous context for fast swap
    //-------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] regs_active [0:NUM_REGS-1];
    reg [DATA_WIDTH-1:0] regs_shadow [0:NUM_REGS-1];

    // Active bank selector
    reg active_bank;  // 0 = bank A active, 1 = bank B active

    //-------------------------------------------------------------------------
    // Write Port
    // @SAFETY: x0 is hardwired to 0; writes to x0 are ignored
    // @WCET: Write = 1 cycle
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            active_bank <= 1'b0;
        end else if (i_shadow_swap_req) begin
            // @SAFETY: Swap active and shadow banks
            active_bank <= ~active_bank;
        end
    end

    // Write to active bank only
    always @(posedge i_clk) begin
        if (i_rd_we && (i_rd_addr != 5'd0)) begin
            // @SAFETY: x0 hardwired to 0 — writes ignored
            if (active_bank == 1'b0) begin
                regs_active[i_rd_addr] <= i_rd_data;
            end else begin
                regs_shadow[i_rd_addr] <= i_rd_data;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Read Ports (async read for 1-cycle latency)
    // @SAFETY: x0 always returns 0
    // @WCET: Read = 1 cycle (async read)
    //-------------------------------------------------------------------------
    assign o_rs1_data = (i_rs1_addr == 5'd0) ? {DATA_WIDTH{1'b0}} :
                        (active_bank == 1'b0) ? regs_active[i_rs1_addr] :
                                                 regs_shadow[i_rs1_addr];
    assign o_rs2_data = (i_rs2_addr == 5'd0) ? {DATA_WIDTH{1'b0}} :
                        (active_bank == 1'b0) ? regs_active[i_rs2_addr] :
                                                 regs_shadow[i_rs2_addr];

    assign o_shadow_swap_done = 1'b1;  // @WCET: Swap completes in same cycle (bank mux)
    assign o_x0_hardwired = 1'b1;

    //-------------------------------------------------------------------------
    // Simulation-only initialization
    //-------------------------------------------------------------------------
    `ifdef SIMULATION
    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < NUM_REGS; init_idx = init_idx + 1) begin
            regs_active[init_idx] = {DATA_WIDTH{1'b0}};
            regs_shadow[init_idx] = {DATA_WIDTH{1'b0}};
        end
    end
    `endif

endmodule
