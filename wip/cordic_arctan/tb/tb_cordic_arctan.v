`timescale 1ns / 1ps
`default_nettype none

//----------------------------------------------------------------------------
// Module : tb_cordic_arctan
// Purpose: Self-checking XSim bench for cordic_arctan, 14 configurations at once.
//
// One compile, NUM_CFG DUT instances (gen_cfg[c].u_dut) side by side, each
// with its own stimulus driver, scoreboard, latency / throughput check and
// report block. The reference is real math ($atan2) on the integer inputs,
// converted to the output format WITHOUT rounding; the error e = DUT - ideal
// is measured in output LSB (spec section 1.4).
//
// Configurations (spec section 2): C0..C2 openofdm (32 -> 16 bit, F=9,
// N=14/12/16), C3 Xilinx default look-alike (no normalisation, truncate),
// C4 nearest-even + optimal pipelining, C5 scaled radians 24 bit, C6 modular
// binary turns, C7 right half plane only (10 bit out), C8 unsigned inputs,
// C9 no pipelining, C10 Blocking flow control with random ready / valid /
// clkEn, C11 word-serial, C12 widest legal (48 bit), C13 = NonBlocking twin
// of C10 (same stimulus; the two output streams must be identical).
//
// Stimulus per config (tasks, driven on the falling edge):
//   a) angle sweep, SWEEP_ANGLES angles x 7 magnitudes
//   b) NUM_UNIFORM uniform random (x, y)
//   c) NUM_LOG_UNIFORM log-uniform magnitude, uniform angle
//   d) corner cases (axes at 1 and FS, the four corners, (0,0), most negative)
//   e) bursty valid (random gaps) and a burst with random i_clkEn
//   f) NUM_STREAM samples back-to-back (throughput)
// C10 additionally runs a) - e) under random i_phaseReady (~60 % high),
// random i_clkEn (~80 % high) and random i_xyValid.
//
// Checks: every output compared in order with the queued expectation
// (|e| <= TOL, TOL per spec 1.4; for C12 TOL + 2 LSB because the double
// precision reference (53 bit mantissa) only resolves ~2^-6 LSB of a 48 bit
// result), tlast / tuser pass-through, no lost / duplicated / unexpected
// output, outputs held while stalled (i_clkEn low or Blocking back-pressure),
// o_xyReady == 1 for NonBlocking parallel cores, latency measured from the
// first accepted input to the first output == cordicArctanLatency() from
// cordic_arctan.vh, streaming throughput <= 1 clock / sample (parallel) or
// <= PRE + N + 1 (word-serial). Samples that spec 1.4 excludes from the
// assertion (PRE_NORMALIZE=0 with small inputs, COARSE_ROTATION=0 with x<0)
// are reported separately as "unasserted".
//
// Report (machine-greppable, one block per config):
//   [tb_cordic_arctan] C<n> IN=.. OUT=.. FMT=.. F=.. N=.. P=.. G=.. NORM=..
//     ROUND=.. ARCH=.. PIPE=.. samples=<n> latency=<meas>/<exp>
//     maxErr=<x.xxx> LSB (<deg> deg) meanErr=<> rmsErr=<>
//     hist(|e|<=0.5/<=1/<=1.5/>1.5)=<%>/<%>/<%>/<%> TOL=<> PASS|FAIL
//   [tb_cordic_arctan] C<n> extra: ...        (flow control, throughput, ...)
//   [tb_cordic_arctan] C<n> decade=<d> ...    (C0..C2: error per magnitude decade)
//   [tb_cordic_arctan] RESULT: PASS (<k>/<k> configs)   or   RESULT: FAIL (...)
// FMT: 0 = radians, 1 = scaled radians (units of pi). ARCH: 1 = parallel,
// 0 = word-serial. meanErr is the signed mean (bias), rmsErr the RMS of e.
//
// Plusargs: +DUMP_CSV writes C<n>.csv (x,y,ideal,dut,err) per config;
//           +QUICK shortens the random phases (debug aid, not a full run).
// `define DUMP dumps a VCD (tb_cordic_arctan.vcd).
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
module tb_cordic_arctan;
`include "cordic_arctan.vh"

    //---- Bench constants ---------------------------------------------------
    localparam integer PERIOD          = 10;        // ns (100 MHz, board clock)
    localparam integer NUM_CFG         = 14;
    localparam integer USER_WIDTH      = 4;
    localparam integer QUEUE_DEPTH     = 4096;      // expectations in flight (2^n)
    localparam integer LOG_DEPTH       = 131072;    // per-config output log
    localparam integer SWEEP_ANGLES    = 3600;
    localparam integer SWEEP_MAGS      = 7;
    localparam integer NUM_UNIFORM     = 40000;
    localparam integer NUM_LOG_UNIFORM = 40000;
    localparam integer NUM_GAPS        = 1000;
    localparam integer NUM_CLKEN       = 500;
    localparam integer NUM_STREAM      = 2000;
    localparam integer QUICK_ANGLES    = 360;
    localparam integer QUICK_RANDOM    = 4000;
    localparam integer MAX_PRINT       = 10;        // mismatches printed per config
    localparam integer ACCEPT_TIMEOUT  = 10000;     // clocks a sample may wait for ready
    localparam integer DRAIN_TIMEOUT   = 20000;     // clocks to wait for the last output
    localparam integer WATCHDOG_CYCLES = 40000000;
    localparam integer NUM_DECADES     = 16;
    localparam integer SEED_STIM       = 20260913;  // same for every config (twin compare)
    localparam integer SEED_FLOW       = 7;
    localparam integer SEED_GAP        = 99;
    localparam real    PI_REAL         = 3.14159265358979323846;
    localparam real    TWO_POW_32      = 4294967296.0;
    localparam real    TWO_POW_16      = 65536.0;

    //---- Top-level signals ---------------------------------------------------
    reg                clk;
    reg                rstN;
    reg                rstDone;
    integer            cycle;             // posedge counter, read pre-increment
    integer            reportIdx;         // token: which config prints its report
    reg  [NUM_CFG-1:0] cfgDone;
    reg  [NUM_CFG-1:0] cfgFail;
    integer            nSweepAngles;
    integer            nUniform;
    integer            nLogUniform;
    integer            twinSamples;
    integer            twinMismatch;
    integer            passCount;
    integer            ci;
    reg                dumpCsv;

    //---- Configuration table ----------------------------------------------
    // Packed 64-bit word per configuration so the generate loop can derive
    // per-instance localparams from the genvar. Field layout, MSB first:
    //   [63:56] INPUT_WIDTH      [55:48] OUTPUT_WIDTH   [47:44] DATA_FORMAT
    //   [43:40] PHASE_FORMAT     [39:32] PHASE_FRAC_BITS (0 = auto)
    //   [31:28] ROUND_MODE       [27:20] ITERATIONS (0 = auto)
    //   [19:16] COARSE_ROTATION  [15:12] PRE_NORMALIZE   [11:8] ARCHITECTURE
    //   [7:4]   PIPELINE_MODE    [3:0]   FLOW_CONTROL
    function [63:0] packCfg(input integer iw, input integer ow, input integer dataFmt,
                            input integer phaseFmt, input integer pfb, input integer rnd,
                            input integer iter, input integer coarse, input integer norm,
                            input integer arch, input integer pipe, input integer flow);
        begin
            packCfg = {iw[7:0], ow[7:0], dataFmt[3:0], phaseFmt[3:0], pfb[7:0], rnd[3:0],
                       iter[7:0], coarse[3:0], norm[3:0], arch[3:0], pipe[3:0], flow[3:0]};
        end
    endfunction

    function [63:0] cfgWord(input integer c);
        begin
            case (c)
                //                 IW  OW  DAT PFM PFB RND ITR COA NRM ARC PIP FLW
                0:  cfgWord = packCfg(32, 16, 0,  0,  9,  1,  14, 1,  1,  1,  2,  0); // openofdm
                1:  cfgWord = packCfg(32, 16, 0,  0,  9,  1,  12, 1,  1,  1,  2,  0); // N=12
                2:  cfgWord = packCfg(32, 16, 0,  0,  9,  1,  16, 1,  1,  1,  2,  0); // N=16
                3:  cfgWord = packCfg(16, 16, 0,  0,  0,  0,  0,  1,  0,  1,  2,  0); // Xilinx dflt
                4:  cfgWord = packCfg(16, 16, 0,  0,  13, 3,  0,  1,  1,  1,  1,  0); // even, opt
                5:  cfgWord = packCfg(24, 24, 0,  1,  0,  2,  0,  1,  1,  1,  2,  0); // scaled 24
                6:  cfgWord = packCfg(16, 16, 0,  1,  15, 1,  0,  1,  1,  1,  2,  0); // bin turns
                7:  cfgWord = packCfg(12, 10, 0,  0,  7,  1,  0,  0,  1,  1,  2,  0); // half plane
                8:  cfgWord = packCfg(16, 16, 1,  0,  13, 1,  0,  1,  1,  1,  2,  0); // unsigned
                9:  cfgWord = packCfg(16, 16, 0,  0,  13, 1,  0,  1,  1,  1,  0,  0); // no pipe
                10: cfgWord = packCfg(16, 16, 0,  0,  13, 1,  0,  1,  1,  1,  2,  1); // Blocking
                11: cfgWord = packCfg(16, 16, 0,  0,  13, 1,  0,  1,  1,  0,  2,  0); // word-serial
                12: cfgWord = packCfg(48, 48, 0,  0,  0,  1,  48, 1,  1,  1,  2,  0); // widest
                13: cfgWord = packCfg(16, 16, 0,  0,  13, 1,  0,  1,  1,  1,  2,  0); // twin of C10
                default: cfgWord = 64'd0;
            endcase
        end
    endfunction

    //---- Helper functions (config independent) ----------------------------
    function integer minInt(input integer a, input integer b);
        begin
            minInt = (a < b) ? a : b;
        end
    endfunction

    function integer maxInt(input integer a, input integer b);
        begin
            maxInt = (a > b) ? a : b;
        end
    endfunction

    // $clog2 as a constant function (N = 1 -> 0)
    function integer clog2i(input integer n);
        integer v;
        begin
            clog2i = 0;
            v      = n - 1;
            while (v > 0) begin
                clog2i = clog2i + 1;
                v      = v >> 1;
            end
        end
    endfunction

    // 64-bit signed integer -> real, built from 32/16/16-bit pieces so that
    // no conversion of a >32-bit value is needed from the simulator.
    function real int64ToReal(input reg signed [63:0] v);
        integer hi;
        integer mid;
        integer lo;
        begin
            hi          = v[63:32];
            mid         = {16'd0, v[31:16]};
            lo          = {16'd0, v[15:0]};
            int64ToReal = ($itor(hi) * TWO_POW_32) + ($itor(mid) * TWO_POW_16) + $itor(lo);
        end
    endfunction

    // real (integer valued, |v| < 2^63) -> 64-bit two's complement
    function [63:0] realToInt64(input real v);
        real    hiR;
        real    rem;
        real    midR;
        real    loR;
        integer hi;
        integer mid;
        integer lo;
        begin
            hiR         = $floor(v / TWO_POW_32);
            rem         = v - (hiR * TWO_POW_32);
            midR        = $floor(rem / TWO_POW_16);
            loR         = rem - (midR * TWO_POW_16);
            hi          = $rtoi(hiR);
            mid         = $rtoi(midR);
            lo          = $rtoi(loR);
            realToInt64 = {hi[31:0], mid[15:0], lo[15:0]};
        end
    endfunction

    // 2^e as real, e may be negative
    function real pow2Real(input integer e);
        integer k;
        begin
            pow2Real = 1.0;
            for (k = 0; k < e; k = k + 1) begin
                pow2Real = pow2Real * 2.0;
            end
            for (k = 0; k > e; k = k - 1) begin
                pow2Real = pow2Real / 2.0;
            end
        end
    endfunction

    function real absReal(input real r);
        begin
            absReal = (r < 0.0) ? -r : r;
        end
    endfunction

    // magnitude decade floor(log10(m)) of an unsigned 64-bit magnitude, 0 for m < 10
    function integer decadeOf(input [63:0] m);
        reg [63:0] v;
        begin
            decadeOf = 0;
            v        = m;
            while (v >= 64'd10) begin
                decadeOf = decadeOf + 1;
                v        = v / 64'd10;
            end
        end
    endfunction

    //---- Clock -------------------------------------------------------------
    always #(PERIOD / 2) clk = ~clk;

    // posedge counter; read in the active region (pre-increment) by driver
    // and monitor, so both see the same edge index
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end

    //---- Per-configuration instance, driver, scoreboard --------------------
    genvar c;
    generate
        for (c = 0; c < NUM_CFG; c = c + 1) begin : gen_cfg
            localparam [63:0]  CW        = cfgWord(c);
            localparam integer CFG       = c;
            localparam integer IW        = CW[63:56];
            localparam integer OW        = CW[55:48];
            localparam integer DATA_FMT  = CW[47:44];
            localparam integer PHASE_FMT = CW[43:40];
            localparam integer PFB       = CW[39:32];
            localparam integer RND       = CW[31:28];
            localparam integer ITER      = CW[27:20];
            localparam integer COARSE    = CW[19:16];
            localparam integer NORM      = CW[15:12];
            localparam integer ARCH      = CW[11:8];
            localparam integer PIPE      = CW[7:4];
            localparam integer FLOW      = CW[3:0];
            // derived quantities, spec 1.1 (bench-side copy for the report;
            // the expected latency itself comes from cordic_arctan.vh)
            localparam integer F         = (PFB == 0) ? (OW - 3) : PFB;
            localparam integer N         = (ITER == 0) ? minInt(48, F + 3) : ITER;
            localparam integer LOG2N     = clog2i(N);
            localparam integer BEFF      = F + 3 + LOG2N;
            localparam integer P         = (NORM != 0) ? minInt(IW, BEFF) : IW;
            localparam integer G         = maxInt(0, BEFF - P);
            localparam integer PRE       = (NORM != 0) ? 3 : 1;
            localparam integer LAT_EXP   = cordicArctanLatency(ARCH, PIPE, ITER, OW, PFB, NORM);
            localparam integer THR_EXP   = (ARCH != 0) ? 1 : (PRE + N + 1); // clocks/sample
            localparam integer MODULAR   = ((PHASE_FMT == 1) && (F == (OW - 1))) ? 1 : 0;
            localparam integer WIDE      = (OW > 40) ? 1 : 0;  // double reference limit
            localparam integer NUM_MAGS  = SWEEP_MAGS;
            localparam [63:0]  FS        = (DATA_FMT == 1) ? ((64'd1 << IW) - 64'd1)
                                                           : ((64'd1 << (IW - 1)) - 64'd1);
            localparam [63:0]  MN        = (DATA_FMT == 1) ? 64'd0
                                                           : (64'hFFFFFFFFFFFFFFFF << (IW - 1));
            // PRE_NORMALIZE=0: only max(|x|,|y|) >= 2^(P-3) is asserted (spec 1.4)
            localparam [63:0]  ASSERT_MIN = ((NORM == 0) && (P > 3)) ? (64'd1 << (P - 3)) : 64'd0;

            //---- DUT connections ----
            reg                   clkEn;
            reg                   xyValid;
            wire                  xyReady;
            reg  [IW-1:0]         x;
            reg  [IW-1:0]         y;
            reg                   xyLast;
            reg  [USER_WIDTH-1:0] xyUser;
            wire                  phaseValid;
            reg                   phaseReady;
            wire [OW-1:0]         phase;
            wire                  phaseLast;
            wire [USER_WIDTH-1:0] phaseUser;

            //---- scoreboard queue (ring, indexed by free-running pointers) ----
            real                  expQ    [0:QUEUE_DEPTH-1];
            real                  tolQ    [0:QUEUE_DEPTH-1];
            reg  signed [63:0]    xQ      [0:QUEUE_DEPTH-1];
            reg  signed [63:0]    yQ      [0:QUEUE_DEPTH-1];
            reg                   assertQ [0:QUEUE_DEPTH-1];
            reg                   lastQ   [0:QUEUE_DEPTH-1];
            reg  [USER_WIDTH-1:0] userQ   [0:QUEUE_DEPTH-1];
            integer               wrPtr;
            integer               rdPtr;
            reg  signed [63:0]    outLog  [0:LOG_DEPTH-1];   // for the twin compare

            //---- statistics ----
            integer               inCount;
            integer               outCount;
            integer               nAsserted;
            integer               nUnasserted;
            real                  maxErr;
            real                  maxErrUnasserted;
            real                  sumErr;
            real                  sumSqErr;
            integer               hist0;      // |e| <= 0.5
            integer               hist1;      // 0.5 < |e| <= 1
            integer               hist2;      // 1 < |e| <= 1.5
            integer               hist3;      // |e| > 1.5
            integer               decCnt   [0:NUM_DECADES-1];
            real                  decMax   [0:NUM_DECADES-1];
            real                  decSumSq [0:NUM_DECADES-1];
            integer               errMismatch;
            integer               errUnexpected;
            integer               errHold;
            integer               errLastUser;
            integer               errX;
            integer               errReadyLow;
            integer               errTimeout;
            integer               errOverflow;
            integer               errLost;
            integer               errCount;
            integer               printed;
            integer               firstAccCycle;
            integer               firstOutCycle;
            integer               lastAcceptCycle;
            integer               latencyMeas;
            integer               strFirst;
            integer               strLast;
            integer               strCount;
            real                  thrMeas;
            reg                   thrFail;
            reg                   fail;

            //---- driver state ----
            reg                   randomFlow;   // C10: random ready / clkEn / valid
            reg                   clkEnRandom;  // burst with random i_clkEn
            integer               seedStim;
            integer               seedFlow;
            integer               seedGap;
            real                  tol;
            real                  scaleF;       // 2^F
            real                  degPerLsb;
            real                  fsReal;
            real                  mnReal;
            integer               csvFd;
            reg  [8*8-1:0]        csvName;

            //---- stall-hold check state ----
            reg                   holdPending;
            reg  [OW-1:0]         holdPhase;
            reg                   holdLast;
            reg  [USER_WIDTH-1:0] holdUser;

            //---- DUT ----
            cordic_arctan #(
                .INPUT_WIDTH     (IW),
                .OUTPUT_WIDTH    (OW),
                .DATA_FORMAT     (DATA_FMT),
                .PHASE_FORMAT    (PHASE_FMT),
                .PHASE_FRAC_BITS (PFB),
                .ROUND_MODE      (RND),
                .ITERATIONS      (ITER),
                .PRECISION       (0),
                .COARSE_ROTATION (COARSE),
                .PRE_NORMALIZE   (NORM),
                .ARCHITECTURE    (ARCH),
                .PIPELINE_MODE   (PIPE),
                .FLOW_CONTROL    (FLOW),
                .USER_WIDTH      (USER_WIDTH)
            ) u_dut (
                .i_clk        (clk),
                .i_clkEn      (clkEn),
                .i_rstN       (rstN),
                .i_xyValid    (xyValid),
                .o_xyReady    (xyReady),
                .i_x          (x),
                .i_y          (y),
                .i_xyLast     (xyLast),
                .i_xyUser     (xyUser),
                .o_phaseValid (phaseValid),
                .i_phaseReady (phaseReady),
                .o_phase      (phase),
                .o_phaseLast  (phaseLast),
                .o_phaseUser  (phaseUser)
            );

            //---- config-local functions ----
            // DUT output word -> real (two's complement, OW bits)
            function real phaseToReal(input [OW-1:0] p);
                reg signed [63:0] ext;
                begin
                    ext         = {{(64-OW){p[OW-1]}}, p};
                    phaseToReal = int64ToReal(ext);
                end
            endfunction

            // IW random bits -> 64-bit signed (sign / zero extension per DATA_FORMAT)
            function [63:0] extendIn(input [63:0] r);
                begin
                    if (DATA_FMT == 1) begin
                        extendIn = {{(64-IW){1'b0}}, r[IW-1:0]};
                    end else begin
                        extendIn = {{(64-IW){r[IW-1]}}, r[IW-1:0]};
                    end
                end
            endfunction

            function real sweepMag(input integer mi);
                begin
                    case (mi)
                        0:       sweepMag = fsReal;
                        1:       sweepMag = fsReal / 2.0;
                        2:       sweepMag = fsReal / 16.0;
                        3:       sweepMag = fsReal / 256.0;
                        4:       sweepMag = 64.0;
                        5:       sweepMag = 5.0;
                        default: sweepMag = 1.0;
                    endcase
                end
            endfunction

            //---- random helpers (seedStim only, so C10 and C13 see the same data) ----
            task automatic randReal(output real r);
                integer rr;
                begin
                    rr = $random(seedStim);
                    r  = int64ToReal({32'd0, rr}) / TWO_POW_32;
                end
            endtask

            task automatic rand64(output [63:0] r);
                integer ra;
                integer rb;
                begin
                    ra = $random(seedStim);
                    rb = $random(seedStim);
                    r  = {ra, rb};
                end
            endtask

            // round half up and clamp into the input range
            task automatic roundClamp(input real v, output reg signed [63:0] out);
                real r;
                begin
                    r = $floor(v + 0.5);
                    if (r > fsReal) begin
                        r = fsReal;
                    end
                    if (r < mnReal) begin
                        r = mnReal;
                    end
                    out = realToInt64(r);
                end
            endtask

            task automatic uniformXY(output reg signed [63:0] xv, output reg signed [63:0] yv);
                reg [63:0] r;
                begin
                    rand64(r);
                    xv = extendIn(r);
                    rand64(r);
                    yv = extendIn(r);
                end
            endtask

            task automatic logUniformXY(output reg signed [63:0] xv,
                                        output reg signed [63:0] yv);
                real u;
                real mag;
                real ang;
                begin
                    randReal(u);
                    mag = $pow(2.0, u * $itor((DATA_FMT == 1) ? IW : (IW - 1)));
                    randReal(u);
                    if (DATA_FMT == 1) begin
                        ang = u * (PI_REAL / 2.0);
                    end else begin
                        ang = -PI_REAL + (u * 2.0 * PI_REAL);
                    end
                    roundClamp(mag * $cos(ang), xv);
                    roundClamp(mag * $sin(ang), yv);
                end
            endtask

            //---- scoreboard push: ideal value, tolerance, assert flag ----
            task automatic pushExpected(input reg signed [63:0] xv, input reg signed [63:0] yv,
                                        input isLast, input [USER_WIDTH-1:0] user);
                real       ideal;
                real       tolS;
                reg        doAssert;
                reg [63:0] xa;
                reg [63:0] ya;
                reg [63:0] mag;
                integer    idx;
                begin
                    if ((xv == 64'sd0) && (yv == 64'sd0)) begin
                        ideal    = 0.0;      // (0,0): exact zero required
                        tolS     = 0.0;
                        doAssert = 1'b1;
                    end else begin
                        ideal = $atan2(int64ToReal(yv), int64ToReal(xv));
                        if (PHASE_FMT == 1) begin
                            ideal = ideal / PI_REAL;
                        end
                        ideal    = ideal * scaleF;
                        tolS     = tol;
                        doAssert = 1'b1;
                        xa       = (xv < 64'sd0) ? -xv : xv;
                        ya       = (yv < 64'sd0) ? -yv : yv;
                        mag      = (xa > ya) ? xa : ya;
                        if ((NORM == 0) && (mag < ASSERT_MIN)) begin
                            doAssert = 1'b0;
                        end
                        if ((COARSE == 0) && (xv < 64'sd0)) begin
                            doAssert = 1'b0;
                        end
                    end
                    idx          = wrPtr % QUEUE_DEPTH;
                    expQ[idx]    = ideal;
                    tolQ[idx]    = tolS;
                    xQ[idx]      = xv;
                    yQ[idx]      = yv;
                    assertQ[idx] = doAssert;
                    lastQ[idx]   = isLast;
                    userQ[idx]   = user;
                    wrPtr        = wrPtr + 1;
                end
            endtask

            //---- drive one sample and wait until the DUT accepts it ----
            task automatic sendXY(input reg signed [63:0] xv, input reg signed [63:0] yv);
                reg     accepted;
                integer k;
                reg     isLast;
                reg [USER_WIDTH-1:0] user;
                begin
                    if ((wrPtr - rdPtr) >= QUEUE_DEPTH) begin
                        // DUT is not producing outputs; drop the sample, keep going
                        errOverflow = errOverflow + 1;
                    end else begin
                        isLast = ((inCount % 16) == 15) ? 1'b1 : 1'b0;
                        user   = inCount[USER_WIDTH-1:0];
                        pushExpected(xv, yv, isLast, user);
                        @(negedge clk);
                        x       = xv[IW-1:0];
                        y       = yv[IW-1:0];
                        xyLast  = isLast;
                        xyUser  = user;
                        xyValid = 1'b1;
                        accepted = 1'b0;
                        k        = 0;
                        while (!accepted && (k < ACCEPT_TIMEOUT)) begin
                            @(posedge clk);
                            // values read here are the pre-edge ones the DUT sampled
                            if (xyValid && (xyReady === 1'b1) && clkEn) begin
                                accepted = 1'b1;
                            end
                            k = k + 1;
                        end
                        if (accepted) begin
                            lastAcceptCycle = cycle;
                            if (firstAccCycle < 0) begin
                                firstAccCycle = cycle;
                            end
                            inCount = inCount + 1;
                        end else begin
                            errTimeout = errTimeout + 1;
                        end
                    end
                end
            endtask

            // deassert valid for n clocks
            task automatic idle(input integer n);
                integer k;
                begin
                    @(negedge clk);
                    xyValid = 1'b0;
                    x       = {IW{1'b0}};
                    y       = {IW{1'b0}};
                    for (k = 1; k < n; k = k + 1) begin
                        @(negedge clk);
                    end
                end
            endtask

            // C10: random i_xyValid gaps (seedGap so the sample values stay
            // identical to the NonBlocking twin)
            task automatic maybeGap;
                integer r;
                begin
                    if (randomFlow) begin
                        r = $unsigned($random(seedGap)) % 100;
                        if (r < 30) begin
                            r = $unsigned($random(seedGap)) % 3;
                            idle(1 + r);
                        end
                    end
                end
            endtask

            task automatic waitDrain;
                integer k;
                begin
                    k = 0;
                    while ((rdPtr != wrPtr) && (k < DRAIN_TIMEOUT)) begin
                        @(negedge clk);
                        k = k + 1;
                    end
                end
            endtask

            task automatic corner(input reg signed [63:0] xv, input reg signed [63:0] yv);
                begin
                    maybeGap();
                    sendXY(xv, yv);
                end
            endtask

            //---- stimulus phases ----
            // a) angle sweep
            task automatic runSweep;
                integer           mi;
                integer           ai;
                real              mag;
                real              ang;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    for (mi = 0; mi < NUM_MAGS; mi = mi + 1) begin
                        mag = sweepMag(mi);
                        for (ai = 0; ai < nSweepAngles; ai = ai + 1) begin
                            if (DATA_FMT == 1) begin
                                ang = ($itor(ai) + 0.5) * (PI_REAL / 2.0) / $itor(nSweepAngles);
                            end else begin
                                ang = -PI_REAL + ($itor(ai) * 2.0 * PI_REAL / $itor(nSweepAngles));
                            end
                            roundClamp(mag * $cos(ang), xv);
                            roundClamp(mag * $sin(ang), yv);
                            if ((xv != 64'sd0) || (yv != 64'sd0)) begin
                                maybeGap();
                                sendXY(xv, yv);
                            end
                        end
                    end
                end
            endtask

            // b) uniform random
            task automatic runUniform;
                integer           i;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    for (i = 0; i < nUniform; i = i + 1) begin
                        uniformXY(xv, yv);
                        maybeGap();
                        sendXY(xv, yv);
                    end
                end
            endtask

            // c) log-uniform magnitude
            task automatic runLogUniform;
                integer           i;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    for (i = 0; i < nLogUniform; i = i + 1) begin
                        logUniformXY(xv, yv);
                        maybeGap();
                        sendXY(xv, yv);
                    end
                end
            endtask

            // d) corner cases
            task automatic runCorners;
                reg signed [63:0] fs;
                reg signed [63:0] mn;
                begin
                    fs = FS;
                    mn = MN;
                    if (DATA_FMT == 1) begin
                        corner(64'sd1, 64'sd0);
                        corner(64'sd1, 64'sd1);
                        corner(64'sd0, 64'sd1);
                        corner(fs, 64'sd0);
                        corner(fs, fs);
                        corner(64'sd0, fs);
                        corner(fs, 64'sd1);
                        corner(64'sd1, fs);
                        corner(64'sd0, 64'sd0);
                    end else begin
                        // 8 compass points at magnitude 1
                        corner(64'sd1, 64'sd0);
                        corner(64'sd1, 64'sd1);
                        corner(64'sd0, 64'sd1);
                        corner(-64'sd1, 64'sd1);
                        corner(-64'sd1, 64'sd0);
                        corner(-64'sd1, -64'sd1);
                        corner(64'sd0, -64'sd1);
                        corner(64'sd1, -64'sd1);
                        // 8 compass points at FS (includes the four corners)
                        corner(fs, 64'sd0);
                        corner(fs, fs);
                        corner(64'sd0, fs);
                        corner(-fs, fs);
                        corner(-fs, 64'sd0);        // expect +pi
                        corner(-fs, -fs);
                        corner(64'sd0, -fs);        // expect -pi/2
                        corner(fs, -fs);
                        corner(fs, 64'sd1);
                        corner(64'sd1, fs);
                        corner(-fs, 64'sd1);
                        corner(64'sd1, -fs);
                        corner(64'sd0, 64'sd0);     // expect 0
                        // most negative
                        corner(mn, 64'sd0);
                        corner(64'sd0, mn);
                        corner(mn, mn);
                        corner(mn, 64'sd1);
                        corner(64'sd1, mn);
                        corner(mn, -64'sd1);
                        corner(-64'sd1, mn);
                        corner(mn, fs);
                        corner(fs, mn);
                    end
                end
            endtask

            // e1) bursty valid: random gaps of 0..7 clocks
            task automatic runGaps;
                integer           i;
                integer           gap;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    for (i = 0; i < NUM_GAPS; i = i + 1) begin
                        gap = $unsigned($random(seedGap)) % 8;
                        if (gap > 0) begin
                            idle(gap);
                        end
                        uniformXY(xv, yv);
                        sendXY(xv, yv);
                    end
                end
            endtask

            // e2) one burst with random i_clkEn: the pipeline must hold
            task automatic runClkEn;
                integer           i;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    clkEnRandom = 1'b1;
                    for (i = 0; i < NUM_CLKEN; i = i + 1) begin
                        uniformXY(xv, yv);
                        sendXY(xv, yv);
                    end
                    clkEnRandom = 1'b0;
                end
            endtask

            // f) back-to-back streaming, throughput measurement
            task automatic runStream;
                integer           i;
                reg signed [63:0] xv;
                reg signed [63:0] yv;
                begin
                    strCount = 0;
                    for (i = 0; i < NUM_STREAM; i = i + 1) begin
                        uniformXY(xv, yv);
                        sendXY(xv, yv);
                        if (i == 0) begin
                            strFirst = lastAcceptCycle;
                        end
                        strLast  = lastAcceptCycle;
                        strCount = strCount + 1;
                    end
                    thrMeas = $itor(strLast - strFirst) / $itor(NUM_STREAM - 1);
                    thrFail = ((strLast - strFirst) > ((NUM_STREAM - 1) * THR_EXP)) ? 1'b1 : 1'b0;
                end
            endtask

            //---- flow-control randomisation (falling edge) ----
            task driveFlow;
                integer r;
                begin
                    if (randomFlow) begin
                        r          = $unsigned($random(seedFlow)) % 100;
                        phaseReady = (r < 60) ? 1'b1 : 1'b0;
                    end else begin
                        phaseReady = 1'b1;
                    end
                    if (randomFlow || clkEnRandom) begin
                        r     = $unsigned($random(seedFlow)) % 100;
                        clkEn = (r < 80) ? 1'b1 : 1'b0;
                    end else begin
                        clkEn = 1'b1;
                    end
                end
            endtask

            // i_phaseReady / i_clkEn change on the falling edge only
            always @(negedge clk) begin
                driveFlow();
            end

            //---- output monitor / scoreboard (rising edge, pre-edge values) ----
            task monitorOutput;
                reg     xfer;
                integer idx;
                real    dutR;
                real    err;
                real    absErr;
                real    twoPow;
                integer dec;
                reg [63:0] xa;
                reg [63:0] ya;
                begin
                    if (rstDone) begin
                        if (phaseValid === 1'bx) begin
                            errX = errX + 1;
                        end
                        if ((FLOW == 0) && (ARCH == 1) && (xyReady !== 1'b1)) begin
                            errReadyLow = errReadyLow + 1;
                        end
                        xfer = (phaseValid === 1'b1) && clkEn &&
                               ((FLOW == 1) ? phaseReady : 1'b1);
                        // a stalled output (clkEn low or back-pressure) must hold
                        if (holdPending) begin
                            if ((phaseValid !== 1'b1) || (phase !== holdPhase) ||
                                (phaseLast !== holdLast) || (phaseUser !== holdUser)) begin
                                errHold = errHold + 1;
                                if (printed < MAX_PRINT) begin
                                    $display("[tb_cordic_arctan] C%0d HOLD violation at cycle %0d",
                                             CFG, cycle);
                                    printed = printed + 1;
                                end
                            end
                        end
                        holdPending = (phaseValid === 1'b1) && !xfer;
                        holdPhase   = phase;
                        holdLast    = phaseLast;
                        holdUser    = phaseUser;
                        if (xfer) begin
                            if (firstOutCycle < 0) begin
                                firstOutCycle = cycle;
                            end
                            if (rdPtr == wrPtr) begin
                                errUnexpected = errUnexpected + 1;
                                if (printed < MAX_PRINT) begin
                                    $display("[tb_cordic_arctan] C%0d UNEXPECTED output cycle %0d",
                                             CFG, cycle);
                                    printed = printed + 1;
                                end
                            end else begin
                                idx = rdPtr % QUEUE_DEPTH;
                                if (^phase === 1'bx) begin
                                    errX = errX + 1;
                                end
                                dutR = phaseToReal(phase);
                                err  = dutR - expQ[idx];
                                if (MODULAR != 0) begin
                                    twoPow = pow2Real(OW);
                                    err    = err - (twoPow * $floor((err / twoPow) + 0.5));
                                end
                                absErr = absReal(err);
                                if ((phaseLast !== lastQ[idx]) || (phaseUser !== userQ[idx])) begin
                                    errLastUser = errLastUser + 1;
                                end
                                if (assertQ[idx]) begin
                                    nAsserted = nAsserted + 1;
                                    sumErr    = sumErr + err;
                                    sumSqErr  = sumSqErr + (err * err);
                                    if (absErr > maxErr) begin
                                        maxErr = absErr;
                                    end
                                    if (absErr <= 0.5) begin
                                        hist0 = hist0 + 1;
                                    end else if (absErr <= 1.0) begin
                                        hist1 = hist1 + 1;
                                    end else if (absErr <= 1.5) begin
                                        hist2 = hist2 + 1;
                                    end else begin
                                        hist3 = hist3 + 1;
                                    end
                                    xa  = (xQ[idx] < 64'sd0) ? -xQ[idx] : xQ[idx];
                                    ya  = (yQ[idx] < 64'sd0) ? -yQ[idx] : yQ[idx];
                                    dec = decadeOf((xa > ya) ? xa : ya);
                                    decCnt[dec]   = decCnt[dec] + 1;
                                    decSumSq[dec] = decSumSq[dec] + (err * err);
                                    if (absErr > decMax[dec]) begin
                                        decMax[dec] = absErr;
                                    end
                                    if (absErr > tolQ[idx]) begin
                                        errMismatch = errMismatch + 1;
                                        if (printed < MAX_PRINT) begin
                                            $write("[tb_cordic_arctan] C%0d MISMATCH sample=%0d",
                                                   CFG, rdPtr);
                                            $write(" x=%0d y=%0d ideal=%.4f", xQ[idx], yQ[idx],
                                                   expQ[idx]);
                                            $display(" dut=%.1f err=%.4f tol=%.3f", dutR, err,
                                                     tolQ[idx]);
                                            printed = printed + 1;
                                        end
                                    end
                                end else begin
                                    nUnasserted = nUnasserted + 1;
                                    if (absErr > maxErrUnasserted) begin
                                        maxErrUnasserted = absErr;
                                    end
                                end
                                if (csvFd != 0) begin
                                    $fwrite(csvFd, "%0d,%0d,%.6f,%.1f,%.6f\n",
                                            xQ[idx], yQ[idx], expQ[idx], dutR, err);
                                end
                                if (outCount < LOG_DEPTH) begin
                                    outLog[outCount] = {{(64-OW){phase[OW-1]}}, phase};
                                end
                                outCount = outCount + 1;
                                rdPtr    = rdPtr + 1;
                            end
                        end
                    end
                end
            endtask

            // scoreboard runs once per rising edge on the pre-edge values
            always @(posedge clk) begin
                monitorOutput();
            end

            //---- report ----
            task printReport;
                integer d;
                real    meanErr;
                real    rmsErr;
                real    pct0;
                real    pct1;
                real    pct2;
                real    pct3;
                begin
                    errLost  = wrPtr - rdPtr;
                    errCount = errMismatch + errUnexpected + errHold + errLastUser + errX +
                               errReadyLow + errTimeout + errOverflow + errLost;
                    if (CFG == 10) begin
                        errCount = errCount + twinMismatch;
                    end
                    fail = (errCount != 0) || (latencyMeas != LAT_EXP) || thrFail ||
                           (nAsserted == 0) || (maxErr > tol);
                    if (nAsserted > 0) begin
                        meanErr = sumErr / $itor(nAsserted);
                        rmsErr  = $sqrt(sumSqErr / $itor(nAsserted));
                        pct0    = 100.0 * $itor(hist0) / $itor(nAsserted);
                        pct1    = 100.0 * $itor(hist1) / $itor(nAsserted);
                        pct2    = 100.0 * $itor(hist2) / $itor(nAsserted);
                        pct3    = 100.0 * $itor(hist3) / $itor(nAsserted);
                    end else begin
                        meanErr = 0.0;
                        rmsErr  = 0.0;
                        pct0    = 0.0;
                        pct1    = 0.0;
                        pct2    = 0.0;
                        pct3    = 0.0;
                    end
                    $write("[tb_cordic_arctan] C%0d IN=%0d OUT=%0d FMT=%0d F=%0d N=%0d P=%0d G=%0d",
                           CFG, IW, OW, PHASE_FMT, F, N, P, G);
                    $write(" NORM=%0d ROUND=%0d ARCH=%0d PIPE=%0d samples=%0d latency=%0d/%0d",
                           NORM, RND, ARCH, PIPE, outCount, latencyMeas, LAT_EXP);
                    $write(" maxErr=%.3f LSB (%.4f deg) meanErr=%.4f rmsErr=%.4f",
                           maxErr, maxErr * degPerLsb, meanErr, rmsErr);
                    $write(" hist(|e|<=0.5/<=1/<=1.5/>1.5)=%.1f%%/%.1f%%/%.1f%%/%.1f%%",
                           pct0, pct1, pct2, pct3);
                    $display(" TOL=%.3f %0s", tol, fail ? "FAIL" : "PASS");
                    $write("[tb_cordic_arctan] C%0d extra: DATA=%0d COARSE=%0d FLOW=%0d ITER=%0d",
                           CFG, DATA_FMT, COARSE, FLOW, ITER);
                    $write(" PFB=%0d in=%0d out=%0d unasserted=%0d maxErrUnasserted=%.3f",
                           PFB, inCount, outCount, nUnasserted, maxErrUnasserted);
                    $write(" thr=%.3f/%0d clk/sample errors=%0d (mismatch=%0d unexpected=%0d",
                           thrMeas, THR_EXP, errCount, errMismatch, errUnexpected);
                    $write(" hold=%0d lastUser=%0d x=%0d readyLow=%0d timeout=%0d",
                           errHold, errLastUser, errX, errReadyLow, errTimeout);
                    $display(" overflow=%0d lost=%0d)", errOverflow, errLost);
                    if (CFG == 10) begin
                        $display("[tb_cordic_arctan] C%0d twin: C13 samples=%0d mismatches=%0d %0s",
                                 CFG, twinSamples, twinMismatch,
                                 (twinMismatch == 0) ? "PASS" : "FAIL");
                    end
                    if (CFG <= 2) begin
                        for (d = 0; d < NUM_DECADES; d = d + 1) begin
                            if (decCnt[d] > 0) begin
                                $write("[tb_cordic_arctan] C%0d decade=%0d mag=[1e%0d,1e%0d)",
                                       CFG, d, d, d + 1);
                                $display(" samples=%0d maxErr=%.3f rmsErr=%.4f", decCnt[d],
                                         decMax[d], $sqrt(decSumSq[d] / $itor(decCnt[d])));
                            end
                        end
                    end
                    cfgFail[CFG] = fail;
                end
            endtask

            // reports print in config order: the top level hands out the token
            always @(reportIdx) begin
                if (reportIdx == CFG) begin
                    printReport();
                end
            end

            //---- driver ----
            initial begin : drv
                integer d;
                clkEn       = 1'b1;
                xyValid     = 1'b0;
                x           = {IW{1'b0}};
                y           = {IW{1'b0}};
                xyLast      = 1'b0;
                xyUser      = {USER_WIDTH{1'b0}};
                phaseReady  = 1'b1;
                randomFlow  = 1'b0;
                clkEnRandom = 1'b0;
                seedStim    = SEED_STIM;
                seedFlow    = SEED_FLOW + CFG;
                seedGap     = SEED_GAP + CFG;
                wrPtr       = 0;
                rdPtr       = 0;
                inCount     = 0;
                outCount    = 0;
                nAsserted   = 0;
                nUnasserted = 0;
                maxErr      = 0.0;
                maxErrUnasserted = 0.0;
                sumErr      = 0.0;
                sumSqErr    = 0.0;
                hist0       = 0;
                hist1       = 0;
                hist2       = 0;
                hist3       = 0;
                for (d = 0; d < NUM_DECADES; d = d + 1) begin
                    decCnt[d]   = 0;
                    decMax[d]   = 0.0;
                    decSumSq[d] = 0.0;
                end
                errMismatch   = 0;
                errUnexpected = 0;
                errHold       = 0;
                errLastUser   = 0;
                errX          = 0;
                errReadyLow   = 0;
                errTimeout    = 0;
                errOverflow   = 0;
                errLost       = 0;
                errCount      = 0;
                printed       = 0;
                firstAccCycle = -1;
                firstOutCycle = -1;
                lastAcceptCycle = 0;
                latencyMeas   = -1;
                strFirst      = 0;
                strLast       = 0;
                strCount      = 0;
                thrMeas       = 0.0;
                thrFail       = 1'b0;
                fail          = 1'b0;
                holdPending   = 1'b0;
                holdPhase     = {OW{1'b0}};
                holdLast      = 1'b0;
                holdUser      = {USER_WIDTH{1'b0}};
                scaleF        = pow2Real(F);
                degPerLsb     = ((PHASE_FMT == 1) ? 180.0 : (180.0 / PI_REAL)) / scaleF;
                fsReal        = int64ToReal(FS);
                mnReal        = int64ToReal(MN);
                // spec 1.4: rounding + CORDIC residual 2^(F+1-N) + datapath truncation;
                // C12: + 2 LSB because the double reference cannot resolve better
                tol           = ((RND == 0) ? 1.0 : 0.5) + pow2Real(F + 1 - N) + 0.3 +
                                ((WIDE != 0) ? 2.0 : 0.0);
                csvFd         = 0;
                wait (rstDone);
                if (dumpCsv) begin
                    $sformat(csvName, "C%0d.csv", CFG);
                    csvFd = $fopen(csvName, "w");
                    $fwrite(csvFd, "x,y,ideal,dut,err\n");
                end
                repeat (4) @(negedge clk);
                // latency sample under clean flow: (FS, 0)
                sendXY(FS, 64'sd0);
                idle(1);
                waitDrain();
                latencyMeas = firstOutCycle - firstAccCycle;
                if (FLOW == 1) begin
                    randomFlow = 1'b1;
                end
                runSweep();
                runUniform();
                runLogUniform();
                runCorners();
                runGaps();
                runClkEn();
                randomFlow = 1'b0;
                idle(4);
                runStream();
                idle(1);
                waitDrain();
                if (csvFd != 0) begin
                    $fclose(csvFd);
                end
                cfgDone[CFG] = 1'b1;
            end
        end
    endgenerate

    //---- reset, plusargs, final report ------------------------------------
    initial begin
        clk          = 1'b0;
        rstN         = 1'b0;
        rstDone      = 1'b0;
        cycle        = 0;
        reportIdx    = -1;
        cfgDone      = {NUM_CFG{1'b0}};
        cfgFail      = {NUM_CFG{1'b0}};
        twinSamples  = 0;
        twinMismatch = 0;
        passCount    = 0;
        dumpCsv      = $test$plusargs("DUMP_CSV") ? 1'b1 : 1'b0;
        if ($test$plusargs("QUICK")) begin
            nSweepAngles = QUICK_ANGLES;
            nUniform     = QUICK_RANDOM;
            nLogUniform  = QUICK_RANDOM;
        end else begin
            nSweepAngles = SWEEP_ANGLES;
            nUniform     = NUM_UNIFORM;
            nLogUniform  = NUM_LOG_UNIFORM;
        end
        $display("[tb_cordic_arctan] start: %0d configs, sweep=%0dx%0d uniform=%0d logUniform=%0d",
                 NUM_CFG, nSweepAngles, SWEEP_MAGS, nUniform, nLogUniform);
        $write("[tb_cordic_arctan] legend: FMT 0=rad 1=scaled(pi units);");
        $display(" ARCH 1=parallel 0=word-serial");
        repeat (5) @(negedge clk);
        rstN = 1'b1;
        repeat (2) @(negedge clk);
        rstDone = 1'b1;
        wait (&cfgDone);
        // C10 (Blocking, random flow) must produce the same stream as C13
        twinSamples  = (gen_cfg[10].outCount < gen_cfg[13].outCount) ? gen_cfg[10].outCount
                                                                     : gen_cfg[13].outCount;
        if (twinSamples > LOG_DEPTH) begin
            twinSamples = LOG_DEPTH;
        end
        twinMismatch = (gen_cfg[10].outCount != gen_cfg[13].outCount) ? 1 : 0;
        for (ci = 0; ci < twinSamples; ci = ci + 1) begin
            if (gen_cfg[10].outLog[ci] !== gen_cfg[13].outLog[ci]) begin
                twinMismatch = twinMismatch + 1;
            end
        end
        for (ci = 0; ci < NUM_CFG; ci = ci + 1) begin
            reportIdx = ci;
            #1;
        end
        passCount = 0;
        for (ci = 0; ci < NUM_CFG; ci = ci + 1) begin
            if (!cfgFail[ci]) begin
                passCount = passCount + 1;
            end
        end
        if (cfgFail == {NUM_CFG{1'b0}}) begin
            $display("[tb_cordic_arctan] RESULT: PASS (%0d/%0d configs)", passCount, NUM_CFG);
        end else begin
            $display("[tb_cordic_arctan] RESULT: FAIL (%0d/%0d configs)", passCount, NUM_CFG);
        end
        $finish;
    end

    // watchdog
    initial begin
        #(PERIOD * WATCHDOG_CYCLES);
        $display("[tb_cordic_arctan] RESULT: FAIL (watchdog timeout, done=%b)", cfgDone);
        $finish;
    end

`ifdef DUMP
    initial begin
        $dumpfile("tb_cordic_arctan.vcd");
        $dumpvars(0, tb_cordic_arctan);
    end
`endif

endmodule

`default_nettype wire
