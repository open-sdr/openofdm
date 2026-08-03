/*
* xianjun.jiao@imec.be; putaoshu@msn.com
* DELAY: 36 cycles -- this is old parameter
* The new div_gen 5.x allow the valid signal, auto delay or manual delay config
*/
//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: dot11
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
// -----------------------------------------------
// xianjun.jiao@imec.be; putaoshu@msn.com
// DELAY: 36 cycles -- this is old parameter
// The new div_gen 5.x allow the valid signal, auto delay or manual delay config
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


module divider (
    input i_clock,
    input i_reset,
    input i_enable,

    input signed [31:0] i_dividend,
    input signed [23:0] i_divisor,
    input i_input_strobe,

    output signed [31:0] o_quotient,
    output o_output_strobe
);

div_gen div_inst (
    .clk(i_clock),
    .dividend(i_dividend),
    .divisor(i_divisor),
    .input_strobe(i_input_strobe),
    .output_strobe(o_output_strobe),
    .quotient(o_quotient)
);

// // --------old one---------------
// div_gen_v3_0 div_inst (
//     .clk(i_clock),
//     .i_dividend(i_dividend),
//     .i_divisor(i_divisor),
//     .o_quotient(o_quotient)
// );

// delayT #(.DATA_WIDTH(1), .DELAY(36)) out_inst (
//     .i_clock(i_clock),
//     .i_reset(i_reset),
//     .data_in(i_input_strobe),
//     .data_out(o_output_strobe)
// );

endmodule

