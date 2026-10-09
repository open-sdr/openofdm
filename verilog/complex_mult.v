//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: complex_mult
//
// Engineer: Tobias Weber
// Target Devices: Artix 7, XC7A100T
// Tool Versions: Vivado 2024.1
// Description:
// 
// Fork of the openofdm project
// https://github.com/jhshi/openofdm
// 
// Dependencies: complex_multiplier.v
// 
// Revision 1.00 - File Created
// Revision 1.01 - Xilinx cmpy 6.0 IP replaced by the open complex_multiplier.v
//                 (same 16x16 -> 32 truncating configuration, latency 3,
//                 bit- and cycle-identical, verified by tb/tb_complex_multiplier.v)
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

module complex_mult
(
    input i_clock,
    input i_enable,
    input i_reset,

    input [15:0] i_a_i,
    input [15:0] i_a_q,
    input [15:0] i_b_i,
    input [15:0] i_b_q,
    input i_input_strobe,

    output [31:0] o_p_i,
    output [31:0] o_p_q,
    output o_output_strobe
);

// Open complex multiplier (verilog/complex_multiplier.v) in the exact
// configuration of the former Xilinx cmpy 6.0 IP: 16x16 -> 32 bit (the LSB of
// the 33-bit product is removed, floor), latency 3, four DSP48E1, output
// valid = a valid AND b valid. Real = i_a_i / i_b_i, imaginary = i_a_q / i_b_q
// (the IP saw tdata = {q, i}). i_enable / i_reset were never applied to the
// IP either, so clock enable and reset are tied off here as well.
complex_multiplier #(
    .A_WIDTH       (16),
    .B_WIDTH       (16),
    .OUT_WIDTH     (32),
    .LATENCY       (3),
    .ROUND_MODE    (0),
    .MULT_TYPE     (1),
    .OPTIMIZE_GOAL (1)
) u_complex_multiplier (
    .i_clk    (i_clock),
    .i_clkEn  (1'b1),
    .i_rstN   (1'b1),
    .i_aValid (i_input_strobe),
    .i_aReal  (i_a_i),
    .i_aImag  (i_a_q),
    .i_bValid (i_input_strobe),
    .i_bReal  (i_b_i),
    .i_bImag  (i_b_q),
    .o_pValid (o_output_strobe),
    .o_pReal  (o_p_i),
    .o_pImag  (o_p_q)
);


// reg [15:0] ar;
// reg [15:0] ai;
// reg [15:0] br;
// reg [15:0] bi;

// wire [31:0] prod_i;
// wire [31:0] prod_q;

// // instantiation of complex multiplier
// wire [31:0] s_axis_a_tdata;
// assign s_axis_a_tdata = {ai,ar} ;
// wire [31:0] s_axis_b_tdata;
// assign s_axis_b_tdata = {bi, br} ;
// wire [63:0] m_axis_dout_tdata;
// assign prod_q = m_axis_dout_tdata[63:32];
// assign prod_i = m_axis_dout_tdata[31:0];
// wire m_axis_dout_tvalid ;

// assign o_output_strobe = m_axis_dout_tvalid; //output strobe valid at the beginning of new data -- simulation confirmed

// complex_multiplier mult_inst (
//   .aclk(i_clock),                                 // input wire aclk
//   .s_axis_a_tvalid(i_input_strobe),        	// input wire s_axis_a_tvalid
//   .s_axis_a_tdata(s_axis_a_tdata),         	// input wire [31 : 0] s_axis_a_tdata
//   .s_axis_b_tvalid(i_input_strobe),        	// input wire s_axis_b_tvalid
//   .s_axis_b_tdata(s_axis_b_tdata),          	// input wire [31 : 0] s_axis_b_tdata
//   .m_axis_dout_tvalid(m_axis_dout_tvalid),  	// output wire m_axis_dout_tvalid
//   .m_axis_dout_tdata(m_axis_dout_tdata)    	// output wire [63 : 0] m_axis_dout_tdata
// );

// always @(posedge i_clock) begin
//     if (i_reset) begin
//         ar <= 0;
//         ai <= 0;
//         br <= 0;
//         bi <= 0;
//         o_p_i <= 0;
//         o_p_q <= 0;
//     end else if (i_enable) begin
//         ar <= i_a_i;
//         ai <= i_a_q;
//         br <= i_b_i;
//         bi <= i_b_q;

//         o_p_i <= prod_i;
//         o_p_q <= prod_q;
//     end
// end

endmodule

