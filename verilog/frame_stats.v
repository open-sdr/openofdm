//////////////////////////////////////////////////////////////////////////////////
//
// Project Name: RA-Sentinel
//
// Module Name: frame_stats
//
// Engineer: Tobias Weber
// Target Devices: Artix 7, XC7A100T
// Tool Versions: Vivado 2025.2
// Description:
//
// Per-frame statistics of the receiver's own estimates, as raw material for
// transmitter fingerprinting (RA-Sentinel IQ snapshot descriptor v2, bytes
// 48..71, doc/iq_capture/SPEC.md). Everything here is a by-product of signals
// the receiver computes anyway; nothing feeds back into the decoding.
//
//   CPE   the equalizer's common phase error per OFDM symbol (the pilot
//         phase after the CFO correction of sync_long): sum and sum of
//         squares over the frame -> mean = residual frequency error, variance
//         = phase noise + estimation noise. Units: openofdm's phase units,
//         PI = 1608 (common_params.v), 3216 = one turn.
//   EVM   error vector of every data subcarrier of the DATA symbols against
//         the nearest point of the ideal 802.11 constellation of the frame's
//         modulation. The equalizer scales its output so that the LTF (and
//         BPSK) amplitude is A = 2^CONS_SCALE_SHIFT; the constellations are
//         unit average power on that scale: QPSK +-A/sqrt(2), 16-QAM
//         (1,3)A/sqrt(10), 64-QAM (1,3,5,7)A/sqrt(42). Sum of
//         (e_i^2 + e_q^2) / 4 and the number of subcarriers ->
//         EVM_rms = sqrt(4 * sum / count) / A, relative to the rms
//         constellation power. SIGNAL and HT-SIG symbols are excluded (they
//         are decoded with a different grid), as is whatever the equalizer
//         still emits after the frame.
//   NSYM  data symbols: a CPE is taken into the sums only when the first
//         data subcarrier of its symbol arrives (the equalizer estimates the
//         CPE of a symbol before it outputs the symbol), so the CPE sums,
//         nsym and evm_cnt all cover exactly the same symbols - SIGNAL,
//         HT-SIG and whatever the equalizer still estimates after the frame
//         are excluded. nsym = evm_cnt / 48 (52 for HT).
//
// The accumulators clear at i_frame_start (the long preamble detect of the
// frame) and are read live; the capture block latches them when it publishes
// the snapshot and flags whether the frame had ended by then. Unsigned sums
// saturate, the signed CPE sum wraps (a frame would need 2^16 symbols).
//
// Dependencies: common_defs.v (CONS_SCALE_SHIFT)
//
// Revision 1.00 - File Created
// Project: https://github.com/Tobias-DG3YEV/RA-Sentinel
//
//////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2026 Tobias Weber
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
`include "common_defs.v"
`timescale 1ns / 1ps

module frame_stats (
    input i_clock,
    input i_reset,
    input i_enable,

    input i_frame_start,                // long preamble detected: clear everything

    // equalizer: common phase error of each OFDM symbol
    input signed [15:0] i_cpe,
    input i_cpe_stb,

    // equalizer output: one data subcarrier per strobe, {I[15:0], Q[15:0]}
    input [31:0] i_eq_out,
    input i_eq_out_stb,
    input i_demod,                      // dot11 is demodulating this frame (SIGNAL .. last data symbol)
    input i_data_phase,                 // ... and is past the header: data symbols
    input [7:0] i_pkt_rate,             // bit 7 HT, [3:0] rate / MCS (as demodulate.v)

    output reg signed [31:0] o_cpe_sum,
    output reg [31:0] o_cpe_sq_sum,
    output reg [31:0] o_evm_sum,
    output reg [15:0] o_evm_cnt,
    output reg [15:0] o_nsym
);

localparam MAX = 1 << `CONS_SCALE_SHIFT;      // LTF / BPSK amplitude A
localparam [1:0] BPSK = 2'd0, QPSK = 2'd1, QAM_16 = 2'd2, QAM_64 = 2'd3;
// ideal 802.11 constellation levels on that scale (unit average power) and
// the decision thresholds halfway between them
localparam QPSK_L   = (MAX * 7071 + 5000) / 10000;    // A / sqrt(2)      724
localparam Q16_L1   = (MAX * 3162 + 5000) / 10000;    // A / sqrt(10)     324
localparam Q16_L3   = (MAX * 9487 + 5000) / 10000;    // 3A / sqrt(10)    971
localparam Q16_T    = (MAX * 6325 + 5000) / 10000;    // 2A / sqrt(10)    648
localparam Q64_L1   = (MAX * 1543 + 5000) / 10000;    // A / sqrt(42)     158
localparam Q64_L3   = (MAX * 4629 + 5000) / 10000;    // 3A / sqrt(42)    474
localparam Q64_L5   = (MAX * 7715 + 5000) / 10000;    // 5A / sqrt(42)    790
localparam Q64_L7   = (MAX * 10801 + 5000) / 10000;   // 7A / sqrt(42)   1106
localparam Q64_T1   = (MAX * 3086 + 5000) / 10000;    // 2A / sqrt(42)    316
localparam Q64_T2   = (MAX * 6172 + 5000) / 10000;    // 4A / sqrt(42)    632
localparam Q64_T3   = (MAX * 9258 + 5000) / 10000;    // 6A / sqrt(42)    948

// modulation of the frame (same table as demodulate.v)
reg [1:0] mod;
always @(*) begin
    case ({i_pkt_rate[7], i_pkt_rate[3:0]})
        5'b01011, 5'b01111: mod = BPSK;
        5'b01010, 5'b01110: mod = QPSK;
        5'b01001, 5'b01101: mod = QAM_16;
        5'b01000, 5'b01100: mod = QAM_64;
        5'b10000:           mod = BPSK;
        5'b10001, 5'b10010: mod = QPSK;
        5'b10011, 5'b10100: mod = QAM_16;
        5'b10101, 5'b10110, 5'b10111: mod = QAM_64;
        default:            mod = BPSK;
    endcase
end

// nearest constellation level on one axis
function signed [15:0] nearest;
    input signed [15:0] x;
    input [1:0] m;
    reg [15:0] a;
    reg signed [15:0] lvl;
    begin
        a = x[15] ? (~x + 1'b1) : x;        // |x|
        case (m)
            QPSK:   lvl = QPSK_L;
            QAM_16: lvl = (a < Q16_T) ? Q16_L1 : Q16_L3;
            QAM_64: lvl = (a < Q64_T1) ? Q64_L1 :
                          (a < Q64_T2) ? Q64_L3 :
                          (a < Q64_T3) ? Q64_L5 : Q64_L7;
            default: lvl = MAX;             // BPSK
        endcase
        nearest = x[15] ? -lvl : lvl;
    end
endfunction

// stage 1: error vector of the subcarrier
wire signed [15:0] eq_i = i_eq_out[31:16];
wire signed [15:0] eq_q = i_eq_out[15:0];
wire signed [15:0] ref_i = nearest(eq_i, mod);
wire signed [15:0] ref_q = (mod == BPSK) ? 16'sd0 : nearest(eq_q, mod);
reg signed [16:0] err_i, err_q;
reg               err_stb;
// stage 2: squared magnitude / 4
reg [33:0] err_sq;
reg        sq_stb;
wire [31:0] err_sq_q = err_sq[33:2];

wire [32:0] evm_next = {1'b0, o_evm_sum} + {1'b0, err_sq_q};
// the CPE of the symbol being output, committed with its first data subcarrier
reg                cpe_pending;
reg  signed [15:0] cpe_pend;
reg                sym_open;                            // inside a symbol's data output
wire signed [31:0] cpe_ext = {{16{cpe_pend[15]}}, cpe_pend};
wire [31:0] cpe_sq = cpe_pend * cpe_pend;               // < 2^31 for |cpe| < 2^15
wire [32:0] cpe_sq_next = {1'b0, o_cpe_sq_sum} + {1'b0, cpe_sq};

always @(posedge i_clock) begin
    if (i_reset) begin
        err_i <= 0; err_q <= 0; err_stb <= 0; err_sq <= 0; sq_stb <= 0;
        cpe_pending <= 0; cpe_pend <= 0; sym_open <= 0;
        o_cpe_sum <= 0; o_cpe_sq_sum <= 0; o_evm_sum <= 0; o_evm_cnt <= 0; o_nsym <= 0;
    end else if (i_enable) begin
        // EVM pipeline
        err_stb <= i_eq_out_stb & i_demod & i_data_phase;
        err_i   <= {eq_i[15], eq_i} - {ref_i[15], ref_i};
        err_q   <= {eq_q[15], eq_q} - {ref_q[15], ref_q};
        sq_stb  <= err_stb;
        err_sq  <= err_i * err_i + err_q * err_q;

        if (i_frame_start) begin
            o_cpe_sum <= 0; o_cpe_sq_sum <= 0; o_evm_sum <= 0; o_evm_cnt <= 0; o_nsym <= 0;
            cpe_pending <= 0; sym_open <= 0;
        end else begin
            // a new CPE estimate: the symbol it belongs to has not been output yet
            if (i_cpe_stb && i_demod) begin
                cpe_pend <= i_cpe; cpe_pending <= 1'b1; sym_open <= 1'b0;
            end
            if (sq_stb) begin
                o_evm_sum <= evm_next[32] ? 32'hFFFFFFFF : evm_next[31:0];
                if (o_evm_cnt != 16'hFFFF) o_evm_cnt <= o_evm_cnt + 16'd1;
                // first data subcarrier of the symbol: commit its CPE
                if (cpe_pending && !sym_open) begin
                    o_cpe_sum    <= o_cpe_sum + cpe_ext;
                    o_cpe_sq_sum <= cpe_sq_next[32] ? 32'hFFFFFFFF : cpe_sq_next[31:0];
                    if (o_nsym != 16'hFFFF) o_nsym <= o_nsym + 16'd1;
                    cpe_pending <= 1'b0;
                end
                sym_open <= 1'b1;
            end
        end
    end
end

endmodule
