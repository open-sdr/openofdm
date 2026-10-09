//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: bits_to_bytes
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

module bits_to_bytes
(
    input i_clock,
    input i_enable,
    input i_reset,

    input i_bit_in,
    input i_input_strobe,

    output reg [7:0] o_byte_out,
    output reg o_output_strobe
);

reg [7:0] bit_buf;
reg [2:0] addr;

always @(posedge i_clock) begin
    if (i_reset) begin
        addr <= 0;
        bit_buf <= 0;
        o_byte_out <= 0;
        o_output_strobe <= 0;
    end else if (i_enable & i_input_strobe) begin
        bit_buf[7] <= i_bit_in;
        bit_buf[6:0] <= bit_buf[7:1];
        addr <= addr + 1;
        if (addr == 7) begin
            o_byte_out <= {i_bit_in, bit_buf[7:1]};
            o_output_strobe <= 1;
        end else begin
            o_output_strobe <= 0;
        end
    end else begin
        o_output_strobe <= 0;
    end
end
endmodule

