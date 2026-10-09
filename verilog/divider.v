//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: dot11
//
// Engineer: Tobias Weber, original Version from xianjun.jiao@imec.be; putaoshu@msn.com
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

// Open signed divider (openCDIV's signed_divider.v) in the exact
// configuration of the former Xilinx div_gen 5.1 IP + div_gen_xlslice:
// 32 / 24 bit signed, quotient rounded toward zero (the IP's fractional part
// was sliced off and is not produced), one division per clock, latency 36,
// output strobe = input strobe delayed by 36. i_enable / i_reset were never
// applied to the IP either, so clock enable and reset are tied off here as
// well.

signed_divider #(
    .DIVIDEND_WIDTH (32),
    .DIVISOR_WIDTH  (24),
    .LATENCY        (36)
) div_inst (
    .i_clk           (i_clock),
    .i_clkEn         (1'b1),
    .i_rstN          (1'b1),
    .i_dividendValid (i_input_strobe),
    .i_dividend      (i_dividend),
    .i_divisorValid  (i_input_strobe),
    .i_divisor       (i_divisor),
    .o_quotientValid (o_output_strobe),
    .o_quotient      (o_quotient)
);

endmodule

