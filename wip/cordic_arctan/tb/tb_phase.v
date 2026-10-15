`timescale 1ns / 1ps
`default_nettype none

//----------------------------------------------------------------------------
// Module : tb_phase
// Purpose: A/B bench of the arctangent block: new cordic_arctan based `phase`
//          (LATENCY = 40 drop-in and LATENCY = 0 natural) against the legacy
//          div_gen + atan_lut `phase_divlut_ref`, same stimulus, $atan2 ideal.
//
// All three DUTs see the identical 32-bit I/Q stream (openofdm distribution):
//   (a) angle sweep, 3600 angles at magnitudes 2^k, k = 2..30
//   (b) 100 000 random samples with log-uniform magnitude 2^2 .. 2^31
//   (c)  20 000 uniform random 32-bit samples
//   (d) corners: axes at 1 and full scale, diagonals, (0,0), most-negative,
//       the legacy divider's 2^22 dividend/divisor switch point
// Ideal = atan2(q, i) * 512 (real); error e = DUT - ideal in LSB
// (1 LSB = 1/512 rad = 0.112 deg). Per DUT: max/mean/RMS error, histogram,
// error by magnitude decade and by stimulus category, measured latency.
// Plus the pairwise new-vs-legacy difference distribution.
// PASS iff: new max|e| <= 1.0 LSB (both LATENCY variants), default latency
// == 40 == legacy latency, natural latency == cordicArctanLatency(), new
// max|e| <= legacy max|e|, no sample lost/duplicated, new outputs 0 for (0,0).
// (0,0) is excluded from the error statistics: the legacy path divides by
// zero there, its output is only reported.
//
// i_enable is held at 1: the legacy delayT/divider path ignores it anyway,
// and the core's i_clkEn is exercised by tb_cordic_arctan.
//
// Build (see tools/run_tb.sh): verilog/phase.v cordic_arctan.v delayT.v
// divider.v div_gen.v lut_roms.v (-d LUT_DIR=<abs verilog dir>),
// tb/phase_divlut_ref.v, the div_gen funcsim netlist (+ glbl, -L unisims_ver)
// and ip_repo/div_gen_xlslice/synth/div_gen_xlslice_0_0.v (+ xlslice hdl).
// Plusargs: +DUMP_CSV writes tb_phase_<dut>.csv (x,y,ideal,dut,err);
//           +QUICK runs a tenth of the sweep/random counts (bring-up only).
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
module tb_phase;

    //---- Parameters ----
    localparam         PERIOD         = 10;             // 100 MHz, the board clock
    localparam integer DATA_WIDTH     = 32;
    localparam integer PHASE_WIDTH    = 16;
    localparam integer ITERATIONS     = 14;             // must equal phase.v default (checked)
    localparam integer SCALE_SHIFT    = 9;              // ATAN_LUT_SCALE_SHIFT
    localparam real    SCALE          = 512.0;
    localparam real    PI_R           = 3.14159265358979323846;
    localparam real    LSB_DEG        = 180.0 / (PI_R * SCALE);
    localparam integer N_SWEEP_ANGLES = 3600;
    localparam integer SWEEP_K_MIN    = 2;
    localparam integer SWEEP_K_MAX    = 30;
    localparam integer N_LOG_RANDOM   = 100000;
    localparam integer N_UNI_RANDOM   = 20000;
    localparam integer N_CORNER_MAX   = 64;
    localparam integer MAX_SAMPLES    = N_SWEEP_ANGLES * (SWEEP_K_MAX - SWEEP_K_MIN + 1)
                                        + N_LOG_RANDOM + N_UNI_RANDOM + N_CORNER_MAX;
    localparam integer N_DUT          = 3;
    localparam integer D_NEW          = 0;              // phase, LATENCY = 40
    localparam integer D_NAT          = 1;              // phase, LATENCY = 0
    localparam integer D_LEG          = 2;              // phase_divlut_ref
    localparam integer N_CAT          = 4;              // sweep, logrand, unirand, corner
    localparam integer N_DECADE       = 10;
    localparam integer N_HIST         = 4;              // <=0.5, <=1, <=1.5, >1.5
    localparam integer N_DIFF         = 7;              // <=-3, -2, -1, 0, 1, 2, >=3
    localparam integer LEGACY_LATENCY = 40;
    localparam real    TOL_NEW        = 1.0;
    localparam integer DRAIN_CYCLES   = 100;            // wait after the last input
    localparam integer GAP_PERIOD     = 997;            // bursty input: a gap every 997

    localparam integer FS_POS         = 2147483647;
    localparam integer FS_NEG         = -2147483647 - 1;   // most negative 32-bit
    // The Xilinx funcsim netlist's glbl holds every primitive in reset (GSR)
    // for the first 100 ns of simulated time; no stimulus before that.
    localparam integer RESET_CYCLES   = 25;

    // Function header; the guard macro is global across files, see phase.v.
    `undef CORDIC_ARCTAN_VH
    `include "cordic_arctan.vh"
    localparam integer NAT_LATENCY    = cordicArctanLatency(1, 2, ITERATIONS, PHASE_WIDTH,
                                                            SCALE_SHIFT, 1);

    //---- DUT connections ----
    reg                          clk = 1'b0;
    reg                          reset;
    reg                          enable;
    reg  signed [DATA_WIDTH-1:0] inI;
    reg  signed [DATA_WIDTH-1:0] inQ;
    reg                          inStrobe;
    wire signed [PHASE_WIDTH-1:0] phaseNew;
    wire                          strobeNew;
    wire signed [PHASE_WIDTH-1:0] phaseNat;
    wire                          strobeNat;
    wire signed [PHASE_WIDTH-1:0] phaseLeg;
    wire                          strobeLeg;
    wire signed [PHASE_WIDTH-1:0] phaseOut  [0:N_DUT-1];
    wire                          strobeOut [0:N_DUT-1];

    //---- Stimulus store and scoreboard ----
    reg  signed [DATA_WIDTH-1:0]  stimI    [0:MAX_SAMPLES-1];
    reg  signed [DATA_WIDTH-1:0]  stimQ    [0:MAX_SAMPLES-1];
    real                          ideal    [0:MAX_SAMPLES-1];
    integer                       stimCat  [0:MAX_SAMPLES-1];
    integer                       stimDec  [0:MAX_SAMPLES-1];
    integer                       inCycle  [0:MAX_SAMPLES-1];
    reg  signed [PHASE_WIDTH-1:0] dutOut   [0:N_DUT-1][0:MAX_SAMPLES-1];
    integer                       nStim;
    integer                       nSent;
    integer                       zeroIdx;
    integer                       seed;
    integer                       cycle;
    reg                           quick;          // +QUICK: reduced counts (bring-up)
    integer                       nSweepAngles;
    integer                       nSweep;
    integer                       nLogRandom;
    integer                       nUniRandom;

    //---- Per-DUT statistics ----
    integer outCount   [0:N_DUT-1];
    integer extraOut   [0:N_DUT-1];
    integer latMin     [0:N_DUT-1];
    integer latMax     [0:N_DUT-1];
    integer errCount   [0:N_DUT-1];
    real    errMax     [0:N_DUT-1];
    integer errMaxIdx  [0:N_DUT-1];
    real    errSum     [0:N_DUT-1];
    real    errSq      [0:N_DUT-1];
    integer hist       [0:N_DUT-1][0:N_HIST-1];
    integer decCnt     [0:N_DUT-1][0:N_DECADE-1];
    real    decMax     [0:N_DUT-1][0:N_DECADE-1];
    real    decSq      [0:N_DUT-1][0:N_DECADE-1];
    integer catCnt     [0:N_DUT-1][0:N_CAT-1];
    real    catMax     [0:N_DUT-1][0:N_CAT-1];
    real    catSq      [0:N_DUT-1][0:N_CAT-1];
    integer zeroOut    [0:N_DUT-1];
    integer csvFd      [0:N_DUT-1];
    reg     dumpCsv;

    //---- Pairwise statistics ----
    integer diffHist   [0:N_DIFF-1];
    integer diffMax;
    integer natMismatch;

    //---- Pass/fail bookkeeping ----
    integer nChecks;
    integer nFails;

    //---- Clock and cycle counter ----
    always #(PERIOD / 2) clk = ~clk;

    // cycle counts rising edges; sampled on the falling edge by driver/monitor
    always @(posedge clk) begin
        cycle <= cycle + 1;
    end

    //---- DUTs ----
    // u_dut_new deliberately takes phase's parameter DEFAULTS (LATENCY, ITERATIONS):
    // dot11.v instantiates phase without overrides, so the 40-cycle drop-in and the
    // accuracy checks below must cover exactly that configuration.
    phase #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut_new (
        .i_clock         (clk),
        .i_reset         (reset),
        .i_enable        (enable),
        .i_in_i          (inI),
        .i_in_q          (inQ),
        .i_input_strobe  (inStrobe),
        .o_phase         (phaseNew),
        .o_output_strobe (strobeNew)
    );

    // u_dut_nat: same core (default ITERATIONS), no latency padding.
    phase #(
        .DATA_WIDTH (DATA_WIDTH),
        .LATENCY    (0)
    ) u_dut_nat (
        .i_clock         (clk),
        .i_reset         (reset),
        .i_enable        (enable),
        .i_in_i          (inI),
        .i_in_q          (inQ),
        .i_input_strobe  (inStrobe),
        .o_phase         (phaseNat),
        .o_output_strobe (strobeNat)
    );

    phase_divlut_ref #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut_leg (
        .i_clock         (clk),
        .i_reset         (reset),
        .i_enable        (enable),
        .i_in_i          (inI),
        .i_in_q          (inQ),
        .i_input_strobe  (inStrobe),
        .o_phase         (phaseLeg),
        .o_output_strobe (strobeLeg)
    );

    assign phaseOut[D_NEW]  = phaseNew;
    assign strobeOut[D_NEW] = strobeNew;
    assign phaseOut[D_NAT]  = phaseNat;
    assign strobeOut[D_NAT] = strobeNat;
    assign phaseOut[D_LEG]  = phaseLeg;
    assign strobeOut[D_LEG] = strobeLeg;

    //---- Helpers ----
    function real absReal(input real v);
        begin
            absReal = (v < 0.0) ? -v : v;
        end
    endfunction

    // round half away from zero, clamped to the signed 32-bit range
    function integer roundReal(input real v);
        real t;
        begin
            t = (v >= 0.0) ? $floor(v + 0.5) : -$floor(-v + 0.5);
            if (t > 2147483647.0) begin
                t = 2147483647.0;
            end
            if (t < -2147483648.0) begin
                t = -2147483648.0;
            end
            roundReal = $rtoi(t);
        end
    endfunction

    // uniform real in [0, 1)
    function real urand(input integer dummy);
        integer r;
        begin
            r = $random(seed);
            urand = ($itor(r) + 2147483648.0) / 4294967296.0;
        end
    endfunction

    // magnitude decade of max(|x|,|y|): 0 for 1..9, 1 for 10..99, ...; -1 for (0,0)
    function integer decadeOf(input integer x, input integer y);
        real ax;
        real ay;
        real p;
        integer d;
        begin
            ax = absReal($itor(x));
            ay = absReal($itor(y));
            if (ay > ax) begin
                ax = ay;
            end
            if (ax < 1.0) begin
                decadeOf = -1;
            end else begin
                d = 0;
                p = 10.0;
                while ((ax >= p) && (d < (N_DECADE - 1))) begin
                    d = d + 1;
                    p = p * 10.0;
                end
                decadeOf = d;
            end
        end
    endfunction

    function [63:0] dutName(input integer d);
        begin
            case (d)
                D_NEW:   dutName = "new";
                D_NAT:   dutName = "nat";
                D_LEG:   dutName = "legacy";
                default: dutName = "?";
            endcase
        end
    endfunction

    function [63:0] catName(input integer c);
        begin
            case (c)
                0:       catName = "sweep";
                1:       catName = "logrand";
                2:       catName = "unirand";
                3:       catName = "corner";
                default: catName = "?";
            endcase
        end
    endfunction

    task addSample(input integer x, input integer y, input integer cat);
        begin
            if (nStim >= MAX_SAMPLES) begin
                $display("[tb_phase] ERROR: stimulus store full (%0d)", MAX_SAMPLES);
                $finish;
            end
            stimI[nStim]   = x;
            stimQ[nStim]   = y;
            ideal[nStim]   = $atan2($itor(y), $itor(x)) * SCALE;
            stimCat[nStim] = cat;
            stimDec[nStim] = decadeOf(x, y);
            if ((x == 0) && (y == 0)) begin
                zeroIdx = nStim;
            end
            nStim = nStim + 1;
        end
    endtask

    task addPolar(input real mag, input real ang, input integer cat);
        integer x;
        integer y;
        begin
            x = roundReal(mag * $cos(ang));
            y = roundReal(mag * $sin(ang));
            if ((x != 0) || (y != 0)) begin
                addSample(x, y, cat);
            end
        end
    endtask

    task genStimulus;
        integer k;
        integer j;
        integer n;
        integer x;
        integer y;
        real    mag;
        real    ang;
        begin
            nStim   = 0;
            zeroIdx = -1;
            // (a) angle sweep at magnitudes 2^k
            for (k = SWEEP_K_MIN; k <= SWEEP_K_MAX; k = k + 1) begin
                mag = 2.0 ** k;
                for (j = 0; j < nSweepAngles; j = j + 1) begin
                    ang = -PI_R + (2.0 * PI_R * j) / nSweepAngles;
                    addPolar(mag, ang, 0);
                end
            end
            // (b) log-uniform magnitude 2^2 .. 2^31, uniform angle
            for (n = 0; n < nLogRandom; n = n + 1) begin
                mag = 2.0 ** (2.0 + 29.0 * urand(0));
                ang = -PI_R + 2.0 * PI_R * urand(0);
                addPolar(mag, ang, 1);
            end
            // (c) uniform random 32-bit
            for (n = 0; n < nUniRandom; n = n + 1) begin
                x = $random(seed);
                y = $random(seed);
                if ((x != 0) || (y != 0)) begin
                    addSample(x, y, 2);
                end
            end
            // (d) corners
            addSample(     FS_POS,           0, 3);
            addSample(          0,      FS_POS, 3);
            addSample(    -FS_POS,           0, 3);
            addSample(          0,     -FS_POS, 3);
            addSample(     FS_POS,      FS_POS, 3);
            addSample(     FS_POS,     -FS_POS, 3);
            addSample(    -FS_POS,      FS_POS, 3);
            addSample(    -FS_POS,     -FS_POS, 3);
            addSample(          1,           0, 3);
            addSample(          0,           1, 3);
            addSample(         -1,           0, 3);
            addSample(          0,          -1, 3);
            addSample(          1,           1, 3);
            addSample(          1,          -1, 3);
            addSample(         -1,           1, 3);
            addSample(         -1,          -1, 3);
            addSample(     FS_POS,           1, 3);
            addSample(          1,      FS_POS, 3);
            addSample(    -FS_POS,           1, 3);
            addSample(          1,     -FS_POS, 3);
            addSample(     FS_POS,          -1, 3);
            addSample(         -1,      FS_POS, 3);
            addSample(    -FS_POS,          -1, 3);
            addSample(         -1,     -FS_POS, 3);
            addSample(     FS_NEG,           0, 3);
            addSample(          0,      FS_NEG, 3);
            addSample(     FS_NEG,      FS_NEG, 3);
            addSample(     FS_NEG,      FS_POS, 3);
            addSample(     FS_POS,      FS_NEG, 3);
            addSample(     FS_NEG,           1, 3);
            addSample(          1,      FS_NEG, 3);
            addSample(     FS_NEG,          -1, 3);
            addSample(         -1,      FS_NEG, 3);
            addSample(          2,           1, 3);
            addSample(          1,           2, 3);
            addSample(         -2,           1, 3);
            addSample(          3,          -1, 3);
            addSample(    4194304,     4194304, 3);   // legacy dividend/divisor switch
            addSample(    4194305,     4194305, 3);
            addSample(    4194304,           1, 3);
            addSample(    4194305,           1, 3);
            addSample(          1,     4194305, 3);
            addSample(   -4194305,     4194304, 3);
            addSample(      65536,       65535, 3);
            addSample(          0,           0, 3);
        end
    endtask

    task initStats;
        integer d;
        integer i;
        begin
            for (d = 0; d < N_DUT; d = d + 1) begin
                outCount[d]  = 0;
                extraOut[d]  = 0;
                latMin[d]    = 1 << 30;
                latMax[d]    = -1;
                errCount[d]  = 0;
                errMax[d]    = 0.0;
                errMaxIdx[d] = -1;
                errSum[d]    = 0.0;
                errSq[d]     = 0.0;
                zeroOut[d]   = 0;
                csvFd[d]     = 0;
                for (i = 0; i < N_HIST; i = i + 1) begin
                    hist[d][i] = 0;
                end
                for (i = 0; i < N_DECADE; i = i + 1) begin
                    decCnt[d][i] = 0;
                    decMax[d][i] = 0.0;
                    decSq[d][i]  = 0.0;
                end
                for (i = 0; i < N_CAT; i = i + 1) begin
                    catCnt[d][i] = 0;
                    catMax[d][i] = 0.0;
                    catSq[d][i]  = 0.0;
                end
            end
            for (i = 0; i < N_DIFF; i = i + 1) begin
                diffHist[i] = 0;
            end
            diffMax     = 0;
            natMismatch = 0;
            nChecks     = 0;
            nFails      = 0;
        end
    endtask

    // one DUT output: score it against the stimulus it belongs to
    task automatic record(input integer d, input signed [PHASE_WIDTH-1:0] v);
        integer n;
        integer lat;
        integer dec;
        integer cat;
        real    e;
        real    ae;
        begin
            n = outCount[d];
            if (n >= nSent) begin
                extraOut[d] = extraOut[d] + 1;
            end else begin
                dutOut[d][n] = v;
                lat = cycle - inCycle[n];
                if (lat < latMin[d]) begin
                    latMin[d] = lat;
                end
                if (lat > latMax[d]) begin
                    latMax[d] = lat;
                end
                e  = $itor(v) - ideal[n];
                ae = absReal(e);
                if (n == zeroIdx) begin
                    zeroOut[d] = v;
                end else begin
                    errCount[d] = errCount[d] + 1;
                    errSum[d]   = errSum[d] + e;
                    errSq[d]    = errSq[d] + e * e;
                    if (ae > errMax[d]) begin
                        errMax[d]    = ae;
                        errMaxIdx[d] = n;
                    end
                    if (ae <= 0.5) begin
                        hist[d][0] = hist[d][0] + 1;
                    end else if (ae <= 1.0) begin
                        hist[d][1] = hist[d][1] + 1;
                    end else if (ae <= 1.5) begin
                        hist[d][2] = hist[d][2] + 1;
                    end else begin
                        hist[d][3] = hist[d][3] + 1;
                    end
                    dec = stimDec[n];
                    decCnt[d][dec] = decCnt[d][dec] + 1;
                    decSq[d][dec]  = decSq[d][dec] + e * e;
                    if (ae > decMax[d][dec]) begin
                        decMax[d][dec] = ae;
                    end
                    cat = stimCat[n];
                    catCnt[d][cat] = catCnt[d][cat] + 1;
                    catSq[d][cat]  = catSq[d][cat] + e * e;
                    if (ae > catMax[d][cat]) begin
                        catMax[d][cat] = ae;
                    end
                end
                if (dumpCsv) begin
                    $fwrite(csvFd[d], "%0d,%0d,%.4f,%0d,%.4f\n",
                            stimI[n], stimQ[n], ideal[n], v, e);
                end
            end
            outCount[d] = n + 1;
        end
    endtask

    //---- Monitors: sample DUT outputs on the falling edge ----
    genvar g;
    generate
        for (g = 0; g < N_DUT; g = g + 1) begin : gen_mon
            always @(negedge clk) begin
                if (!reset && (strobeOut[g] === 1'b1)) begin
                    record(g, phaseOut[g]);
                end
            end
        end
    endgenerate

    //---- Reports ----
    task reportDut(input integer d);
        integer i;
        real    mean;
        real    rms;
        real    dutV;
        begin
            if (errCount[d] > 0) begin
                mean = errSum[d] / errCount[d];
                rms  = $sqrt(errSq[d] / errCount[d]);
            end else begin
                mean = 0.0;
                rms  = 0.0;
            end
            $write("[tb_phase] %0s samples=%0d/%0d extra=%0d latency=%0d..%0d ",
                   dutName(d), outCount[d], nStim, extraOut[d], latMin[d], latMax[d]);
            $display("maxErr=%.3f LSB (%.3f deg) at (%0d,%0d) ideal=%.3f dut=%0d",
                     errMax[d], errMax[d] * LSB_DEG,
                     (errMaxIdx[d] >= 0) ? stimI[errMaxIdx[d]] : 0,
                     (errMaxIdx[d] >= 0) ? stimQ[errMaxIdx[d]] : 0,
                     (errMaxIdx[d] >= 0) ? ideal[errMaxIdx[d]] : 0.0,
                     (errMaxIdx[d] >= 0) ? dutOut[d][errMaxIdx[d]] : 0);
            $write("[tb_phase] %0s meanErr=%.4f LSB rmsErr=%.4f LSB (%.4f deg) ",
                   dutName(d), mean, rms, rms * LSB_DEG);
            $display("hist(|e|<=0.5/<=1/<=1.5/>1.5)=%.2f%%/%.2f%%/%.2f%%/%.2f%% zeroOut=%0d",
                     100.0 * hist[d][0] / errCount[d], 100.0 * hist[d][1] / errCount[d],
                     100.0 * hist[d][2] / errCount[d], 100.0 * hist[d][3] / errCount[d],
                     zeroOut[d]);
            for (i = 0; i < N_DECADE; i = i + 1) begin
                if (decCnt[d][i] > 0) begin
                    $display("[tb_phase] %0s   decade 1e%0d: n=%0d maxErr=%.3f rmsErr=%.4f LSB",
                             dutName(d), i, decCnt[d][i], decMax[d][i],
                             $sqrt(decSq[d][i] / decCnt[d][i]));
                end
            end
            for (i = 0; i < N_CAT; i = i + 1) begin
                if (catCnt[d][i] > 0) begin
                    $display("[tb_phase] %0s   %0s: n=%0d maxErr=%.3f rmsErr=%.4f LSB",
                             dutName(d), catName(i), catCnt[d][i], catMax[d][i],
                             $sqrt(catSq[d][i] / catCnt[d][i]));
                end
            end
        end
    endtask

    task reportPairwise;
        integer n;
        integer df;
        integer adf;
        integer nCmp;
        begin
            nCmp = 0;
            for (n = 0; n < nStim; n = n + 1) begin
                if ((n < outCount[D_NEW]) && (n < outCount[D_LEG]) && (n != zeroIdx)) begin
                    nCmp = nCmp + 1;
                    df = dutOut[D_NEW][n] - dutOut[D_LEG][n];
                    adf = (df < 0) ? -df : df;
                    if (adf > diffMax) begin
                        diffMax = adf;
                    end
                    if (df <= -3) begin
                        diffHist[0] = diffHist[0] + 1;
                    end else if (df >= 3) begin
                        diffHist[6] = diffHist[6] + 1;
                    end else begin
                        diffHist[df + 3] = diffHist[df + 3] + 1;
                    end
                end
                if ((n < outCount[D_NEW]) && (n < outCount[D_NAT])) begin
                    if (dutOut[D_NEW][n] !== dutOut[D_NAT][n]) begin
                        natMismatch = natMismatch + 1;
                    end
                end
            end
            $write("[tb_phase] diff new-legacy: n=%0d max|diff|=%0d LSB ", nCmp, diffMax);
            $display("hist(<=-3/-2/-1/0/+1/+2/>=+3)=%0d/%0d/%0d/%0d/%0d/%0d/%0d",
                     diffHist[0], diffHist[1], diffHist[2], diffHist[3],
                     diffHist[4], diffHist[5], diffHist[6]);
            $display("[tb_phase] new vs nat output mismatches: %0d", natMismatch);
        end
    endtask

    task check(input [511:0] name, input cond);
        begin
            nChecks = nChecks + 1;
            if (!cond) begin
                nFails = nFails + 1;
            end
            $display("[tb_phase] check %0s: %0s", name, cond ? "PASS" : "FAIL");
        end
    endtask

    //---- Main ----
    integer n;
    integer d;
    integer allDone;
    integer drain;

    initial begin
`ifdef DUMP
        $dumpfile("tb_phase.vcd");
        $dumpvars(0, tb_phase);
`endif
        seed     = 32'h5EED0001;
        cycle    = 0;
        nSent    = 0;
        reset    = 1'b1;
        enable   = 1'b1;
        inI      = {DATA_WIDTH{1'b0}};
        inQ      = {DATA_WIDTH{1'b0}};
        inStrobe = 1'b0;
        dumpCsv  = $test$plusargs("DUMP_CSV");
        quick    = $test$plusargs("QUICK");
        nSweepAngles = quick ? (N_SWEEP_ANGLES / 10) : N_SWEEP_ANGLES;
        nSweep       = nSweepAngles * (SWEEP_K_MAX - SWEEP_K_MIN + 1);
        nLogRandom   = quick ? (N_LOG_RANDOM / 10) : N_LOG_RANDOM;
        nUniRandom   = quick ? (N_UNI_RANDOM / 10) : N_UNI_RANDOM;
        initStats;
        genStimulus;
        $write("[tb_phase] stimulus: %0d samples (sweep %0d, logrand %0d, unirand %0d, ",
               nStim, nSweep, nLogRandom, nUniRandom);
        $display("corner %0d), zeroIdx=%0d quick=%0d",
                 nStim - nSweep - nLogRandom - nUniRandom, zeroIdx, quick);
        $write("[tb_phase] DUTs: new(defaults LATENCY=%0d ITERATIONS=%0d) ",
               u_dut_new.LATENCY, u_dut_new.ITERATIONS);
        $display("nat(LATENCY=0 ITERATIONS=%0d, formula %0d) legacy(%0d)",
                 u_dut_nat.ITERATIONS, NAT_LATENCY, LEGACY_LATENCY);
        if (dumpCsv) begin
            csvFd[D_NEW] = $fopen("tb_phase_new.csv", "w");
            csvFd[D_NAT] = $fopen("tb_phase_nat.csv", "w");
            csvFd[D_LEG] = $fopen("tb_phase_legacy.csv", "w");
            for (d = 0; d < N_DUT; d = d + 1) begin
                $fwrite(csvFd[d], "x,y,ideal,dut,err\n");
            end
        end

        repeat (RESET_CYCLES) @(negedge clk);
        reset = 1'b0;
        repeat (3) @(negedge clk);

        // drive: one sample per clock, with a short idle gap every GAP_PERIOD samples
        for (n = 0; n < nStim; n = n + 1) begin
            @(negedge clk);
            if ((n % GAP_PERIOD) == (GAP_PERIOD - 1)) begin
                inStrobe = 1'b0;
                repeat (1 + ((n / GAP_PERIOD) % 7)) @(negedge clk);
            end
            inI        = stimI[n];
            inQ        = stimQ[n];
            inStrobe   = 1'b1;
            inCycle[n] = cycle;
            nSent      = n + 1;
        end
        @(negedge clk);
        inStrobe = 1'b0;
        inI      = {DATA_WIDTH{1'b0}};
        inQ      = {DATA_WIDTH{1'b0}};

        // drain
        drain   = 0;
        allDone = 0;
        while (!allDone && (drain < DRAIN_CYCLES)) begin
            @(negedge clk);
            drain   = drain + 1;
            allDone = (outCount[D_LEG] >= nStim) && (outCount[D_NEW] >= nStim)
                      && (outCount[D_NAT] >= nStim);
        end
        repeat (5) @(negedge clk);
        if (dumpCsv) begin
            for (d = 0; d < N_DUT; d = d + 1) begin
                $fclose(csvFd[d]);
            end
        end

        //---- Reports ----
        for (d = 0; d < N_DUT; d = d + 1) begin
            reportDut(d);
        end
        reportPairwise;

        //---- Checks ----
        check("legacy sample count", outCount[D_LEG] == nStim && extraOut[D_LEG] == 0);
        check("legacy latency constant", latMin[D_LEG] == latMax[D_LEG]);
        check("legacy latency == 40", latMin[D_LEG] == LEGACY_LATENCY);
        check("new sample count", outCount[D_NEW] == nStim && extraOut[D_NEW] == 0);
        check("nat sample count", outCount[D_NAT] == nStim && extraOut[D_NAT] == 0);
        check("new latency constant", latMin[D_NEW] == latMax[D_NEW]);
        check("nat latency constant", latMin[D_NAT] == latMax[D_NAT]);
        check("new latency == 40", latMin[D_NEW] == LEGACY_LATENCY);
        check("new latency == legacy latency", latMin[D_NEW] == latMin[D_LEG]);
        check("nat latency == cordicArctanLatency()", latMin[D_NAT] == NAT_LATENCY);
        check("phase default ITERATIONS == 14", u_dut_new.ITERATIONS == ITERATIONS);
        check("phase default LATENCY == 40", u_dut_new.LATENCY == LEGACY_LATENCY);
        check("new max|e| <= 1.0 LSB", errMax[D_NEW] <= TOL_NEW);
        check("nat max|e| <= 1.0 LSB", errMax[D_NAT] <= TOL_NEW);
        check("new max|e| <= legacy max|e|", errMax[D_NEW] <= errMax[D_LEG]);
        check("new (0,0) -> 0", zeroOut[D_NEW] == 0);
        check("nat (0,0) -> 0", zeroOut[D_NAT] == 0);
        check("new == nat outputs", natMismatch == 0);
        if (nFails == 0) begin
            $display("[tb_phase] RESULT: PASS (%0d/%0d checks)", nChecks, nChecks);
        end else begin
            $display("[tb_phase] RESULT: FAIL (%0d/%0d checks failed)", nFails, nChecks);
        end
        $finish;
    end

endmodule

`default_nettype wire
