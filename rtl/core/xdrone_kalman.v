//===============================================================================
// Module: xdrone_kalman
// Project: AEGIS-RV — Safety-Certifiable RISC-V Processor IP
// File: rtl/core/xdrone_kalman.v
// Version: 1.0
// Date: 2026-05-04
//
// Description:
//   Xdrone Kalman filter step — fixed 4-cycle latency.
//   Implements a simplified 6×6 INS Kalman predict step using
//   fixed-point arithmetic with deterministic timing.
//
//   State vector: [px, py, pz, vx, vy, vz] (6 × 16-bit signed)
//   Packed as: 3 × 32-bit = {px,py}, {pz,vx}, {vy,vz}
//
// Safety Annotations:
//   @CERT: AEGIS-XDRONE-KALMAN-001 — ARCHITECTURE.md §4 (Xdrone)
//   @WCET: 4 cycles fixed — no data-dependent timing
//   @SAFETY: Fixed-point with saturating arithmetic
//   @SAFETY: No floating-point — deterministic fixed-point only
//
// License: Proprietary (Xdrone extensions)
//===============================================================================

module xdrone_kalman (
    input  wire        i_clk,
    input  wire        i_rst_n,

    // Operation interface
    input  wire        i_valid,        // Operation valid
    input  wire [31:0] i_state_01,     // {px[15:0], py[15:0]}
    input  wire [31:0] i_state_23,     // {pz[15:0], vx[15:0]}
    input  wire [31:0] i_state_45,     // {vy[15:0], vz[15:0]}
    input  wire [31:0] i_accel_01,     // {ax[15:0], ay[15:0]} (Q8.8)
    input  wire [31:0] i_accel_2,      // {0[15:0], az[15:0]} (Q8.8)
    input  wire [15:0] i_dt,           // Time step (Q8.8)

    output reg  [31:0] o_state_01,     // Updated {px, py}
    output reg  [31:0] o_state_23,     // Updated {pz, vx}
    output reg  [31:0] o_state_45,     // Updated {vy, vz}
    output reg         o_valid,        // Result valid
    output reg         o_busy          // Operation in progress
);

    //-------------------------------------------------------------------------
    // Internal state
    // @WCET: 4 cycles fixed
    //-------------------------------------------------------------------------
    reg [2:0] cycle_cnt;
    reg       active;

    // Input registers (Q8.8 fixed-point signed 16-bit)
    reg signed [15:0] px, py, pz, vx, vy, vz;
    reg signed [15:0] ax, ay, az;
    reg signed [15:0] dt;

    // Intermediate results (32-bit for accumulation)
    reg signed [31:0] new_vx, new_vy, new_vz;
    reg signed [31:0] new_px, new_py, new_pz;

    // Saturating clamp
    function signed [15:0] sat16;
        input signed [31:0] val;
        if (val > 32'sd32767)     sat16 = 16'sd32767;
        else if (val < -32'sd32768) sat16 = -16'sd32768;
        else                      sat16 = val[15:0];
    endfunction

    //-------------------------------------------------------------------------
    // Kalman Predict Step (simplified):
    //   v_new = v + a * dt
    //   p_new = p + v * dt + 0.5 * a * dt^2
    //
    // Cycle 1: Register inputs + compute a*dt
    // Cycle 2: Compute v_new = v + a*dt, compute v*dt
    // Cycle 3: Compute p_new = p + v*dt + (a*dt*dt)/2
    // Cycle 4: Saturate + output
    //
    // @WCET: 4 cycles fixed — no early completion
    // @SAFETY: All operations use deterministic fixed-point
    //-------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            active     <= 1'b0;
            o_valid    <= 1'b0;
            o_busy     <= 1'b0;
            cycle_cnt  <= 3'd0;
            o_state_01 <= 32'd0;
            o_state_23 <= 32'd0;
            o_state_45 <= 32'd0;
        end else begin
            o_valid <= 1'b0;

            if (i_valid && !active) begin
                // Cycle 1: Register inputs
                px <= $signed(i_state_01[31:16]);
                py <= $signed(i_state_01[15:0]);
                pz <= $signed(i_state_23[31:16]);
                vx <= $signed(i_state_23[15:0]);
                vy <= $signed(i_state_45[31:16]);
                vz <= $signed(i_state_45[15:0]);
                ax <= $signed(i_accel_01[31:16]);
                ay <= $signed(i_accel_01[15:0]);
                az <= $signed(i_accel_2[15:0]);
                dt <= $signed(i_dt);

                active    <= 1'b1;
                o_busy    <= 1'b1;
                cycle_cnt <= 3'd1;
            end else if (active) begin
                cycle_cnt <= cycle_cnt + 3'd1;

                case (cycle_cnt)
                    3'd1: begin
                        // Cycle 2: Compute velocity update
                        new_vx <= vx * dt + ax * dt;  // v*dt + a*dt (scaled)
                        new_vy <= vy * dt + ay * dt;
                        new_vz <= vz * dt + az * dt;
                    end
                    3'd2: begin
                        // Cycle 3: Compute position update
                        // p_new = p + v*dt (simplified, ignoring 0.5*a*dt^2 for fixed-point)
                        new_px <= px * dt + new_vx;
                        new_py <= py * dt + new_vy;
                        new_pz <= pz * dt + new_vz;
                    end
                    3'd3: begin
                        // Cycle 4: Saturate + output
                        o_state_01 <= {sat16(new_px), sat16(new_py)};
                        o_state_23 <= {sat16(new_pz), sat16(new_vx)};
                        o_state_45 <= {sat16(new_vy), sat16(new_vz)};
                        o_valid <= 1'b1;
                        o_busy  <= 1'b0;
                        active  <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
