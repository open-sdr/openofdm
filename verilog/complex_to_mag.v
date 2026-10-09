//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: complex_to_mag
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

module complex_to_mag
#(
    parameter DATA_WIDTH = 16
)
(
    input i_clock,
    input i_enable,
    input i_reset,

    input signed [DATA_WIDTH-1:0] i_i,
    input signed [DATA_WIDTH-1:0] i_q,
    input i_input_strobe,

    output reg [DATA_WIDTH-1:0] o_mag,
    output reg o_mag_stb
);

reg [DATA_WIDTH-1:0] abs_i;
reg [DATA_WIDTH-1:0] abs_q;

reg [DATA_WIDTH-1:0] max;
reg[ DATA_WIDTH-1:0] min;

reg input_strobe_reg0;
reg input_strobe_reg1;

// delayT #(.DATA_WIDTH(1), .DELAY(3)) stb_delay_inst (
//     .i_clock(i_clock),
//     .i_reset(i_reset),

//     .data_in(i_input_strobe),
//     .data_out(o_mag_stb)
// );


// http://dspguru.com/dsp/tricks/magnitude-estimator
// alpha = 1, beta = 1/4
// avg err 0.006
always @(posedge i_clock) begin
    if (i_reset) begin
        o_mag <= 0;
        abs_i <= 0;
        abs_q <= 0;
        max <= 0;
        min <= 0;
        input_strobe_reg0 <= 0;
        input_strobe_reg1 <= 0;
    end else if (i_enable) begin
        abs_i <= i_i[DATA_WIDTH-1]? (~i_i+1): i_i;
        abs_q <= i_q[DATA_WIDTH-1]? (~i_q+1): i_q;

        max <= abs_i > abs_q? abs_i: abs_q;
        min <= abs_i > abs_q? abs_q: abs_i;

        o_mag <= max + (min>>2);

        input_strobe_reg0 <= i_input_strobe;
        input_strobe_reg1 <= input_strobe_reg0;
        o_mag_stb           <= input_strobe_reg1;
    end
end

endmodule

