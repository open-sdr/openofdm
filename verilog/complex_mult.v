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
// Dependencies: 
// 
// Revision 1.00 - File Created
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

wire [63:0] m_axis_dout_tdata;
assign o_p_q = m_axis_dout_tdata[63:32];
assign o_p_i = m_axis_dout_tdata[31:0];
complex_multiplier mult_inst (
  .aclk(i_clock),                                 // input wire aclk
  .s_axis_a_tvalid(i_input_strobe),        	// input wire s_axis_a_tvalid
  .s_axis_a_tdata({i_a_q, i_a_i}),         	// input wire [31 : 0] s_axis_a_tdata
  .s_axis_b_tvalid(i_input_strobe),        	// input wire s_axis_b_tvalid
  .s_axis_b_tdata({i_b_q, i_b_i}),          	// input wire [31 : 0] s_axis_b_tdata
  .m_axis_dout_tvalid(o_output_strobe),  	// output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(m_axis_dout_tdata)    	// output wire [63 : 0] m_axis_dout_tdata
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

