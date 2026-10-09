//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: descramble
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

module descramble
(
    input i_clock,
    input i_enable,
    input i_reset,

    input i_in_bit,
    input i_input_strobe,

    output reg o_out_bit,
    output reg o_output_strobe
);

reg [6:0] state;
reg [4:0] bit_count;

reg inited;

wire feedback = state[6] ^ state[3];

always @(posedge i_clock) begin
    if (i_reset) begin
        bit_count <= 0;
        state <= 0;
        inited <= 0;
        o_out_bit <= 0;
        o_output_strobe <= 0;
    end else if (i_enable & i_input_strobe) begin
        if (!inited) begin
            state[6-bit_count] <= i_in_bit;
            if (bit_count == 6) begin
                bit_count <= 0;
                inited <= 1;
            end else begin
                bit_count <= bit_count + 1;
            end
        end else begin
            o_out_bit <= feedback ^ i_in_bit;
            o_output_strobe <= 1;
            state <= {state[5:0], feedback};
        end
    end else begin
        o_output_strobe <= 0;
    end
end

endmodule

