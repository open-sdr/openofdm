//----------------------------------------------------------------------------
// Module : cordic_arctan
// Purpose: Vendor-neutral CORDIC arctangent (atan2) core, AXI-Stream style.
// Open replacement for the AMD/Xilinx CORDIC 6.0 core in Arc_Tan mode:
// same configuration space (architecture, pipelining, data/phase format,
// widths, round mode, iterations, precision, coarse rotation, flow control,
// TLAST/TUSER, ACLKEN, ARESETN) plus a block-floating-point input
// normalisation (LZC + barrel shift) so that 32-bit inputs whose magnitude
// spans 2^0 .. 2^31 keep full angular accuracy with a short datapath.
// Pure integer arithmetic (Verilog-2001, no 'real'); the angle constants are
// an embedded Q4.60 table (spec 1.2), rounded to the internal angle width.
//
// Output format: o_phase = round(angle * 2^F) in OUTPUT_WIDTH bits, two's
// complement; angle in radians (PHASE_FORMAT 0) or in units of pi
// (PHASE_FORMAT 1). Bits above F+3 wrap naturally, so scaled radians with
// F = OUTPUT_WIDTH-1 are modular binary turns (+pi wraps to -pi).
// Latency: see cordic_arctan.vh (cordicArctanLatency), spec 1.1.
//
// Project: RA-Sentinel (NLnet) - fork of openofdm,
//          https://github.com/Tobias-DG3YEV/openofdm
// Engineer: Tobias Weber
//----------------------------------------------------------------------------
// Copyright 2026 Tobias Weber
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may
// not use this file except in compliance with the License. You may obtain
// a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module cordic_arctan #(
    parameter integer INPUT_WIDTH     = 16, // 2..48  width of i_x and i_y
    parameter integer OUTPUT_WIDTH    = 16, // 2..48  width of o_phase
    parameter integer DATA_FORMAT     = 0,  // 0 signed two's complement (full plane)
                                            // 1 unsigned (first quadrant only)
    parameter integer PHASE_FORMAT    = 0,  // 0 radians, 1 scaled radians (units of pi)
    parameter integer PHASE_FRAC_BITS = 0,  // 0 auto = OUTPUT_WIDTH-3 (Xilinx 2QN);
                                            // else number of fractional bits of o_phase
    parameter integer ROUND_MODE      = 0,  // 0 Truncate (floor)
                                            // 1 Round_Pos_Inf (half up)
                                            // 2 Round_Pos_Neg_Inf (half away from zero)
                                            // 3 Nearest_Even (half to even)
    parameter integer ITERATIONS      = 0,  // 0 auto = min(48, F+3); else 1..48
    parameter integer PRECISION       = 0,  // 0 auto; else internal x/y precision bits P
    parameter integer COARSE_ROTATION = 1,  // 1 full circle (-pi, pi]; 0 right half plane
    parameter integer PRE_NORMALIZE   = 1,  // 1 LZC + barrel shift before iterating
    parameter integer ARCHITECTURE    = 1,  // 1 Parallel (unrolled), 0 Word_Serial
    parameter integer PIPELINE_MODE   = 2,  // Parallel only: 0 No_Pipelining,
                                            // 1 Optimal (reg every 2nd iteration),
                                            // 2 Maximum (reg every iteration)
    parameter integer FLOW_CONTROL    = 0,  // 0 NonBlocking, 1 Blocking (ready/valid)
    parameter integer USER_WIDTH      = 1   // width of the TUSER pass-through
) (
    input  wire                    i_clk,
    input  wire                    i_clkEn,      // ACLKEN: 1 = advance
    input  wire                    i_rstN,       // async active-low, control flops only
    input  wire                    i_xyValid,    // S_AXIS_CARTESIAN tvalid
    output wire                    o_xyReady,    // S_AXIS_CARTESIAN tready
    input  wire [INPUT_WIDTH-1:0]  i_x,
    input  wire [INPUT_WIDTH-1:0]  i_y,
    input  wire                    i_xyLast,     // tlast pass-through
    input  wire [USER_WIDTH-1:0]   i_xyUser,     // tuser pass-through
    output wire                    o_phaseValid, // M_AXIS_DOUT tvalid
    input  wire                    i_phaseReady, // M_AXIS_DOUT tready (Blocking only)
    output wire [OUTPUT_WIDTH-1:0] o_phase,
    output wire                    o_phaseLast,
    output wire [USER_WIDTH-1:0]   o_phaseUser
);

    //---- Latency function (shared with wrappers, must live inside the module) ----
    `include "cordic_arctan.vh"

    //---- Derived quantities (spec 1.1) ----
    localparam integer IW    = INPUT_WIDTH;
    localparam integer OW    = OUTPUT_WIDTH;
    localparam integer F     = (PHASE_FRAC_BITS == 0) ? (OW - 3) : PHASE_FRAC_BITS;
    localparam integer N_AUTO = ((F + 3) < 48) ? (F + 3) : 48;
    localparam integer N     = (ITERATIONS == 0) ? N_AUTO : ITERATIONS;
    localparam integer LOG2N = $clog2(N);
    localparam integer AF    = ((F + LOG2N + 2) < 60) ? (F + LOG2N + 2) : 60;
    localparam integer AW    = AF + 3;                  // signed angle, 3 integer bits
    localparam integer BEFF  = F + 3 + LOG2N;           // x/y bits for < 1/4 LSB error
    localparam integer P_NORM = (IW < BEFF) ? IW : BEFF;
    localparam integer P_AUTO = (PRE_NORMALIZE != 0) ? P_NORM : IW;
    localparam integer P     = (PRECISION != 0) ? PRECISION : P_AUTO;
    localparam integer G     = (BEFF > P) ? (BEFF - P) : 0; // guard bits below x/y LSB
    localparam integer DW    = P + 3 + G;               // x/y datapath width
    localparam integer PIPE_DIV_OPT = (PIPELINE_MODE == 1) ? 2 : N;
    localparam integer PIPE_DIV = (PIPELINE_MODE == 2) ? 1 : PIPE_DIV_OPT;
    localparam integer PRE   = (PRE_NORMALIZE != 0) ? 3 : 1; // pre-iteration register stages
    localparam integer ITER_REGS = (N + PIPE_DIV - 1) / PIPE_DIV; // ceil(N / PIPE_DIV)
    // Latency from the module's own derivation and from the shared .vh function;
    // both must agree (checked below), the wrappers rely on the function.
    localparam integer LATENCY_LOCAL = (ARCHITECTURE != 0) ? (PRE + ITER_REGS + 1)
                                                           : (PRE + N + 1);
    localparam integer LATENCY = cordicArctanLatency(ARCHITECTURE, PIPELINE_MODE, ITERATIONS,
                                                     OW, PHASE_FRAC_BITS, PRE_NORMALIZE);
    localparam integer D     = AF - F;                  // bits dropped at the output
    localparam integer RW    = F + 4;                   // rounded result width (AW+1-D)
    localparam integer XW    = (OW > RW) ? OW : RW;     // sign-extension width
    localparam integer LZW   = $clog2(IW + 1);          // leading-zero count width
    localparam integer SW    = 6;                       // shift-amount width (0..47)

    //---- Angle constants, Q4.60 (spec 1.2) ----
    localparam [63:0] PI2_RAD_Q60    = 64'h1921FB54442D1847; // pi/2
    localparam [63:0] PI2_SCALED_Q60 = 64'h0800000000000000; // 1/2 (units of pi)

    // Output rounding helpers (all zero when D == 0, i.e. no rounding).
    localparam [AW:0]   HALF     = ({{AW{1'b0}}, 1'b1} << D) >> 1;
    localparam [AW:0]   HALF_M1  = (D > 0) ? (HALF - {{AW{1'b0}}, 1'b1}) : {(AW + 1){1'b0}};
    localparam [AW-1:0] LOW_MASK = ({{(AW - 1){1'b0}}, 1'b1} << D) - {{(AW - 1){1'b0}}, 1'b1};

    // Word-serial FSM states
    localparam [1:0] ST_IDLE = 2'd0; // waiting for an input beat
    localparam [1:0] ST_PRE  = 2'd1; // sample travels through the pre-stages
    localparam [1:0] ST_ITER = 2'd2; // iterations 1..N-1 in the shared stage
    localparam [1:0] ST_DONE = 2'd3; // result registered, output stage loads it

    //---- Parameter validation ----
    initial begin
        if ((INPUT_WIDTH < 2) || (INPUT_WIDTH > 48)) begin
            $error("cordic_arctan: INPUT_WIDTH=%0d out of range 2..48", INPUT_WIDTH);
        end
        if ((OUTPUT_WIDTH < 2) || (OUTPUT_WIDTH > 48)) begin
            $error("cordic_arctan: OUTPUT_WIDTH=%0d out of range 2..48", OUTPUT_WIDTH);
        end
        if ((F < 1) || (F > (OUTPUT_WIDTH - 1))) begin
            $error("cordic_arctan: F=%0d out of range 1..OUTPUT_WIDTH-1", F);
        end
        if ((N < 1) || (N > 48)) begin
            $error("cordic_arctan: ITERATIONS=%0d out of range 1..48", N);
        end
        if ((DATA_FORMAT < 0) || (DATA_FORMAT > 1)) begin
            $error("cordic_arctan: DATA_FORMAT=%0d must be 0 or 1", DATA_FORMAT);
        end
        if ((PHASE_FORMAT < 0) || (PHASE_FORMAT > 1)) begin
            $error("cordic_arctan: PHASE_FORMAT=%0d must be 0 or 1", PHASE_FORMAT);
        end
        if ((ROUND_MODE < 0) || (ROUND_MODE > 3)) begin
            $error("cordic_arctan: ROUND_MODE=%0d must be 0..3", ROUND_MODE);
        end
        if ((COARSE_ROTATION < 0) || (COARSE_ROTATION > 1)) begin
            $error("cordic_arctan: COARSE_ROTATION=%0d must be 0 or 1", COARSE_ROTATION);
        end
        if ((PRE_NORMALIZE < 0) || (PRE_NORMALIZE > 1)) begin
            $error("cordic_arctan: PRE_NORMALIZE=%0d must be 0 or 1", PRE_NORMALIZE);
        end
        if ((ARCHITECTURE < 0) || (ARCHITECTURE > 1)) begin
            $error("cordic_arctan: ARCHITECTURE=%0d must be 0 or 1", ARCHITECTURE);
        end
        if ((PIPELINE_MODE < 0) || (PIPELINE_MODE > 2)) begin
            $error("cordic_arctan: PIPELINE_MODE=%0d must be 0..2", PIPELINE_MODE);
        end
        if ((FLOW_CONTROL < 0) || (FLOW_CONTROL > 1)) begin
            $error("cordic_arctan: FLOW_CONTROL=%0d must be 0 or 1", FLOW_CONTROL);
        end
        if (P < 2) begin
            $error("cordic_arctan: PRECISION P=%0d must be >= 2", P);
        end
        if (USER_WIDTH < 1) begin
            $error("cordic_arctan: USER_WIDTH=%0d must be >= 1", USER_WIDTH);
        end
        if ((PHASE_FORMAT == 0) && (COARSE_ROTATION == 1) && ((OUTPUT_WIDTH - F) < 3)) begin
            $error("cordic_arctan: pi not representable, OUTPUT_WIDTH-F=%0d < 3",
                   OUTPUT_WIDTH - F);
        end
        if (LATENCY != LATENCY_LOCAL) begin
            $error("cordic_arctan: cordicArctanLatency()=%0d disagrees with the core (%0d)",
                   LATENCY, LATENCY_LOCAL);
        end
    end

    //---- Functions: constant table, angle scaling, LZC, CORDIC step ----

    // atan(2^-i) in radians, Q4.60 (round(atan(2^-i) * 2^60)), i = 0..47.
    function [63:0] atanRadQ60(input integer i);
        begin
            case (i)
                0:  atanRadQ60 = 64'h0C90FDAA22168C23;
                1:  atanRadQ60 = 64'h076B19C1586ED3DA;
                2:  atanRadQ60 = 64'h03EB6EBF25901BAC;
                3:  atanRadQ60 = 64'h01FD5BA9AAC2F6DC;
                4:  atanRadQ60 = 64'h00FFAADDB967EF4E;
                5:  atanRadQ60 = 64'h007FF556EEA5D893;
                6:  atanRadQ60 = 64'h003FFEAAB776E535;
                7:  atanRadQ60 = 64'h001FFFD555BBBA97;
                8:  atanRadQ60 = 64'h000FFFFAAAADDDDC;
                9:  atanRadQ60 = 64'h0007FFFF55556EEF;
                10: atanRadQ60 = 64'h0003FFFFEAAAAB77;
                11: atanRadQ60 = 64'h0001FFFFFD55555C;
                12: atanRadQ60 = 64'h0000FFFFFFAAAAAB;
                13: atanRadQ60 = 64'h00007FFFFFF55555;
                14: atanRadQ60 = 64'h00003FFFFFFEAAAB;
                15: atanRadQ60 = 64'h00001FFFFFFFD555;
                16: atanRadQ60 = 64'h00000FFFFFFFFAAB;
                17: atanRadQ60 = 64'h000007FFFFFFFF55;
                18: atanRadQ60 = 64'h000003FFFFFFFFEB;
                19: atanRadQ60 = 64'h000001FFFFFFFFFD;
                20: atanRadQ60 = 64'h0000010000000000;
                21: atanRadQ60 = 64'h0000008000000000;
                22: atanRadQ60 = 64'h0000004000000000;
                23: atanRadQ60 = 64'h0000002000000000;
                24: atanRadQ60 = 64'h0000001000000000;
                25: atanRadQ60 = 64'h0000000800000000;
                26: atanRadQ60 = 64'h0000000400000000;
                27: atanRadQ60 = 64'h0000000200000000;
                28: atanRadQ60 = 64'h0000000100000000;
                29: atanRadQ60 = 64'h0000000080000000;
                30: atanRadQ60 = 64'h0000000040000000;
                31: atanRadQ60 = 64'h0000000020000000;
                32: atanRadQ60 = 64'h0000000010000000;
                33: atanRadQ60 = 64'h0000000008000000;
                34: atanRadQ60 = 64'h0000000004000000;
                35: atanRadQ60 = 64'h0000000002000000;
                36: atanRadQ60 = 64'h0000000001000000;
                37: atanRadQ60 = 64'h0000000000800000;
                38: atanRadQ60 = 64'h0000000000400000;
                39: atanRadQ60 = 64'h0000000000200000;
                40: atanRadQ60 = 64'h0000000000100000;
                41: atanRadQ60 = 64'h0000000000080000;
                42: atanRadQ60 = 64'h0000000000040000;
                43: atanRadQ60 = 64'h0000000000020000;
                44: atanRadQ60 = 64'h0000000000010000;
                45: atanRadQ60 = 64'h0000000000008000;
                46: atanRadQ60 = 64'h0000000000004000;
                47: atanRadQ60 = 64'h0000000000002000;
                default: atanRadQ60 = 64'd0;
            endcase
        end
    endfunction

    // atan(2^-i) / pi in Q4.60 (round(atan(2^-i) / pi * 2^60)), i = 0..47.
    function [63:0] atanScaledQ60(input integer i);
        begin
            case (i)
                0:  atanScaledQ60 = 64'h0400000000000000;
                1:  atanScaledQ60 = 64'h025C80A3B3BE610D;
                2:  atanScaledQ60 = 64'h013F670B6BDC73D2;
                3:  atanScaledQ60 = 64'h00A2223A83BBB343;
                4:  atanScaledQ60 = 64'h005161A861CB135E;
                5:  atanScaledQ60 = 64'h0028BAFC2B208C4F;
                6:  atanScaledQ60 = 64'h00145EC3CB8504C5;
                7:  atanScaledQ60 = 64'h000A2F8AA23A8856;
                8:  atanScaledQ60 = 64'h000517CA68DA1867;
                9:  atanScaledQ60 = 64'h00028BE5D7661567;
                10: atanScaledQ60 = 64'h000145F30012374F;
                11: atanScaledQ60 = 64'h0000A2F982950197;
                12: atanScaledQ60 = 64'h0000517CC19BFD8C;
                13: atanScaledQ60 = 64'h000028BE60D82E5E;
                14: atanScaledQ60 = 64'h0000145F306D5D22;
                15: atanScaledQ60 = 64'h00000A2F9836D74F;
                16: atanScaledQ60 = 64'h00000517CC1B70C0;
                17: atanScaledQ60 = 64'h0000028BE60DB903;
                18: atanScaledQ60 = 64'h00000145F306DC96;
                19: atanScaledQ60 = 64'h000000A2F9836E4D;
                20: atanScaledQ60 = 64'h000000517CC1B727;
                21: atanScaledQ60 = 64'h00000028BE60DB94;
                22: atanScaledQ60 = 64'h000000145F306DCA;
                23: atanScaledQ60 = 64'h0000000A2F9836E5;
                24: atanScaledQ60 = 64'h0000000517CC1B72;
                25: atanScaledQ60 = 64'h000000028BE60DB9;
                26: atanScaledQ60 = 64'h0000000145F306DD;
                27: atanScaledQ60 = 64'h00000000A2F9836E;
                28: atanScaledQ60 = 64'h00000000517CC1B7;
                29: atanScaledQ60 = 64'h0000000028BE60DC;
                30: atanScaledQ60 = 64'h00000000145F306E;
                31: atanScaledQ60 = 64'h000000000A2F9837;
                32: atanScaledQ60 = 64'h000000000517CC1B;
                33: atanScaledQ60 = 64'h00000000028BE60E;
                34: atanScaledQ60 = 64'h000000000145F307;
                35: atanScaledQ60 = 64'h0000000000A2F983;
                36: atanScaledQ60 = 64'h0000000000517CC2;
                37: atanScaledQ60 = 64'h000000000028BE61;
                38: atanScaledQ60 = 64'h0000000000145F30;
                39: atanScaledQ60 = 64'h00000000000A2F98;
                40: atanScaledQ60 = 64'h00000000000517CC;
                41: atanScaledQ60 = 64'h0000000000028BE6;
                42: atanScaledQ60 = 64'h00000000000145F3;
                43: atanScaledQ60 = 64'h000000000000A2FA;
                44: atanScaledQ60 = 64'h000000000000517D;
                45: atanScaledQ60 = 64'h00000000000028BE;
                46: atanScaledQ60 = 64'h000000000000145F;
                47: atanScaledQ60 = 64'h0000000000000A30;
                default: atanScaledQ60 = 64'd0;
            endcase
        end
    endfunction

    // Q4.60 -> Q3.AF, round half up (AF <= 60 by construction).
    function [AW-1:0] toAngle(input [63:0] q60);
        reg [63:0] scaled;
        begin
            if (AF < 60) begin
                scaled = (q60 + (64'd1 << (59 - AF))) >> (60 - AF);
            end else begin
                scaled = q60;
            end
            toAngle = scaled[AW-1:0];
        end
    endfunction

    // Per-iteration angle K[i] in AF units for the selected phase format.
    function [AW-1:0] angleConst(input integer i);
        begin
            if (PHASE_FORMAT == 0) begin
                angleConst = toAngle(atanRadQ60(i));
            end else begin
                angleConst = toAngle(atanScaledQ60(i));
            end
        end
    endfunction

    // Leading-zero count over IW bits; returns IW for an all-zero input.
    function [LZW-1:0] leadingZeros(input [IW-1:0] v);
        integer k;
        integer cnt;
        begin
            cnt = IW;
            for (k = 0; k < IW; k = k + 1) begin
                if (v[k]) begin
                    cnt = IW - 1 - k;
                end
            end
            leadingZeros = cnt[LZW-1:0];
        end
    endfunction

    // One vectoring micro-rotation of x/y with a variable shift (word-serial stage);
    // returns {x', y'}. The parallel stages use the same arithmetic unrolled inline.
    function [2*DW-1:0] cordicStepXy(
        input signed [DW-1:0] x,
        input signed [DW-1:0] y,
        input        [SW-1:0] shift
    );
        reg signed [DW-1:0] xSh;
        reg signed [DW-1:0] ySh;
        reg signed [DW-1:0] xNext;
        reg signed [DW-1:0] yNext;
        begin
            xSh = x >>> shift;
            ySh = y >>> shift;
            if (y[DW-1]) begin
                xNext = x - ySh;
                yNext = y + xSh;
            end else begin
                xNext = x + ySh;
                yNext = y - xSh;
            end
            cordicStepXy = {xNext, yNext};
        end
    endfunction

    //---- Internal signals ----
    wire                    en;          // global pipeline advance
    wire                    idle;        // word-serial: no sample in flight
    wire                    acceptEn;    // input beat is taken into the pre-stages
    wire signed [AW-1:0]    halfPi;      // +pi/2 coarse-rotation offset in AF units

    // Pre-stage outputs (either normalised or direct), P+1 bit signed
    wire signed [P:0]       xsPre;
    wire signed [P:0]       ysPre;
    wire                    yNegPre;     // raw sign of y (set only for a non-zero y)
    wire                    zeroPre;
    wire                    validPre;
    wire                    lastPre;
    wire [USER_WIDTH-1:0]   userPre;

    // Stage S2: coarse rotation
    reg  signed [P:0]       x0Pre;
    reg  signed [P:0]       y0Pre;
    reg  signed [AW-1:0]    z0Pre;
    wire signed [DW-1:0]    x0Ext;
    wire signed [DW-1:0]    y0Ext;
    reg  signed [DW-1:0]    x0Q;         // datapath: no reset
    reg  signed [DW-1:0]    y0Q;         // datapath: no reset
    reg  signed [AW-1:0]    z0Q;         // datapath: no reset
    reg  [USER_WIDTH-1:0]   userS2;      // datapath: no reset
    reg                     validS2;
    reg                     lastS2;
    reg                     zeroS2;

    // Final iteration result feeding the output stage
    wire signed [AW-1:0]    zFin;
    wire                    validFin;
    wire                    lastFin;
    wire                    zeroFin;
    wire [USER_WIDTH-1:0]   userFin;

    // Output stage
    reg  signed [AW:0]      zExt;
    reg  signed [AW:0]      zRound;
    reg  signed [AW:0]      zShift;
    reg  signed [RW-1:0]    rounded;
    wire signed [XW-1:0]    rExt;
    reg  [OW-1:0]           phaseQ;      // datapath: no reset
    reg  [USER_WIDTH-1:0]   userQ;       // datapath: no reset
    reg                     validQ;
    reg                     lastQ;

    //---- Flow control ----

    // Blocking: the whole pipeline stalls while the output is valid but not taken.
    generate
        if (FLOW_CONTROL != 0) begin : gen_blocking
            assign en = i_clkEn && (!validQ || i_phaseReady);
        end else begin : gen_nonblocking
            assign en = i_clkEn;
        end
    endgenerate

    // Parallel: always ready (NonBlocking) or ready whenever the pipeline moves
    // (Blocking). Word-serial: one sample in flight, ready while idle and moving.
    generate
        if (ARCHITECTURE != 0) begin : gen_ready_parallel
            assign idle      = 1'b1;
            assign o_xyReady = (FLOW_CONTROL != 0) ? en : 1'b1;
        end else begin : gen_ready_serial
            assign o_xyReady = idle && en;
        end
    endgenerate

    assign acceptEn = i_xyValid && idle;

    // +pi/2 in the internal angle format (constant, folded by synthesis)
    assign halfPi = $signed(toAngle((PHASE_FORMAT == 0) ? PI2_RAD_Q60 : PI2_SCALED_Q60));

    //---- Pre-stages: S0 (abs/sign), S1 (LZC), or direct input ----
    generate
        if (PRE_NORMALIZE != 0) begin : gen_normalize
            wire [IW-1:0]         xAbsIn;
            wire [IW-1:0]         yAbsIn;
            wire                  xNegIn;
            wire                  yNegIn;
            reg  [IW-1:0]         xAbsS0;   // datapath: no reset
            reg  [IW-1:0]         yAbsS0;   // datapath: no reset
            reg                   xNegS0;   // datapath: no reset
            reg                   yNegS0;   // datapath: no reset
            reg  [USER_WIDTH-1:0] userS0;   // datapath: no reset
            reg                   validS0;
            reg                   lastS0;
            wire [IW-1:0]         orS0;
            reg  [IW-1:0]         xAbsS1;   // datapath: no reset
            reg  [IW-1:0]         yAbsS1;   // datapath: no reset
            reg                   xNegS1;   // datapath: no reset
            reg                   yNegS1;   // datapath: no reset
            reg  [LZW-1:0]        lzS1;     // datapath: no reset
            reg  [USER_WIDTH-1:0] userS1;   // datapath: no reset
            reg                   validS1;
            reg                   lastS1;
            reg                   zeroS1;
            wire [IW-1:0]         xShift;
            wire [IW-1:0]         yShift;
            wire [P+IW-1:0]       xPad;
            wire [P+IW-1:0]       yPad;
            wire [P-1:0]          xTop;
            wire [P-1:0]          yTop;
            wire signed [P:0]     xMag;
            wire signed [P:0]     yMag;

            // Unsigned data is already a magnitude; signed data is folded to |x|.
            assign xNegIn = (DATA_FORMAT == 0) ? i_x[IW-1] : 1'b0;
            assign yNegIn = (DATA_FORMAT == 0) ? i_y[IW-1] : 1'b0;
            assign xAbsIn = xNegIn ? ({IW{1'b0}} - i_x) : i_x;
            assign yAbsIn = yNegIn ? ({IW{1'b0}} - i_y) : i_y;

            // S0 datapath: magnitudes and signs of the accepted beat
            always @(posedge i_clk) begin
                if (en) begin
                    xAbsS0 <= xAbsIn;
                    yAbsS0 <= yAbsIn;
                    xNegS0 <= xNegIn;
                    yNegS0 <= yNegIn;
                    userS0 <= i_xyUser;
                end
            end

            // S0 control: valid/last flags follow the beat
            always @(posedge i_clk or negedge i_rstN) begin
                if (!i_rstN) begin
                    validS0 <= 1'b0;
                    lastS0  <= 1'b0;
                end else if (en) begin
                    validS0 <= acceptEn;
                    lastS0  <= i_xyLast;
                end
            end

            assign orS0 = xAbsS0 | yAbsS0;

            // S1 datapath: leading-zero count of the joint magnitude
            always @(posedge i_clk) begin
                if (en) begin
                    xAbsS1 <= xAbsS0;
                    yAbsS1 <= yAbsS0;
                    xNegS1 <= xNegS0;
                    yNegS1 <= yNegS0;
                    lzS1   <= leadingZeros(orS0);
                    userS1 <= userS0;
                end
            end

            // S1 control: valid/last/zero flags
            always @(posedge i_clk or negedge i_rstN) begin
                if (!i_rstN) begin
                    validS1 <= 1'b0;
                    lastS1  <= 1'b0;
                    zeroS1  <= 1'b0;
                end else if (en) begin
                    validS1 <= validS0;
                    lastS1  <= lastS0;
                    zeroS1  <= (orS0 == {IW{1'b0}});
                end
            end

            // Barrel shift so the larger magnitude has its MSB at bit IW-1, then keep
            // the top P bits (zero-padded at the LSB end when P > IW).
            assign xShift = xAbsS1 << lzS1;
            assign yShift = yAbsS1 << lzS1;
            assign xPad   = {xShift, {P{1'b0}}};
            assign yPad   = {yShift, {P{1'b0}}};
            assign xTop   = xPad[P+IW-1 -: P];
            assign yTop   = yPad[P+IW-1 -: P];
            assign xMag   = $signed({1'b0, xTop});
            assign yMag   = $signed({1'b0, yTop});
            assign xsPre  = xNegS1 ? (-xMag) : xMag;
            assign ysPre  = yNegS1 ? (-yMag) : yMag;
            assign yNegPre  = yNegS1;
            assign zeroPre  = zeroS1;
            assign validPre = validS1;
            assign lastPre  = lastS1;
            assign userPre  = userS1;
        end else begin : gen_direct
            wire [P+IW-1:0] xPad;
            wire [P+IW-1:0] yPad;
            wire [P-1:0]    xTop;
            wire [P-1:0]    yTop;
            wire            xSign;
            wire            ySign;

            // Raw inputs: top P bits (LSB zero-padded when P > IW) with the sign
            // bit prepended; unsigned data gets a zero sign bit.
            assign xPad  = {i_x, {P{1'b0}}};
            assign yPad  = {i_y, {P{1'b0}}};
            assign xTop  = xPad[P+IW-1 -: P];
            assign yTop  = yPad[P+IW-1 -: P];
            assign xSign = (DATA_FORMAT == 0) ? i_x[IW-1] : 1'b0;
            assign ySign = (DATA_FORMAT == 0) ? i_y[IW-1] : 1'b0;
            assign xsPre = $signed({xSign, xTop});
            assign ysPre = $signed({ySign, yTop});
            assign yNegPre  = ySign;
            assign zeroPre  = (i_x == {IW{1'b0}}) && (i_y == {IW{1'b0}});
            assign validPre = acceptEn;
            assign lastPre  = i_xyLast;
            assign userPre  = i_xyUser;
        end
    endgenerate

    //---- Stage S2: coarse rotation into the right half plane ----

    // Left half plane is rotated by -/+ pi/2 so the iterations converge. The quadrant
    // is taken from the raw sign of y, so a tiny negative y that vanished in the
    // normalisation still lands at -pi (not +pi), as the ideal angle does.
    always @(*) begin
        x0Pre = xsPre;
        y0Pre = ysPre;
        z0Pre = {AW{1'b0}};
        if ((COARSE_ROTATION != 0) && xsPre[P]) begin
            if (!yNegPre) begin
                x0Pre = ysPre;      // 2nd quadrant: rotate by -pi/2
                y0Pre = -xsPre;
                z0Pre = halfPi;
            end else begin
                x0Pre = -ysPre;     // 3rd quadrant: rotate by +pi/2
                y0Pre = xsPre;
                z0Pre = -halfPi;
            end
        end
    end

    // Sign-extend by two headroom bits (CORDIC gain 2.33) and append G guard bits.
    assign x0Ext = $signed({{(DW - P - 1){x0Pre[P]}}, x0Pre}) <<< G;
    assign y0Ext = $signed({{(DW - P - 1){y0Pre[P]}}, y0Pre}) <<< G;

    // S2 datapath: rotated start vector and start angle
    always @(posedge i_clk) begin
        if (en) begin
            x0Q    <= x0Ext;
            y0Q    <= y0Ext;
            z0Q    <= z0Pre;
            userS2 <= userPre;
        end
    end

    // S2 control: valid/last/zero flags
    always @(posedge i_clk or negedge i_rstN) begin
        if (!i_rstN) begin
            validS2 <= 1'b0;
            lastS2  <= 1'b0;
            zeroS2  <= 1'b0;
        end else if (en) begin
            validS2 <= validPre;
            lastS2  <= lastPre;
            zeroS2  <= zeroPre;
        end
    end

    //---- Iterations: parallel (unrolled) or word-serial (one shared stage) ----
    generate
        if (ARCHITECTURE != 0) begin : gen_parallel
            // Inter-stage buses; slice s is the input of iteration s. The x chain
            // stops one iteration early (the last one only needs the sign of y).
            localparam integer XN = (N > 1) ? (N - 1) : 1;
            wire [XN*DW-1:0]        xChain;
            wire [N*DW-1:0]         yChain;
            wire [(N+1)*AW-1:0]     zChain;
            wire [N:0]              validChain;
            wire [N:0]              lastChain;
            wire [N:0]              zeroChain;
            wire [(N+1)*USER_WIDTH-1:0] userChain;
            genvar s;

            assign xChain[0 +: DW]          = x0Q;
            assign yChain[0 +: DW]          = y0Q;
            assign zChain[0 +: AW]          = z0Q;
            assign validChain[0]            = validS2;
            assign lastChain[0]             = lastS2;
            assign zeroChain[0]             = zeroS2;
            assign userChain[0 +: USER_WIDTH] = userS2;

            for (s = 0; s < N; s = s + 1) begin : gen_iter
                localparam integer REG_S = (((s + 1) % PIPE_DIV) == 0) || (s == (N - 1));
                wire signed [DW-1:0] yIn;
                wire signed [AW-1:0] zIn;
                wire        [AW-1:0] kS;
                wire signed [AW-1:0] zNext;

                assign yIn = $signed(yChain[s*DW +: DW]);
                assign zIn = $signed(zChain[s*AW +: AW]);
                assign kS  = angleConst(s);
                // Angle accumulates the rotation that drove y towards zero.
                assign zNext = yIn[DW-1] ? (zIn - $signed(kS)) : (zIn + $signed(kS));

                // y is needed by every later iteration (its sign steers them); x only by
                // iterations that still update y. Both chains therefore end early.
                if (s < (N - 1)) begin : gen_y
                    wire signed [DW-1:0] xIn;
                    wire signed [DW-1:0] xSh;
                    wire signed [DW-1:0] yNext;

                    assign xIn   = $signed(xChain[s*DW +: DW]);
                    assign xSh   = xIn >>> s;
                    assign yNext = yIn[DW-1] ? (yIn + xSh) : (yIn - xSh);

                    if (REG_S != 0) begin : gen_y_reg
                        reg signed [DW-1:0] yStage;  // datapath: no reset

                        // Pipeline register per the PIPE_DIV rule
                        always @(posedge i_clk) begin
                            if (en) begin
                                yStage <= yNext;
                            end
                        end
                        assign yChain[(s+1)*DW +: DW] = yStage;
                    end else begin : gen_y_comb
                        assign yChain[(s+1)*DW +: DW] = yNext;
                    end

                    if (s < (N - 2)) begin : gen_x
                        wire signed [DW-1:0] ySh;
                        wire signed [DW-1:0] xNext;

                        assign ySh   = yIn >>> s;
                        assign xNext = yIn[DW-1] ? (xIn - ySh) : (xIn + ySh);

                        if (REG_S != 0) begin : gen_x_reg
                            reg signed [DW-1:0] xStage;  // datapath: no reset

                            // Pipeline register per the PIPE_DIV rule
                            always @(posedge i_clk) begin
                                if (en) begin
                                    xStage <= xNext;
                                end
                            end
                            assign xChain[(s+1)*DW +: DW] = xStage;
                        end else begin : gen_x_comb
                            assign xChain[(s+1)*DW +: DW] = xNext;
                        end
                    end
                end

                if (REG_S != 0) begin : gen_z_reg
                    reg signed [AW-1:0]   zStage;     // datapath: no reset
                    reg [USER_WIDTH-1:0]  userStage;  // datapath: no reset
                    reg                   validStage;
                    reg                   lastStage;
                    reg                   zeroStage;

                    // Pipeline register per the PIPE_DIV rule (angle, user)
                    always @(posedge i_clk) begin
                        if (en) begin
                            zStage    <= zNext;
                            userStage <= userChain[s*USER_WIDTH +: USER_WIDTH];
                        end
                    end

                    // Pipeline register per the PIPE_DIV rule (control flags)
                    always @(posedge i_clk or negedge i_rstN) begin
                        if (!i_rstN) begin
                            validStage <= 1'b0;
                            lastStage  <= 1'b0;
                            zeroStage  <= 1'b0;
                        end else if (en) begin
                            validStage <= validChain[s];
                            lastStage  <= lastChain[s];
                            zeroStage  <= zeroChain[s];
                        end
                    end
                    assign zChain[(s+1)*AW +: AW]  = zStage;
                    assign validChain[s+1]         = validStage;
                    assign lastChain[s+1]          = lastStage;
                    assign zeroChain[s+1]          = zeroStage;
                    assign userChain[(s+1)*USER_WIDTH +: USER_WIDTH] = userStage;
                end else begin : gen_z_comb
                    assign zChain[(s+1)*AW +: AW]  = zNext;
                    assign validChain[s+1]         = validChain[s];
                    assign lastChain[s+1]          = lastChain[s];
                    assign zeroChain[s+1]          = zeroChain[s];
                    assign userChain[(s+1)*USER_WIDTH +: USER_WIDTH] =
                        userChain[s*USER_WIDTH +: USER_WIDTH];
                end
            end

            assign zFin     = $signed(zChain[N*AW +: AW]);
            assign validFin = validChain[N];
            assign lastFin  = lastChain[N];
            assign zeroFin  = zeroChain[N];
            assign userFin  = userChain[N*USER_WIDTH +: USER_WIDTH];
        end else begin : gen_serial
            reg  [1:0]            state;
            reg  [1:0]            stateNext;
            reg  [SW-1:0]         iterCnt;
            reg  [SW-1:0]         iterCntNext;
            reg  signed [DW-1:0]  xIt;      // datapath: no reset
            reg  signed [DW-1:0]  yIt;      // datapath: no reset
            reg  signed [AW-1:0]  zIt;      // datapath: no reset
            reg  [USER_WIDTH-1:0] userIt;   // datapath: no reset
            reg                   lastIt;
            reg                   zeroIt;
            wire                  loadStep;
            wire                  stepEn;
            wire signed [DW-1:0]  xSrc;
            wire signed [DW-1:0]  ySrc;
            wire signed [AW-1:0]  zSrc;
            wire [AW-1:0]         kIt;
            wire [2*DW-1:0]       xyNext;
            wire signed [AW-1:0]  zNext;

            assign idle     = (state == ST_IDLE);
            assign loadStep = (state == ST_PRE) && validS2;   // iteration 0 from S2
            assign stepEn   = loadStep || (state == ST_ITER); // iterations 1..N-1
            assign xSrc = loadStep ? x0Q : xIt;
            assign ySrc = loadStep ? y0Q : yIt;
            assign zSrc = loadStep ? z0Q : zIt;
            // Variable shift / constant lookup indexed by the iteration counter
            assign kIt    = angleConst(iterCnt);
            assign xyNext = cordicStepXy(xSrc, ySrc, iterCnt);
            assign zNext  = ySrc[DW-1] ? (zSrc - $signed(kIt)) : (zSrc + $signed(kIt));

            // FSM next state: accept -> pre-stages -> N iterations -> output load
            always @(*) begin
                stateNext   = state;
                iterCntNext = iterCnt;
                case (state)
                    ST_IDLE: begin
                        iterCntNext = {SW{1'b0}};
                        if (i_xyValid) begin
                            stateNext = ST_PRE;
                        end
                    end
                    ST_PRE: begin
                        if (validS2) begin
                            iterCntNext = {{(SW - 1){1'b0}}, 1'b1};
                            if (N == 1) begin
                                stateNext = ST_DONE;
                            end else begin
                                stateNext = ST_ITER;
                            end
                        end
                    end
                    ST_ITER: begin
                        iterCntNext = iterCnt + {{(SW - 1){1'b0}}, 1'b1};
                        if (iterCnt == (N - 1)) begin
                            stateNext = ST_DONE;
                        end
                    end
                    ST_DONE: begin
                        iterCntNext = {SW{1'b0}};
                        stateNext   = ST_IDLE;
                    end
                    default: begin
                        stateNext = ST_IDLE;
                    end
                endcase
            end

            // FSM state register (control, async reset)
            always @(posedge i_clk or negedge i_rstN) begin
                if (!i_rstN) begin
                    state   <= ST_IDLE;
                    iterCnt <= {SW{1'b0}};
                    lastIt  <= 1'b0;
                    zeroIt  <= 1'b0;
                end else if (en) begin
                    state   <= stateNext;
                    iterCnt <= iterCntNext;
                    if (loadStep) begin
                        lastIt <= lastS2;
                        zeroIt <= zeroS2;
                    end
                end
            end

            // Shared iteration register: loaded from S2, then recirculated
            always @(posedge i_clk) begin
                if (en && stepEn) begin
                    xIt <= $signed(xyNext[2*DW-1 -: DW]);
                    yIt <= $signed(xyNext[DW-1:0]);
                    zIt <= zNext;
                end
                if (en && loadStep) begin
                    userIt <= userS2;
                end
            end

            assign zFin     = zIt;
            assign validFin = (state == ST_DONE);
            assign lastFin  = lastIt;
            assign zeroFin  = zeroIt;
            assign userFin  = userIt;
        end
    endgenerate

    //---- Output stage: drop D = AF - F bits with the selected rounding ----

    // Rounding is done one bit wider than the angle so the half-LSB add cannot wrap.
    always @(*) begin
        zExt    = {zFin[AW-1], zFin};
        zRound  = zExt;
        zShift  = zExt;
        rounded = {RW{1'b0}};
        case (ROUND_MODE)
            1: begin
                zRound = zExt + $signed(HALF);
            end
            2: begin
                if (zFin[AW-1]) begin
                    zRound = zExt + $signed(HALF_M1);
                end else begin
                    zRound = zExt + $signed(HALF);
                end
            end
            3: begin
                zRound = zExt + $signed(HALF);
            end
            default: begin
                zRound = zExt;
            end
        endcase
        zShift  = zRound >>> D;
        rounded = zShift[RW-1:0];
        // Nearest even: an exact half that rounded up to an odd value goes back down.
        if ((ROUND_MODE == 3) && (D > 0) && rounded[0] &&
            (($unsigned(zFin) & LOW_MASK) == HALF[AW-1:0])) begin
            rounded = rounded - {{(RW - 1){1'b0}}, 1'b1};
        end
    end

    // Sign-extend to the output width when it is wider than the rounded result.
    generate
        if (XW > RW) begin : gen_ext
            assign rExt = $signed({{(XW - RW){rounded[RW-1]}}, rounded});
        end else begin : gen_noext
            assign rExt = rounded;
        end
    endgenerate

    // Output datapath register; (0,0) input yields phase 0.
    always @(posedge i_clk) begin
        if (en) begin
            phaseQ <= zeroFin ? {OW{1'b0}} : rExt[OW-1:0];
            userQ  <= userFin;
        end
    end

    // Output control register; holds valid while a Blocking stall is pending.
    always @(posedge i_clk or negedge i_rstN) begin
        if (!i_rstN) begin
            validQ <= 1'b0;
            lastQ  <= 1'b0;
        end else if (en) begin
            validQ <= validFin;
            lastQ  <= lastFin;
        end
    end

    assign o_phaseValid = validQ;
    assign o_phase      = phaseQ;
    assign o_phaseLast  = lastQ;
    assign o_phaseUser  = userQ;

endmodule

`default_nettype wire
