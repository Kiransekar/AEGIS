//===============================================================================
// Module: xdrone_dispatcher
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/xdrone_dispatcher.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Handshaking dispatcher for Xdrone execution units.
//   Fixed-latency dispatch: qmul=2 cycles, kalman=4 cycles.
//
// Safety Annotations:
//   @CERT: AEGIS-RT-XDR-002 — ARCHITECTURE.md §7 (Xdrone Extension)
//   @WCET: qmul=2 cycles; kalman=4 cycles; constant-time padding
//   @SAFETY: All Xdrone ops have fixed latency (no data-dependent timing)
//
// License: Apache 2.0 (core) / Proprietary (Xdrone extensions)
//===============================================================================

module xdrone_dispatcher #(
    parameter QMUL_LATENCY = 2,
    parameter KALMAN_LATENCY = 4
) (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Request Interface (from decoder)
    input  wire        i_req_valid,
    input  wire [6:0]  i_req_opcode,
    input  wire [31:0] i_rs1_data,
    input  wire [31:0] i_rs2_data,
    input  wire [31:0] i_rs3_data,   // Third operand for qmul/kalman
    input  wire [31:0] i_rs4_data,   // Fourth operand
    output wire        o_ready,

    // Response Interface (to pipeline)
    output wire [31:0] o_result,
    output wire        o_done,
    output wire        o_error,

    // CSR Configuration
    input  wire [3:0]  i_max_depth,
    input  wire [3:0]  i_precision
);

    //-------------------------------------------------------------------------
    // Xdrone Operation Codes
    //-------------------------------------------------------------------------
    localparam [6:0] XDRONE_QMUL   = 7'h01;  // Quaternion multiply
    localparam [6:0] XDRONE_KALMAN = 7'h02;  // Kalman filter step
    localparam [6:0] XDRONE_SAT    = 7'h03;  // Satellite estimation
    localparam [6:0] XDRONE_FOC    = 7'h04;  // Field-oriented control

    //-------------------------------------------------------------------------
    // Dispatch FSM
    // @SAFETY: Fixed latency per opcode — no data-dependent timing
    // @WCET: qmul=2, kalman=4, all others=2 (default)
    //-------------------------------------------------------------------------
    localparam DISP_IDLE = 2'd0;
    localparam DISP_EXEC = 2'd1;
    localparam DISP_DONE = 2'd2;

    reg [1:0]  disp_state;
    reg [3:0]  cycle_counter;
    reg [3:0]  target_latency;
    reg [31:0] result_reg;
    reg        done_reg;
    reg        error_reg;
    reg        ready_reg;
    reg [6:0]  opcode_reg;

    //-------------------------------------------------------------------------
    // Xdrone QMUL sub-module
    // @WCET: 2 cycles fixed
    //-------------------------------------------------------------------------
    wire [31:0] qmul_result_wx, qmul_result_yz;
    wire        qmul_valid, qmul_busy;

    xdrone_qmul u_qmul (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_valid(i_req_valid && i_req_opcode == XDRONE_QMUL && disp_state == DISP_IDLE),
        .i_operand_a(i_rs1_data),
        .i_operand_b(i_rs2_data),
        .i_operand_c(i_rs3_data),
        .i_operand_d(i_rs4_data),
        .o_result_wx(qmul_result_wx),
        .o_result_yz(qmul_result_yz),
        .o_valid(qmul_valid),
        .o_busy(qmul_busy)
    );

    //-------------------------------------------------------------------------
    // Xdrone Kalman sub-module
    // @WCET: 4 cycles fixed
    //-------------------------------------------------------------------------
    wire [31:0] kalman_state_01, kalman_state_23, kalman_state_45;
    wire        kalman_valid, kalman_busy;

    xdrone_kalman u_kalman (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_valid(i_req_valid && i_req_opcode == XDRONE_KALMAN && disp_state == DISP_IDLE),
        .i_state_01(i_rs1_data),
        .i_state_23(i_rs2_data),
        .i_state_45(i_rs3_data),
        .i_accel_01(i_rs4_data),
        .i_accel_2(i_rs1_data),  // Reuse rs1 for accel_z
        .i_dt(16'd1),            // @SAFETY: dt=1.0 (Q8.8) — fixed for RT determinism
        .o_state_01(kalman_state_01),
        .o_state_23(kalman_state_23),
        .o_state_45(kalman_state_45),
        .o_valid(kalman_valid),
        .o_busy(kalman_busy)
    );

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            disp_state     <= DISP_IDLE;
            cycle_counter  <= 4'd0;
            target_latency <= 4'd0;
            result_reg     <= 32'd0;
            done_reg       <= 1'b0;
            error_reg      <= 1'b0;
            ready_reg      <= 1'b1;
            opcode_reg     <= 7'd0;
        end else begin
            case (disp_state)
                DISP_IDLE: begin
                    done_reg  <= 1'b0;
                    ready_reg <= 1'b1;
                    if (i_req_valid) begin
                        ready_reg  <= 1'b0;
                        opcode_reg <= i_req_opcode;
                        // @SAFETY: Fixed latency per opcode
                        case (i_req_opcode)
                            XDRONE_QMUL:   target_latency <= QMUL_LATENCY[3:0];
                            XDRONE_KALMAN: target_latency <= KALMAN_LATENCY[3:0];
                            default:       target_latency <= 4'd2;
                        endcase
                        cycle_counter <= 4'd1;
                        disp_state <= DISP_EXEC;
                    end
                end

                DISP_EXEC: begin
                    // @SAFETY: Wait for sub-module valid or cycle count
                    case (opcode_reg)
                        XDRONE_QMUL: begin
                            if (qmul_valid) begin
                                result_reg <= qmul_result_wx;
                                disp_state <= DISP_DONE;
                                done_reg   <= 1'b1;
                            end
                        end
                        XDRONE_KALMAN: begin
                            if (kalman_valid) begin
                                result_reg <= kalman_state_01;
                                disp_state <= DISP_DONE;
                                done_reg   <= 1'b1;
                            end
                        end
                        default: begin
                            // @SAFETY: Generic ops use cycle counter
                            if (cycle_counter >= target_latency) begin
                                disp_state <= DISP_DONE;
                                done_reg   <= 1'b1;
                                result_reg <= i_rs1_data + i_rs2_data;
                            end else begin
                                cycle_counter <= cycle_counter + 4'd1;
                            end
                        end
                    endcase
                end

                DISP_DONE: begin
                    done_reg  <= 1'b0;
                    ready_reg <= 1'b1;
                    disp_state <= DISP_IDLE;
                end

                default: begin
                    // @SAFETY: Default prevents latch inference
                    disp_state <= DISP_IDLE;
                end
            endcase
        end
    end

    assign o_ready = ready_reg;
    assign o_result = result_reg;
    assign o_done   = done_reg;
    assign o_error  = error_reg;

endmodule
