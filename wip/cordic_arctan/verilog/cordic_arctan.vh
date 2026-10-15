//----------------------------------------------------------------------------
// Module : cordic_arctan.vh (include file, no module)
// Purpose: Elaboration-time latency function of the cordic_arctan core.
// cordicArctanLatency() reproduces the derivation of the core's LATENCY
// localparam (spec 1.1) so that a wrapper (phase.v) can pad or check the
// delay with the same integer math the core itself uses.
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
// Usage: `include "cordic_arctan.vh" INSIDE the body of every module that
// calls the function (Verilog-2001 has no compilation-unit functions).
// The guard below only protects against a nested/double include within one
// module body; it is undefined again at the end because `define macros are
// global across all files of one xvlog / Vivado run and a classic guard would
// hide the function from the second module that includes this file.
//----------------------------------------------------------------------------
`ifndef CORDIC_ARCTAN_VH
`define CORDIC_ARCTAN_VH

// Latency in i_clk cycles from the accepted input beat to o_phaseValid.
// architecture : 1 Parallel, 0 Word_Serial
// pipelineMode : 0 none, 1 optimal (every 2nd iteration), 2 maximum
// iterations   : 0 auto (min(48, F+3)), else 1..48
// outputWidth  : OUTPUT_WIDTH of the core
// phaseFracBits: 0 auto (outputWidth-3), else fractional bits F
// preNormalize : 1 LZC + barrel shift pre-stages (3 regs), 0 none (1 reg)
function integer cordicArctanLatency(
    input integer architecture,
    input integer pipelineMode,
    input integer iterations,
    input integer outputWidth,
    input integer phaseFracBits,
    input integer preNormalize
);
    integer fracBits;
    integer iterCount;
    integer pipeDiv;
    integer preStages;
    begin
        if (phaseFracBits == 0) begin
            fracBits = outputWidth - 3;
        end else begin
            fracBits = phaseFracBits;
        end
        if (iterations == 0) begin
            if ((fracBits + 3) < 48) begin
                iterCount = fracBits + 3;
            end else begin
                iterCount = 48;
            end
        end else begin
            iterCount = iterations;
        end
        if (pipelineMode == 2) begin
            pipeDiv = 1;
        end else if (pipelineMode == 1) begin
            pipeDiv = 2;
        end else begin
            pipeDiv = iterCount;
        end
        if (preNormalize != 0) begin
            preStages = 3;
        end else begin
            preStages = 1;
        end
        if (architecture != 0) begin
            // pre-stages + ceil(N / PIPE_DIV) iteration registers + output register
            cordicArctanLatency = preStages + ((iterCount + pipeDiv - 1) / pipeDiv) + 1;
        end else begin
            // pre-stages + one registered iteration per cycle + output register
            cordicArctanLatency = preStages + iterCount + 1;
        end
    end
endfunction

`endif // CORDIC_ARCTAN_VH
`undef CORDIC_ARCTAN_VH
