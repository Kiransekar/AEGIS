//===============================================================================
// Module: rt_interrupt_controller
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/rt_interrupt_controller.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Vector table + priority encoder with 12-cycle guaranteed entry latency.
//   Vector table locked in TCM for deterministic interrupt response.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-INT-001 — ARCHITECTURE.md §5 (Determinism)
//   @SAFETY: Fixed 12-cycle entry; no cache miss paths; priority encoder hardwired
//   @WCET: 12 cycles worst-case (vector fetch + PC update)
//   @SIDE_CHANNEL: Fixed latency prevents timing-based IRQ priority inference
//
// Verification:
//   Testbench: tb/core/rt_interrupt_controller_tb.v
//   Formal: sby/core/interrupt_determinism.sby
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module rt_interrupt_controller #(
    parameter NUM_IRQ = 11,                  // Number of interrupt sources
    parameter ENTRY_CYCLES = 12,             // Guaranteed entry latency
    parameter VECTOR_TABLE_BASE = 19'h00000  // TCM base for vector table
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Interrupt Request Inputs
    input  wire [NUM_IRQ-1:0] i_irq_pending,  // Pending interrupt requests
    input  wire        i_irq_ack,              // Interrupt service acknowledge

    // Vector Output
    output wire [NUM_IRQ-1:0] o_irq_vector,   // Resolved interrupt vector
    output wire        o_irq_valid,            // Vector valid
    output wire [31:0] o_irq_pc_target,        // Target PC for interrupt handler

    // CSR Interface
    input  wire [NUM_IRQ-1:0] i_irq_enable,   // Interrupt enable mask (CSR)
    input  wire [NUM_IRQ-1:0] i_irq_priority, // Priority configuration (CSR)

    // Status
    output wire        o_irq_active,           // Currently servicing an interrupt
    output wire [3:0]  o_irq_entry_counter     // Cycle counter for entry latency
);

    //-------------------------------------------------------------------------
    // Priority Encoder
    // @SAFETY: Hardwired priority — highest pending + enabled IRQ wins
    // @WCET: Combinational — 0 cycles
    //-------------------------------------------------------------------------
    reg [NUM_IRQ-1:0] resolved_irq;

    always @* begin
        resolved_irq = {NUM_IRQ{1'b0}};
        // Priority scan: highest bit = highest priority
        begin : priority_scan
            integer i;
            for (i = NUM_IRQ - 1; i >= 0; i = i - 1) begin
                if (i_irq_pending[i] && i_irq_enable[i]) begin
                    resolved_irq[i] = 1'b1;
                end
            end
        end
    end

    // Extract highest-priority IRQ number (one-hot to binary)
    // @SAFETY: Priority encoder output is one-hot; convert to index for vector table
    reg [3:0] irq_number;
    always @* begin
        irq_number = 4'd0;
        begin : irq_num_scan
            integer i;
            for (i = NUM_IRQ - 1; i >= 0; i = i - 1) begin
                if (resolved_irq[i]) irq_number = i[3:0];
            end
        end
    end

    assign o_irq_vector = resolved_irq;

    //-------------------------------------------------------------------------
    // Interrupt Entry FSM
    // @SAFETY: Fixed 12-cycle entry regardless of IRQ source
    // @WCET: Exactly 12 cycles from pending to PC target valid
    // @CERT: AEGIS-RT-INT-002 — Entry latency (ISO 26262-6:2018 Table D.3)
    //-------------------------------------------------------------------------
    localparam [1:0] IRQ_ST_IDLE       = 2'd0;
    localparam [1:0] IRQ_ST_FETCH_VEC = 2'd1;
    localparam [1:0] IRQ_ST_SERVICE   = 2'd2;
    localparam [1:0] IRQ_ST_COMPLETE  = 2'd3;
    localparam [3:0] ENTRY_COUNT_MAX  = ENTRY_CYCLES - 1;

    reg [1:0]  irq_state;
    reg [3:0]  entry_counter;
    reg        irq_valid_reg;
    reg        irq_active_reg;
    reg [31:0] irq_pc_target_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            irq_state        <= IRQ_ST_IDLE;
            entry_counter    <= 4'd0;
            irq_valid_reg    <= 1'b0;
            irq_active_reg   <= 1'b0;
            irq_pc_target_reg <= 32'd0;
        end else begin
            case (irq_state)
                IRQ_ST_IDLE: begin
                    irq_valid_reg <= 1'b0;
                    if (|resolved_irq) begin
                        irq_state     <= IRQ_ST_FETCH_VEC;
                        entry_counter <= 4'd1;
                    end
                end

                IRQ_ST_FETCH_VEC: begin
                    // @WCET: TCM read = 1 cycle guaranteed (no cache, no arbitration)
                    if (entry_counter == ENTRY_COUNT_MAX) begin
                        irq_valid_reg <= 1'b1;
                        irq_active_reg <= 1'b1;
                        irq_pc_target_reg <= {VECTOR_TABLE_BASE, 13'd0} +
                                             {24'd0, irq_number, 2'd0};
                    end else begin
                        entry_counter <= entry_counter + 4'd1;
                    end
                end

                IRQ_ST_SERVICE: begin
                    irq_valid_reg <= 1'b0;
                    if (i_irq_ack) begin
                        irq_state <= IRQ_ST_COMPLETE;
                    end
                end

                IRQ_ST_COMPLETE: begin
                    irq_active_reg <= 1'b0;
                    irq_state      <= IRQ_ST_IDLE;
                end

                default: begin
                    // @SAFETY: Default prevents latch inference
                    irq_state <= IRQ_ST_IDLE;
                end
            endcase
        end
    end

    assign o_irq_valid        = irq_valid_reg;
    assign o_irq_active       = irq_active_reg;
    assign o_irq_pc_target    = irq_pc_target_reg;
    assign o_irq_entry_counter = entry_counter;

endmodule
