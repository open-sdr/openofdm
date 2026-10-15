//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: phase
//
// Engineer: Tobias Weber
// Target Devices: Artix 7, XC7A100T
// Tool Versions: Vivado 2025.2
// Description:
// 
// Fork of the openofdm project
// https://github.com/jhshi/openofdm
//
// Four-quadrant arctangent of a 32-bit complex sample, o_phase = atan2(q, i)
// in radians scaled by 2^ATAN_LUT_SCALE_SHIFT (512), range (-1608, 1608].
// The arithmetic is done by the open-source cordic_arctan core (block-floating
// point pre-normalisation, 14 iterations, round half up). LATENCY pads the
// core's natural latency with a delayT shift register so the block stays a
// 40-clock drop-in for dot11.v; LATENCY = 0 gives the natural core latency.
// 
// Dependencies: cordic_arctan.v, cordic_arctan.vh, delayT.v
// 
// Revision 1.00 - File Created
// Revision 2.00 - divider + atan_lut replaced by cordic_arctan
// Project: https://github.com/Tobias-DG3YEV/RA-Sentinel
// 
//////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2024 Tobias Weber
// License: GNU GPL v3
//
// This project is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTIBILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public License
// along with this program. If not, see
// <http://www.gnu.org/licenses/> for a copy.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`default_nettype none

`include "common_defs.v"

module phase
#(
    parameter DATA_WIDTH = 32,
    parameter LATENCY    = 40,  // i_input_strobe -> o_output_strobe; 0 = natural core latency
    parameter ITERATIONS = 14   // CORDIC iterations (residual 2^(F+1-N) = 1/16 LSB at 14)
)
(
    input wire i_clock,
    input wire i_reset,
    input wire i_enable,

    input wire signed [DATA_WIDTH-1:0] i_in_i,
    input wire signed [DATA_WIDTH-1:0] i_in_q,
    input wire i_input_strobe,

    // (-pi, pi] scaled up by 512
    output wire signed [15:0] o_phase,
    output wire o_output_strobe
);
`include "common_params.v"

// cordic_arctan.vh declares a function, so it is included inside the module.
// Its include guard is a text macro, and xvlog/Vivado keep text macros global
// across the files of one run; the header undefines its own guard at its end,
// and the `undef here makes this include immune to a stale definition.
`undef CORDIC_ARCTAN_VH
`include "cordic_arctan.vh"

//---- Derived constants ----
localparam integer PHASE_WIDTH  = 16;
localparam integer PHASE_FRAC   = `ATAN_LUT_SCALE_SHIFT;    // 9: radians * 512
localparam integer ARCH         = 1;                        // parallel (unrolled)
localparam integer PIPE_MODE    = 2;                        // register every iteration
localparam integer PRE_NORM     = 1;                        // block floating point input
localparam integer CORE_LATENCY = cordicArctanLatency(ARCH, PIPE_MODE, ITERATIONS,
                                                      PHASE_WIDTH, PHASE_FRAC, PRE_NORM);
localparam integer PAD_DELAY    = (LATENCY == 0) ? 0 : (LATENCY - CORE_LATENCY);
localparam signed [PHASE_WIDTH-1:0] PHASE_MAX = PI;         // +pi -> 1608 (common_params.v)
localparam signed [PHASE_WIDTH-1:0] PHASE_MIN = -PI;

//---- Internal signals ----
// openofdm resets are synchronous active-high; the core wants an asynchronous
// active-low reset for its valid/last flops. i_reset comes straight from
// dot11's i_reset port; every known instantiator drives that as an OR of
// flop outputs in the i_clock domain (system_top_wbmc.v: rst_rx | receiver_rst,
// openofdm_rx.v additionally ~s00_axi_aresetn), which cannot glitch towards
// assertion, and deassertion is synchronous so Vivado checks recovery/removal.
// Whoever changes the reset tree of dot11 must keep i_reset glitch-free.
wire                   rstN = ~i_reset;
wire                   corePhaseValid;
wire [PHASE_WIDTH-1:0] corePhase;
reg  signed [PHASE_WIDTH-1:0] coreSat;

//---- Submodules ----
cordic_arctan #(
    .INPUT_WIDTH     (DATA_WIDTH),
    .OUTPUT_WIDTH    (PHASE_WIDTH),
    .DATA_FORMAT     (0),
    .PHASE_FORMAT    (0),
    .PHASE_FRAC_BITS (PHASE_FRAC),
    .ROUND_MODE      (1),
    .ITERATIONS      (ITERATIONS),
    .COARSE_ROTATION (1),
    .PRE_NORMALIZE   (PRE_NORM),
    .ARCHITECTURE    (ARCH),
    .PIPELINE_MODE   (PIPE_MODE),
    .FLOW_CONTROL    (0)
) u_cordic_arctan (
    .i_clk        (i_clock),
    .i_clkEn      (i_enable),
    .i_rstN       (rstN),
    .i_xyValid    (i_input_strobe),
    .o_xyReady    (),
    .i_x          (i_in_i),
    .i_y          (i_in_q),
    .i_xyLast     (1'b0),
    .i_xyUser     (1'b0),
    .o_phaseValid (corePhaseValid),
    .i_phaseReady (1'b1),
    .o_phase      (corePhase),
    .o_phaseLast  (),
    .o_phaseUser  ()
);

// Range clamp to [-PI, PI]. The ideal +pi is 1608.495 LSB, so the core's
// half-up rounding yields 1609 whenever its residual is positive (measured on
// ~3 % of the inputs on the negative real axis); the legacy ROM path never
// exceeded PI = 1608 and the consumers (equalizer, sync_short) assume that.
// Clamping keeps |e| <= 0.5 LSB there. The -PI side is unreachable in exact
// arithmetic (angle range is (-pi, pi]) and is clamped only for symmetry.
always @(*) begin
    coreSat = $signed(corePhase);
    if ($signed(corePhase) > PHASE_MAX) begin
        coreSat = PHASE_MAX;
    end else if ($signed(corePhase) < PHASE_MIN) begin
        coreSat = PHASE_MIN;
    end
end

// Latency padding. delayT runs free of i_enable, exactly like the divider and
// the ROM of the legacy implementation did.
generate
    if (PAD_DELAY > 0) begin : gen_pad
        delayT #(
            .DATA_WIDTH (PHASE_WIDTH + 1),
            .DELAY      (PAD_DELAY)
        ) u_delayT_pad (
            .i_clock    (i_clock),
            .i_reset    (i_reset),
            .i_data_in  ({corePhaseValid, coreSat}),
            .o_data_out ({o_output_strobe, o_phase})
        );
    end else begin : gen_noPad
        assign o_output_strobe = corePhaseValid;
        assign o_phase         = coreSat;
    end
endgenerate

//---- Parameter validation ----
initial begin
    if ((LATENCY != 0) && (LATENCY < CORE_LATENCY)) begin
        $error("phase: LATENCY=%0d is smaller than the cordic_arctan core latency %0d",
               LATENCY, CORE_LATENCY);
    end
end

endmodule

`default_nettype wire
