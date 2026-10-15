//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: delayT
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


module delayT
#(
    parameter DATA_WIDTH = 32,
    parameter DELAY = 1
)
(
    input i_clock,
    input i_reset,

    input [DATA_WIDTH-1:0] i_data_in,
    output [DATA_WIDTH-1:0] o_data_out
);

reg [DATA_WIDTH-1:0] ram[DELAY-1:0];
integer i;

assign o_data_out = ram[DELAY-1];

always @(posedge i_clock) begin
    if (i_reset) begin
        for (i = 0; i < DELAY; i = i+1) begin
            ram[i] <= 0;
        end
    end else begin
        ram[0] <= i_data_in;
        for (i = 1; i < DELAY; i= i+1) begin
            ram[i] <= ram[i-1];
        end
    end
end

endmodule

