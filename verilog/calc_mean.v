//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: calc_mean
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
// master_clk
// You should have received i_a copy of the GNU Lesser General Public License
// along with this program. If not, see
// <http://www.gnu.org/licenses/> for i_a copy.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module calc_mean
(
    input i_clock,
    input i_enable,
    input i_reset,

    input signed [15:0] i_a,
    input signed [15:0] i_b,
    input i_sign,
    input i_input_strobe,

    output reg signed [15:0] o_c,
    output reg o_output_strobe
);

reg signed [15:0] aa;
reg signed [15:0] bb;
reg signed [15:0] cc;

reg [1:0] delay;
reg [1:0] sign_stage;

always @(posedge i_clock) begin
    if (i_reset) begin
        aa <= 0;
        bb <= 0;
        cc <= 0;
        o_c <= 0;
        o_output_strobe <= 0;
        delay <= 0;
    end else if (i_enable) begin
        delay[0] <= i_input_strobe;
        delay[1] <= delay[0];
        o_output_strobe <= delay[1];
        sign_stage[1] <= sign_stage[0];
        sign_stage[0] <= i_sign;

        aa <= i_a>>>1;
        bb <= i_b>>>1;
        cc <= aa + bb;
        o_c <= sign_stage[1]? ~cc+1: cc;
    end
end

endmodule


