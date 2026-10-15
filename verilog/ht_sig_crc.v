//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: ht_sig_crc
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

module ht_sig_crc
(
    input i_clock,
    input i_enable,
    input i_reset,

    input i_bit,
    input i_input_strobe,

    output [7:0] o_crc
);

reg [7:0] C;
genvar i;

generate
for (i = 0; i < 8; i=i+1) begin: reverse
    assign o_crc[i] = ~C[7-i];
end
endgenerate


always @(posedge i_clock) begin
    if (i_reset) begin
        C <= 8'hff;
    end else if (i_enable) begin
        if (i_input_strobe) begin
            C[0] <= i_bit ^ C[7];
            C[1] <= i_bit ^ C[7] ^ C[0];
            C[2] <= i_bit ^ C[7] ^ C[1];
            C[7:3] <= C[6:2];
        end
    end
end

endmodule

