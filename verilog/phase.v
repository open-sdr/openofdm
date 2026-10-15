//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: o_phase
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

`include "common_defs.v"

module phase
#(
    parameter DATA_WIDTH = 32
)
(
    input i_clock,
    input i_reset,
    input i_enable,

    input signed [DATA_WIDTH-1:0] i_in_i,
    input signed [DATA_WIDTH-1:0] i_in_q,
    input i_input_strobe,

    // [-pi, pi) scaled up by 512
    output reg signed [15:0] o_phase,
    output o_output_strobe
);
`include "common_params.v"

reg [DATA_WIDTH-1:0] in_i_delay;
reg [DATA_WIDTH-1:0] in_q_delay;
reg [DATA_WIDTH-1:0] abs_i;
reg [DATA_WIDTH-1:0] abs_q;
reg [DATA_WIDTH-1:0] max;
reg [DATA_WIDTH-1:0] min;
wire [DATA_WIDTH-1:0] dividend;
wire [DATA_WIDTH-`ATAN_LUT_LEN_SHIFT-1:0] divisor;
assign dividend = (max > 4194304) ? min                                   : {min[DATA_WIDTH-`ATAN_LUT_LEN_SHIFT-1:0], {`ATAN_LUT_LEN_SHIFT{1'b0}}};
assign divisor  = (max > 4194304) ? max[DATA_WIDTH-1:`ATAN_LUT_LEN_SHIFT] :  max[DATA_WIDTH-`ATAN_LUT_LEN_SHIFT-1:0];

wire div_in_stb;

wire [31:0] quotient;
wire div_out_stb;

wire [`ATAN_LUT_LEN_SHIFT-1:0] atan_addr;
wire [`ATAN_LUT_SCALE_SHIFT-1:0] atan_data;

assign atan_addr = (quotient>511?511:quotient[`ATAN_LUT_LEN_SHIFT-1:0]);
wire signed [`ATAN_LUT_SCALE_SHIFT:0] _phase = {1'b0, atan_data};

reg [2:0] quadrant;
wire [2:0] quadrant_delayed;

// 1 cycle for abs
// 1 cycle for quadrant
delayT #(.DATA_WIDTH(1), .DELAY(2)) div_in_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(i_input_strobe),
    .o_data_out(div_in_stb)
);

// 1 cycle for atan_lut
// 1 cycle for quadrant_delayed
delayT #(.DATA_WIDTH(1), .DELAY(2)) output_inst  (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(div_out_stb),
    .o_data_out(o_output_strobe)
);


divider div_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .i_dividend(dividend),
    .i_divisor({{(`ATAN_LUT_LEN_SHIFT-8){1'b0}}, divisor}),
    .i_input_strobe(div_in_stb),

    .o_quotient(quotient),
    .o_output_strobe(div_out_stb)
);

delayT #(.DATA_WIDTH(3), .DELAY(37)) quadrant_inst  (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(quadrant),
    .o_data_out(quadrant_delayed)
);

atan_lut lut_inst (
    .clka(i_clock),
    .addra(atan_addr),
    .douta(atan_data)
);


always @(posedge i_clock) begin
    if (i_reset) begin
        max <= 0;
        min <= 0;
        abs_i <= 0;
        abs_q <= 0;
        in_i_delay <= 0;
        in_q_delay <= 0;
    end else if (i_enable) begin
        // 1st cycle
        abs_i <= i_in_i[DATA_WIDTH-1]? ~i_in_i+1: i_in_i;
        abs_q <= i_in_q[DATA_WIDTH-1]? ~i_in_q+1: i_in_q;
        in_i_delay <= i_in_i;
        in_q_delay <= i_in_q;

        // 2nd cycle
        if (abs_i >= abs_q) begin
            quadrant <= {in_i_delay[DATA_WIDTH-1], in_q_delay[DATA_WIDTH-1], 1'b0};
            max <= abs_i;
            min <= abs_q;
        end else begin
            quadrant <= {in_i_delay[DATA_WIDTH-1], in_q_delay[DATA_WIDTH-1], 1'b1};
            max <= abs_q;
            min <= abs_i;
        end

        case(quadrant_delayed)
            3'b000: o_phase <= _phase;            // [0, PI/4]
            3'b001: o_phase <= PI_2 - _phase;     // [PI/4, PI/2]
            3'b010: o_phase <= -_phase;           // [-PI/4, 0]
            3'b011: o_phase <= _phase - PI_2;     // [-PI/2, -Pi/4]
            3'b100: o_phase <= PI - _phase;       // [3/4PI, PI]
            3'b101: o_phase <= PI_2 + _phase;     // [PI/2, 3/4PI]
            3'b110: o_phase <= _phase - PI;       // [-3/4PI, -PI]
            3'b111: o_phase <= -PI_2 - _phase;    // [-PI/2, -3/4PI]
        endcase
    end
end

endmodule

