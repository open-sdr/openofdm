//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: rotate
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

module rotate
(
    input i_clock,
    input i_enable,
    input i_reset,

    input [15:0] i_in_i,
    input [15:0] i_in_q,
    // [-PI, PI]
    // scaled up by ATAN_LUT_SCALE_SHIFT
    input signed [15:0] i_phase,
    input i_input_strobe,

    output [`ROTATE_LUT_LEN_SHIFT-1:0] o_rot_addr,
    input [31:0] i_rot_data,

    output signed [15:0] o_out_i,
    output signed [15:0] o_out_q,
    output o_output_strobe
);
`include "common_params.v"

reg [15:0] phase_delayed;
reg [15:0] phase_abs;

reg [2:0] quadrant;
reg [2:0] quadrant_delayed;
wire [15:0] in_i_delayed;
wire [15:0] in_q_delayed;

reg [15:0] actual_phase;

wire [15:0] raw_rot_i;
wire [15:0] raw_rot_q;
(* keep = "true" *) reg [15:0] rot_i;
(* keep = "true" *) reg [15:0] rot_q;

wire mult_in_stb;

wire [31:0] p_i;
wire [31:0] p_q;

assign o_out_i = p_i[`ROTATE_LUT_SCALE_SHIFT+15:`ROTATE_LUT_SCALE_SHIFT];
assign o_out_q = p_q[`ROTATE_LUT_SCALE_SHIFT+15:`ROTATE_LUT_SCALE_SHIFT];

assign o_rot_addr = actual_phase[`ROTATE_LUT_LEN_SHIFT-1:0];
assign raw_rot_i = i_rot_data[31:16];
assign raw_rot_q = i_rot_data[15:0];


delayT #(.DATA_WIDTH(32), .DELAY(4)) in_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in({i_in_i, i_in_q}),
    .o_data_out({in_i_delayed, in_q_delayed})
);

delayT #(.DATA_WIDTH(1), .DELAY(4)) mult_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(i_input_strobe),
    .o_data_out(mult_in_stb)
);


complex_mult mult_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),
    .i_a_i(in_i_delayed),
    .i_a_q(in_q_delayed),
    .i_b_i(rot_i),
    .i_b_q(rot_q),
    .i_input_strobe(mult_in_stb),
    .o_p_i(p_i),
    .o_p_q(p_q),
    .o_output_strobe(o_output_strobe)
);


//integer i;
always @(posedge i_clock) begin
    if (i_reset) begin
        actual_phase <= 0;

        rot_i <= 0;
        rot_q <= 0;
        phase_abs <= 0;
        phase_delayed <= 0;

    end else if (i_enable) begin
        `ifdef DEBUG_PRINT
            if (i_phase > PI || i_phase < -PI) begin
                $display("[WARN] i_phase overflow: %d\n", i_phase);
            end
        `endif

        // cycle 1
        phase_abs <= i_phase[15]? ~i_phase+1: i_phase;
        phase_delayed <= i_phase;

        // cycle 2
        if (phase_abs <= PI_4) begin
            quadrant <= {phase_delayed[15], 2'b00};
            actual_phase <= phase_abs;
        end else if (phase_abs <= PI_2) begin
            quadrant <= {phase_delayed[15], 2'b01};
            actual_phase <= PI_2 - phase_abs;
        end else if (phase_abs <= PI_3_4) begin
            quadrant <= {phase_delayed[15], 2'b10};
            actual_phase <= phase_abs - PI_2;
        end else begin
            quadrant <= {phase_delayed[15], 2'b11};
            actual_phase <= PI - phase_abs;
        end

        // cycle 3
        // wait for raw_rot_i
        quadrant_delayed <= quadrant;

        // cycle 4
        case(quadrant_delayed)
            3'b000: begin
                rot_i <= raw_rot_i;
                rot_q <= raw_rot_q;
            end
            3'b001: begin
                rot_i <= raw_rot_q;
                rot_q <= raw_rot_i;
            end
            3'b010: begin
                rot_i <= ~raw_rot_q+1;
                rot_q <= raw_rot_i;
            end
            3'b011: begin
                rot_i <= ~raw_rot_i+1;
                rot_q <= raw_rot_q;
            end
            3'b100: begin
                rot_i <= raw_rot_i;
                rot_q <= ~raw_rot_q+1;
            end
            3'b101: begin
                rot_i <= raw_rot_q;
                rot_q <= ~raw_rot_i+1;
            end
            3'b110: begin
                rot_i <= ~raw_rot_q+1;
                rot_q <= ~raw_rot_i+1;
            end
            3'b111: begin
                rot_i <= ~raw_rot_i+1;
                rot_q <= ~raw_rot_q+1;
            end
        endcase
    end
end

endmodule

