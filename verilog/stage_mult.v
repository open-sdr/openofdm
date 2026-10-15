//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: stage_mult
//
// Engineer: Tobias Weber
// Target Devices: Artix 7, XC7A100T
// Tool Versions: Vivado 2024.1
// Description:
// 
// Fork of the openofdm project
// https://github.com/jhshi/openofdm
// 
// Dependencies: complex_multiplier.v, delayT.v
// 
// Revision 1.00 - File Created
// Revision 1.01 - the eight Xilinx cmpy 6.0 IP instances replaced by the open
//                 complex_multiplier.v (same 16x16 -> 32 truncating configuration,
//                 latency 3, bit- and cycle-identical; output_strobe unchanged)
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

module stage_mult
(
    input i_clock,
    input i_enable,
    input i_reset,

    input signed [31:0] X0,
    input signed [31:0] X1,
    input signed [31:0] X2,
    input signed [31:0] X3,
    input signed [31:0] X4,
    input signed [31:0] X5,
    input signed [31:0] X6,
    input signed [31:0] X7,

    input signed [31:0] Y0,
    input signed [31:0] Y1,
    input signed [31:0] Y2,
    input signed [31:0] Y3,
    input signed [31:0] Y4,
    input signed [31:0] Y5,
    input signed [31:0] Y6,
    input signed [31:0] Y7,

    input input_strobe,

    output reg [63:0] sum,
    output output_strobe
);

wire signed [15:0] X0_q = X0[31:16];
wire signed [15:0] X0_i = X0[15:0];
wire signed [15:0] X1_q = X1[31:16];
wire signed [15:0] X1_i = X1[15:0];
wire signed [15:0] X2_q = X2[31:16];
wire signed [15:0] X2_i = X2[15:0];
wire signed [15:0] X3_q = X3[31:16];
wire signed [15:0] X3_i = X3[15:0];
wire signed [15:0] X4_q = X4[31:16];
wire signed [15:0] X4_i = X4[15:0];
wire signed [15:0] X5_q = X5[31:16];
wire signed [15:0] X5_i = X5[15:0];
wire signed [15:0] X6_q = X6[31:16];
wire signed [15:0] X6_i = X6[15:0];
wire signed [15:0] X7_q = X7[31:16];
wire signed [15:0] X7_i = X7[15:0];

wire signed [15:0] Y0_q = Y0[31:16];
wire signed [15:0] Y0_i = Y0[15:0];
wire signed [15:0] Y1_q = Y1[31:16];
wire signed [15:0] Y1_i = Y1[15:0];
wire signed [15:0] Y2_q = Y2[31:16];
wire signed [15:0] Y2_i = Y2[15:0];
wire signed [15:0] Y3_q = Y3[31:16];
wire signed [15:0] Y3_i = Y3[15:0];
wire signed [15:0] Y4_q = Y4[31:16];
wire signed [15:0] Y4_i = Y4[15:0];
wire signed [15:0] Y5_q = Y5[31:16];
wire signed [15:0] Y5_i = Y5[15:0];
wire signed [15:0] Y6_q = Y6[31:16];
wire signed [15:0] Y6_i = Y6[15:0];
wire signed [15:0] Y7_q = Y7[31:16];
wire signed [15:0] Y7_i = Y7[15:0];

wire signed [31:0] prod_0_i;
wire signed [31:0] prod_0_q;
wire signed [31:0] prod_1_i;
wire signed [31:0] prod_1_q;
wire signed [31:0] prod_2_i;
wire signed [31:0] prod_2_q;
wire signed [31:0] prod_3_i;
wire signed [31:0] prod_3_q;
wire signed [31:0] prod_4_i;
wire signed [31:0] prod_4_q;
wire signed [31:0] prod_5_i;
wire signed [31:0] prod_5_q;
wire signed [31:0] prod_6_i;
wire signed [31:0] prod_6_q;
wire signed [31:0] prod_7_i;
wire signed [31:0] prod_7_q;

// Open complex multiplier (verilog/complex_multiplier.v) in the exact
// configuration of the former Xilinx cmpy 6.0 IP (16x16 -> 32 bit, LSB of the
// 33-bit product removed, latency 3, four DSP48E1 each). The IP was fed
// tdata = {Xn_i, Xn_q}, i.e. tdata[15:0] = Xn_q was its REAL input and
// tdata[31:16] = Xn_i its IMAGINARY input, and it returned
// {prod_n_q, prod_n_i} = {imaginary, real}. That mapping is kept exactly:
// real <- Xn_q / Yn_q, imaginary <- Xn_i / Yn_i, prod_n_i <- real product,
// prod_n_q <- imaginary product. Clock enable and reset are tied off like the
// IP had none; output_strobe still comes from the delayT below.

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_0 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X0_q),
    .i_aImag  (X0_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y0_q),
    .i_bImag  (Y0_i),
    .o_pValid (),
    .o_pReal  (prod_0_i),
    .o_pImag  (prod_0_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_1 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X1_q),
    .i_aImag  (X1_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y1_q),
    .i_bImag  (Y1_i),
    .o_pValid (),
    .o_pReal  (prod_1_i),
    .o_pImag  (prod_1_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_2 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X2_q),
    .i_aImag  (X2_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y2_q),
    .i_bImag  (Y2_i),
    .o_pValid (),
    .o_pReal  (prod_2_i),
    .o_pImag  (prod_2_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_3 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X3_q),
    .i_aImag  (X3_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y3_q),
    .i_bImag  (Y3_i),
    .o_pValid (),
    .o_pReal  (prod_3_i),
    .o_pImag  (prod_3_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_4 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X4_q),
    .i_aImag  (X4_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y4_q),
    .i_bImag  (Y4_i),
    .o_pValid (),
    .o_pReal  (prod_4_i),
    .o_pImag  (prod_4_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_5 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X5_q),
    .i_aImag  (X5_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y5_q),
    .i_bImag  (Y5_i),
    .o_pValid (),
    .o_pReal  (prod_5_i),
    .o_pImag  (prod_5_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_6 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X6_q),
    .i_aImag  (X6_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y6_q),
    .i_bImag  (Y6_i),
    .o_pValid (),
    .o_pReal  (prod_6_i),
    .o_pImag  (prod_6_q)
);

complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier_7 (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (input_strobe),
    .i_aReal  (X7_q),
    .i_aImag  (X7_i),
    .i_bValid (input_strobe),
    .i_bReal  (Y7_q),
    .i_bImag  (Y7_i),
    .o_pValid (),
    .o_pReal  (prod_7_i),
    .o_pImag  (prod_7_q)
);

reg signed [31:0] sum_i1;
reg signed [31:0] sum_i2;
reg signed [31:0] sum_i3;
reg signed [31:0] sum_i4;
reg signed [31:0] sum_q1;
reg signed [31:0] sum_q2;
reg signed [31:0] sum_q3;
reg signed [31:0] sum_q4;

delayT #(.DATA_WIDTH(1), .DELAY(5)) sum_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(input_strobe),
    .o_data_out(output_strobe)
);

always @(posedge i_clock) begin
    if (i_reset) begin
        sum <= 0;
        sum_i1 <= 0;
        sum_i2 <= 0;
        sum_i3 <= 0;
        sum_i4 <= 0;
        sum_q1 <= 0;
        sum_q2 <= 0;
        sum_q3 <= 0;
        sum_q4 <= 0;
    end else if (i_enable) begin
        sum_i1 <= prod_0_i + prod_1_i;
        sum_i2 <= prod_2_i + prod_3_i;
        sum_i3 <= prod_4_i + prod_5_i;
        sum_i4 <= prod_6_i + prod_7_i;
        sum_q1 <= prod_0_q + prod_1_q;
        sum_q2 <= prod_2_q + prod_3_q;
        sum_q3 <= prod_4_q + prod_5_q;
        sum_q4 <= prod_6_q + prod_7_q;

        sum[63:32] <= sum_i1 + sum_i2 + sum_i3 + sum_i4;
        sum[31:0]  <= sum_q1 + sum_q2 + sum_q3 + sum_q4;
    end
end

endmodule

