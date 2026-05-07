//===============================================================================
// Module: tb_memory_model
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: tb/tb_memory_model.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Behavioral SRAM/TCM model with fault injection capability.
//   Supports single-bit and double-bit error injection for ECC testing.
//   Used as a drop-in replacement for scratchpad_bank in simulation.
//
// Safety Annotations:
//   @SAFETY: Fault injection controlled by testbench only
//   @CERT: Used for ISO 26262 fault injection test evidence
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module tb_memory_model #(
    parameter ADDR_WIDTH = 17,       // 128K words = 256 KB
    parameter DATA_WIDTH = 32,
    parameter ECC_WIDTH  = 7,        // SECDED(39,32) → 7 check bits
    parameter CODE_WIDTH = DATA_WIDTH + ECC_WIDTH  // 39
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Memory Interface (same as scratchpad_bank)
    input  wire [ADDR_WIDTH-1:0] i_addr,
    input  wire [CODE_WIDTH-1:0] i_wdata,    // 39-bit ECC-encoded write data
    input  wire        i_we,
    input  wire        i_re,
    output wire [CODE_WIDTH-1:0] o_rdata,    // 39-bit ECC-encoded read data

    // Fault Injection Control (testbench only)
    input  wire        i_inject_fault,        // Enable fault injection
    input  wire [ADDR_WIDTH-1:0] i_fault_addr,// Address to inject fault at
    input  wire [CODE_WIDTH-1:0] i_fault_mask,// Bit mask for fault injection
    input  wire [1:0]  i_fault_type,          // 00=none, 01=single-bit, 10=double-bit, 11=all-zero

    // Status
    output wire        o_fault_active,        // Fault currently injected
    output wire [31:0] o_access_count         // Total access counter
);

    //-------------------------------------------------------------------------
    // Memory Storage (behavioral)
    //-------------------------------------------------------------------------
    reg [CODE_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH) - 1];

    // Read data register
    reg [CODE_WIDTH-1:0] rdata_reg;

    // Fault state
    reg [CODE_WIDTH-1:0] fault_xor_mask;
    reg                  fault_active_reg;
    reg [31:0]           access_count_reg;

    //-------------------------------------------------------------------------
    // Fault Injection Logic
    // @SAFETY: Only active when i_inject_fault is asserted
    //-------------------------------------------------------------------------
    always @* begin
        fault_xor_mask = {CODE_WIDTH{1'b0}};
        if (i_inject_fault && (i_addr == i_fault_addr)) begin
            case (i_fault_type)
                2'd01: begin
                    // Single-bit error: XOR with one bit
                    fault_xor_mask = i_fault_mask;
                end
                2'd10: begin
                    // Double-bit error: XOR with two bits
                    fault_xor_mask = i_fault_mask;
                end
                2'd11: begin
                    // All-zero: return zero data
                    fault_xor_mask = {CODE_WIDTH{1'b1}};
                end
                default: fault_xor_mask = {CODE_WIDTH{1'b0}};
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // Write Logic
    //-------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (i_we) begin
            mem[i_addr] <= i_wdata;
            access_count_reg <= access_count_reg + 32'd1;
        end
    end

    //-------------------------------------------------------------------------
    // Read Logic (with fault injection)
    //-------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (i_re) begin
            if (i_inject_fault && (i_addr == i_fault_addr)) begin
                rdata_reg <= mem[i_addr] ^ fault_xor_mask;
                fault_active_reg <= 1'b1;
            end else begin
                rdata_reg <= mem[i_addr];
                fault_active_reg <= 1'b0;
            end
            access_count_reg <= access_count_reg + 32'd1;
        end else begin
            fault_active_reg <= 1'b0;
        end
    end

    assign o_rdata        = rdata_reg;
    assign o_fault_active = fault_active_reg;
    assign o_access_count = access_count_reg;

    //-------------------------------------------------------------------------
    // Simulation-only initialization
    //-------------------------------------------------------------------------
    `ifdef SIMULATION
    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < (1 << ADDR_WIDTH); init_idx = init_idx + 1) begin
            mem[init_idx] = {CODE_WIDTH{1'b0}};
        end
        access_count_reg = 32'd0;
        fault_active_reg = 1'b0;
        rdata_reg = {CODE_WIDTH{1'b0}};
    end
    `endif

endmodule
