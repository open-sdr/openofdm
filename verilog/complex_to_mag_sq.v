//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: complex_to_mag_sq
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

module complex_to_mag_sq (
    input i_clock,
    input i_enable,
    input i_reset,

    input signed [15:0] i_i,
    input signed [15:0] i_q,
    input i_input_strobe,

    output [31:0] o_mag_sq,
    output o_mag_sq_strobe
);

reg valid_in;
reg [15:0] input_i;
reg [15:0] input_q;
reg [15:0] input_q_neg;

complex_mult mult_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),
    .i_enable(i_enable),
    
    .i_a_i(input_i),
    .i_a_q(input_q),
    .i_b_i(input_i),
    .i_b_q(input_q_neg),
    .i_input_strobe(valid_in),

    .o_p_i(o_mag_sq),
    .o_p_q(),
    .o_output_strobe(o_mag_sq_strobe)
);

always @(posedge i_clock) begin
    if (i_reset) begin
        input_i <= 0;
        input_q <= 0;
        input_q_neg <= 0;
        valid_in <= 0;
    end else if (i_enable) begin
        valid_in <= i_input_strobe;
        input_i <= i_i;
        input_q <= i_q;
        input_q_neg <= ~i_q+1;
    end
end
endmodule

