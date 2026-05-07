//===============================================================================
// Module: xdrone_qmul
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/xdrone_qmul.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Xdrone quaternion multiply (qmul) — fixed 2-cycle latency.
//   Computes q0 * q1 where q = [w, x, y, z] stored as 4 × 16-bit
//   fixed-point values packed into two 32-bit registers.
//
//   Format: operand_a = {w0[15:0], x0[15:0]}, operand_b = {y0[15:0], z0[15:0]}
//           Second operand similarly packed.
//
// Safety Annotations:
//   @CERT: AEGIS-XDRONE-QMUL-001 — ARCHITECTURE.md §4 (Xdrone)
//   @WCET: 2 cycles fixed — no data-dependent timing
//   @SAFETY: Fixed-point arithmetic with saturating overflow
//   @SAFETY: All intermediate products computed in 32-bit to prevent overflow
//
// License: Proprietary (Xdrone extensions)
//===============================================================================

module xdrone_qmul (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Operation interface
    input  wire        i_valid,        // Operation valid
    input  wire [31:0] i_operand_a,    // q0: {w0[15:0], x0[15:0]}
    input  wire [31:0] i_operand_b,    // q1: {w1[15:0], x1[15:0]}
    input  wire [31:0] i_operand_c,    // q0: {y0[15:0], z0[15:0]}
    input  wire [31:0] i_operand_d,    // q1: {y1[15:0], z1[15:0]}

    output reg  [31:0] o_result_wx,    // Result: {w[15:0], x[15:0]}
    output reg  [31:0] o_result_yz,    // Result: {y[15:0], z[15:0]}
    output reg         o_valid,        // Result valid
    output reg         o_busy          // Operation in progress
);

    //-------------------------------------------------------------------------
    // Internal state
    // @WCET: 2 cycles fixed
    //-------------------------------------------------------------------------
    reg [1:0] cycle_cnt;
    reg       active;

    // Input registers
    reg signed [15:0] w0, x0, y0, z0;
    reg signed [15:0] w1, x1, y1, z1;

    // Intermediate products (32-bit to prevent overflow)
    reg signed [31:0] prod_ww, prod_xx, prod_yy, prod_zz;
    reg signed [31:0] prod_wx_xw;   // w0*x1 + x0*w1
    reg signed [31:0] prod_wy_yw;   // w0*y1 + y0*w1
    reg signed [31:0] prod_wz_zw;   // w0*z1 + z0*w1
    reg signed [31:0] prod_xz_zy;   // x0*z1 - z0*y1  (for x component)
    reg signed [31:0] prod_xy_yz;   // x0*y1 + y0*z1  (for z component)
    reg signed [31:0] prod_yw_xz;   // y0*w1 - x0*z1  (for y component)
    reg signed [31:0] prod_yx_zw;   // y0*x1 - z0*w1  (for z component negated)

    // Saturating clamp to 16-bit signed range
    function signed [15:0] sat16;
        input signed [31:0] val;
        if (val > 32'sd32767)     sat16 = 16'sd32767;
        else if (val < -32'sd32768) sat16 = -16'sd32768;
        else                      sat16 = val[15:0];
    endfunction

    //-------------------------------------------------------------------------
    // Cycle 1: Register inputs + compute products
    // Cycle 2: Sum products + saturate + output
    // @WCET: 2 cycles fixed — no early completion
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            active    <= 1'b0;
            o_valid   <= 1'b0;
            o_busy    <= 1'b0;
            cycle_cnt <= 2'd0;
            o_result_wx <= 32'd0;
            o_result_yz <= 32'd0;
        end else begin
            o_valid <= 1'b0;

            if (i_valid && !active) begin
                // Register inputs (signed 16-bit each)
                w0 <= $signed(i_operand_a[31:16]);
                x0 <= $signed(i_operand_a[15:0]);
                y0 <= $signed(i_operand_c[31:16]);
                z0 <= $signed(i_operand_c[15:0]);
                w1 <= $signed(i_operand_b[31:16]);
                x1 <= $signed(i_operand_b[15:0]);
                y1 <= $signed(i_operand_d[31:16]);
                z1 <= $signed(i_operand_d[15:0]);

                // Compute all products from current inputs (cycle 1)
                // @SAFETY: Products computed from input ports, not registered values
                // Hamilton product: q = q0 * q1
                prod_ww  <= $signed(i_operand_a[31:16]) * $signed(i_operand_b[31:16]);  // w0*w1
                prod_xx  <= $signed(i_operand_a[15:0])  * $signed(i_operand_b[15:0]);   // x0*x1
                prod_yy  <= $signed(i_operand_c[31:16]) * $signed(i_operand_d[31:16]);  // y0*y1
                prod_zz  <= $signed(i_operand_c[15:0])  * $signed(i_operand_d[15:0]);   // z0*z1
                prod_wx_xw <= $signed(i_operand_a[31:16]) * $signed(i_operand_b[15:0])
                            + $signed(i_operand_a[15:0])  * $signed(i_operand_b[31:16]); // w0*x1+x0*w1
                prod_wy_yw <= $signed(i_operand_a[31:16]) * $signed(i_operand_d[31:16])
                            + $signed(i_operand_c[31:16]) * $signed(i_operand_b[31:16]); // w0*y1+y0*w1
                prod_wz_zw <= $signed(i_operand_a[31:16]) * $signed(i_operand_d[15:0])
                            + $signed(i_operand_c[15:0])  * $signed(i_operand_b[31:16]); // w0*z1+z0*w1
                prod_xz_zy <= $signed(i_operand_a[15:0])  * $signed(i_operand_d[15:0])
                            - $signed(i_operand_c[15:0])  * $signed(i_operand_d[31:16]); // x0*z1-z0*y1
                prod_xy_yz <= $signed(i_operand_a[15:0])  * $signed(i_operand_d[31:16])
                            - $signed(i_operand_c[31:16]) * $signed(i_operand_a[15:0]);  // x0*y1-y0*x1
                prod_yw_xz <= $signed(i_operand_c[31:16]) * $signed(i_operand_b[31:16])
                            - $signed(i_operand_a[15:0])  * $signed(i_operand_d[15:0]);  // y0*w1-x0*z1
                prod_yx_zw <= $signed(i_operand_c[31:16]) * $signed(i_operand_b[15:0])
                            - $signed(i_operand_c[15:0])  * $signed(i_operand_b[31:16]); // y0*x1-z0*w1

                active    <= 1'b1;
                o_busy    <= 1'b1;
                cycle_cnt <= 2'd1;
            end else if (active) begin
                cycle_cnt <= cycle_cnt + 2'd1;

                if (cycle_cnt == 2'd1) begin
                    // Cycle 2: Sum products + saturate
                    // q = q0 * q1 (Hamilton product):
                    //   w = w0*w1 - x0*x1 - y0*y1 - z0*z1
                    //   x = w0*x1 + x0*w1 + y0*z1 - z0*y1
                    //   y = w0*y1 - x0*z1 + y0*w1 + z0*x1
                    //   z = w0*z1 + x0*y1 - y0*x1 + z0*w1
                    // @SAFETY: Q8.8 products are Q16.16; right-shift by 8 to rescale to Q8.8
                    o_result_wx <= {sat16((prod_ww - prod_xx - prod_yy - prod_zz) >>> 8),
                                    sat16((prod_wx_xw + prod_xz_zy) >>> 8)};
                    o_result_yz <= {sat16((prod_wy_yw + prod_yw_xz) >>> 8),
                                    sat16((prod_wz_zw + prod_xy_yz) >>> 8)};

                    o_valid <= 1'b1;
                    o_busy  <= 1'b0;
                    active  <= 1'b0;
                end
            end
        end
    end

endmodule
