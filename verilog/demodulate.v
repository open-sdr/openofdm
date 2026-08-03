//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: demodulate
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

module demodulate (
    input i_clock,
    input i_enable,
    input i_reset,

    input [7:0] i_rate,
    input [15:0] i_cons_i,
    input [15:0] i_cons_q,
    input i_input_strobe,

    output reg [5:0] o_bits,
    output reg [5:0] o_soft_bits,
    output reg [3:0] o_soft_bits_pos,
    output o_output_strobe
);

localparam MAX = 1<<`CONS_SCALE_SHIFT;

localparam QAM_16_DIV = MAX*2/3;

localparam QAM_64_DIV_0 = MAX*2/7;
localparam QAM_64_DIV_1 = MAX*4/7;
localparam QAM_64_DIV_2 = MAX*6/7;

localparam BPSK_SOFT_4  = MAX;
localparam BPSK_SOFT_3  = MAX*3/4;
localparam BPSK_SOFT_2  = MAX*2/4;
localparam BPSK_SOFT_1  = MAX*1/4;
localparam BPSK_SOFT_0  = 0;

localparam QPSK_SOFT_4  = MAX;
localparam QPSK_SOFT_3  = MAX*3/4;
localparam QPSK_SOFT_2  = MAX*2/4;
localparam QPSK_SOFT_1  = MAX*1/4;
localparam QPSK_SOFT_0  = 0;

localparam QAM_16_SOFT_12 = MAX;
localparam QAM_16_SOFT_11 = MAX*11/12;
localparam QAM_16_SOFT_10 = MAX*10/12;
localparam QAM_16_SOFT_9  = MAX*9/12;
localparam QAM_16_SOFT_8  = MAX*8/12;
localparam QAM_16_SOFT_7  = MAX*7/12;
localparam QAM_16_SOFT_6  = MAX*6/12;
localparam QAM_16_SOFT_5  = MAX*5/12;
localparam QAM_16_SOFT_4  = MAX*4/12;
localparam QAM_16_SOFT_3  = MAX*3/12;
localparam QAM_16_SOFT_2  = MAX*2/12;
localparam QAM_16_SOFT_1  = MAX*1/12;
localparam QAM_16_SOFT_0  = 0;

localparam QAM_64_SOFT_28 = MAX;
localparam QAM_64_SOFT_27 = MAX*27/28;
localparam QAM_64_SOFT_26 = MAX*26/28;
localparam QAM_64_SOFT_25 = MAX*25/28;
localparam QAM_64_SOFT_24 = MAX*24/28;
localparam QAM_64_SOFT_23 = MAX*23/28;
localparam QAM_64_SOFT_22 = MAX*22/28;
localparam QAM_64_SOFT_21 = MAX*21/28;
localparam QAM_64_SOFT_20 = MAX*20/28;
localparam QAM_64_SOFT_19 = MAX*19/28;
localparam QAM_64_SOFT_18 = MAX*18/28;
localparam QAM_64_SOFT_17 = MAX*17/28;
localparam QAM_64_SOFT_16 = MAX*16/28;
localparam QAM_64_SOFT_15 = MAX*15/28;
localparam QAM_64_SOFT_14 = MAX*14/28;
localparam QAM_64_SOFT_13 = MAX*13/28;
localparam QAM_64_SOFT_12 = MAX*12/28;
localparam QAM_64_SOFT_11 = MAX*11/28;
localparam QAM_64_SOFT_10 = MAX*10/28;
localparam QAM_64_SOFT_9  = MAX*9/28;
localparam QAM_64_SOFT_8  = MAX*8/28;
localparam QAM_64_SOFT_7  = MAX*7/28;
localparam QAM_64_SOFT_6  = MAX*6/28;
localparam QAM_64_SOFT_5  = MAX*5/28;
localparam QAM_64_SOFT_4  = MAX*4/28;
localparam QAM_64_SOFT_3  = MAX*3/28;
localparam QAM_64_SOFT_2  = MAX*2/28;
localparam QAM_64_SOFT_1  = MAX*1/28;
localparam QAM_64_SOFT_0  = 0;

localparam BPSK = 1;
localparam QPSK = 2;
localparam QAM_16 = 3;
localparam QAM_64 = 4;

reg [15:0] cons_i_delayed;
reg [15:0] cons_q_delayed;
reg [15:0] abs_cons_i;
reg [15:0] abs_cons_q;

reg [2:0] mod;


delayT #(.DATA_WIDTH(1), .DELAY(2)) stb_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(i_input_strobe),
    .o_data_out(o_output_strobe)
);


always @(posedge i_clock) begin
    if (i_reset) begin
        o_bits <= 0;
        o_soft_bits <= 0;
        o_soft_bits_pos <= 4'b1111;
        abs_cons_i <= 0;
        abs_cons_q <= 0;
        cons_i_delayed <= 0;
        cons_q_delayed <= 0;
        mod <= 0;
    end else if (i_enable) begin
        abs_cons_i <= i_cons_i[15]? ~i_cons_i+1: i_cons_i;
        abs_cons_q <= i_cons_q[15]? ~i_cons_q+1: i_cons_q;
        cons_i_delayed <= i_cons_i;
        cons_q_delayed <= i_cons_q;

        case({i_rate[7], i_rate[3:0]})
            // 802.11a rates
            5'b01011: begin mod <= BPSK;    end
            5'b01111: begin mod <= BPSK;    end
            5'b01010: begin mod <= QPSK;    end
            5'b01110: begin mod <= QPSK;    end
            5'b01001: begin mod <= QAM_16;  end
            5'b01101: begin mod <= QAM_16;  end
            5'b01000: begin mod <= QAM_64;  end
            5'b01100: begin mod <= QAM_64;  end

            // 802.11n rates
            5'b10000: begin mod <= BPSK;    end
            5'b10001: begin mod <= QPSK;    end
            5'b10010: begin mod <= QPSK;    end
            5'b10011: begin mod <= QAM_16;  end
            5'b10100: begin mod <= QAM_16;  end
            5'b10101: begin mod <= QAM_64;  end
            5'b10110: begin mod <= QAM_64;  end
            5'b10111: begin mod <= QAM_64;  end

            default: begin mod <= BPSK; end
        endcase

        case(mod)
            BPSK: begin
                // Hard decoded o_bits
                o_bits[0] <= ~cons_i_delayed[15];
                o_bits[5:1] <= 0;

                // Inphase soft decoded o_bits
                if(cons_i_delayed[15] == 0 && abs_cons_i >= BPSK_SOFT_3)
                    o_soft_bits[2:0] <= 3'b111;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_3 && abs_cons_i >= BPSK_SOFT_2)
                    o_soft_bits[2:0] <= 3'b110;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_2 && abs_cons_i >= BPSK_SOFT_1)
                    o_soft_bits[2:0] <= 3'b101;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_1 && abs_cons_i >= BPSK_SOFT_0)
                    o_soft_bits[2:0] <= 3'b100;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_1 && abs_cons_i >= BPSK_SOFT_0)
                    o_soft_bits[2:0] <= 3'b000;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_2 && abs_cons_i >= BPSK_SOFT_1)
                    o_soft_bits[2:0] <= 3'b001;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_3 && abs_cons_i >= BPSK_SOFT_2)
                    o_soft_bits[2:0] <= 3'b010;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_4 && abs_cons_i >= BPSK_SOFT_3)
                    o_soft_bits[2:0] <= 3'b011;
                //
                else
                    o_soft_bits[2:0] <= 3'b011;

                // Quadrature soft decoded o_bits
                o_soft_bits[5:3] <= 3'b000;

                // Inphase soft decoded bit positions
                if(abs_cons_i < BPSK_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b00;
                else
                    o_soft_bits_pos[1:0] <= 2'b11;

                // Quadrature soft decoded bit positions
                o_soft_bits_pos[3:2] <= 2'b11;
            end
            QPSK: begin
                // Hard decoded o_bits
                o_bits[0] <= ~cons_i_delayed[15];
                o_bits[1] <= ~cons_q_delayed[15];
                o_bits[5:2] <= 0;

                // Inphase soft decoded o_bits
                if(cons_i_delayed[15] == 0 && abs_cons_i >= QPSK_SOFT_3)
                    o_soft_bits[2:0] <= 3'b111;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_3 && abs_cons_i >= QPSK_SOFT_2)
                    o_soft_bits[2:0] <= 3'b110;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_2 && abs_cons_i >= QPSK_SOFT_1)
                    o_soft_bits[2:0] <= 3'b101;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_1 && abs_cons_i >= QPSK_SOFT_0)
                    o_soft_bits[2:0] <= 3'b100;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_1 && abs_cons_i >= QPSK_SOFT_0)
                    o_soft_bits[2:0] <= 3'b000;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_2 && abs_cons_i >= QPSK_SOFT_1)
                    o_soft_bits[2:0] <= 3'b001;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_3 && abs_cons_i >= QPSK_SOFT_2)
                    o_soft_bits[2:0] <= 3'b010;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_4 && abs_cons_i >= QPSK_SOFT_3)
                    o_soft_bits[2:0] <= 3'b011;
                //
                else
                    o_soft_bits[2:0] <= 3'b011;

                // Quadrature soft decoded o_bits
                if(cons_q_delayed[15] == 0 && abs_cons_q >= QPSK_SOFT_3)
                    o_soft_bits[5:3] <= 3'b111;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_3 && abs_cons_q >= QPSK_SOFT_2)
                    o_soft_bits[5:3] <= 3'b110;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_2 && abs_cons_q >= QPSK_SOFT_1)
                    o_soft_bits[5:3] <= 3'b101;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_1 && abs_cons_q >= QPSK_SOFT_0)
                    o_soft_bits[5:3] <= 3'b100;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_1 && abs_cons_q >= QPSK_SOFT_0)
                    o_soft_bits[5:3] <= 3'b000;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_2 && abs_cons_q >= QPSK_SOFT_1)
                    o_soft_bits[5:3] <= 3'b001;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_3 && abs_cons_q >= QPSK_SOFT_2)
                    o_soft_bits[5:3] <= 3'b010;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_4 && abs_cons_q >= QPSK_SOFT_3)
                    o_soft_bits[5:3] <= 3'b011;
                //
                else
                    o_soft_bits[5:3] <= 3'b011;

                // Inphase soft decoded bit positions
                if(abs_cons_i < QPSK_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b00;
                else
                    o_soft_bits_pos[1:0] <= 2'b11;

                // Quadrature soft decoded bit positions
                if(abs_cons_q < QPSK_SOFT_4)
                    o_soft_bits_pos[3:2] <= 2'b00;
                else
                    o_soft_bits_pos[3:2] <= 2'b11;
            end
            QAM_16: begin
                // Hard decoded o_bits
                o_bits[0] <= ~cons_i_delayed[15];
                o_bits[1] <= abs_cons_i < QAM_16_DIV? 1: 0;
                o_bits[2] <= ~cons_q_delayed[15];
                o_bits[3] <= abs_cons_q < QAM_16_DIV? 1: 0;
                o_bits[5:4] <= 0;

                // Inphase soft decoded o_bits
                if(abs_cons_i < QAM_16_SOFT_12 && abs_cons_i >= QAM_16_SOFT_11)
                    o_soft_bits[2:0] <= 3'b011;
                else if(abs_cons_i < QAM_16_SOFT_11 && abs_cons_i >= QAM_16_SOFT_10)
                    o_soft_bits[2:0] <= 3'b010;
                else if(abs_cons_i < QAM_16_SOFT_10 && abs_cons_i >= QAM_16_SOFT_9)
                    o_soft_bits[2:0] <= 3'b001;
                else if(abs_cons_i < QAM_16_SOFT_9  && abs_cons_i >= QAM_16_SOFT_8)
                    o_soft_bits[2:0] <= 3'b000;
                else if(abs_cons_i < QAM_16_SOFT_8  && abs_cons_i >= QAM_16_SOFT_7)
                    o_soft_bits[2:0] <= 3'b100;
                else if(abs_cons_i < QAM_16_SOFT_7  && abs_cons_i >= QAM_16_SOFT_6)
                    o_soft_bits[2:0] <= 3'b101;
                else if(abs_cons_i < QAM_16_SOFT_6  && abs_cons_i >= QAM_16_SOFT_5)
                    o_soft_bits[2:0] <= 3'b110;
                else if(abs_cons_i < QAM_16_SOFT_5  && abs_cons_i >= QAM_16_SOFT_4)
                    o_soft_bits[2:0] <= 3'b111;
                //
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_4 && abs_cons_i >= QAM_16_SOFT_3)
                    o_soft_bits[2:0] <= 3'b111;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_3 && abs_cons_i >= QAM_16_SOFT_2)
                    o_soft_bits[2:0] <= 3'b110;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_2 && abs_cons_i >= QAM_16_SOFT_1)
                    o_soft_bits[2:0] <= 3'b101;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_1 && abs_cons_i >= QAM_16_SOFT_0)
                    o_soft_bits[2:0] <= 3'b100;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_1 && abs_cons_i >= QAM_16_SOFT_0)
                    o_soft_bits[2:0] <= 3'b000;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_2 && abs_cons_i >= QAM_16_SOFT_1)
                    o_soft_bits[2:0] <= 3'b001;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_3 && abs_cons_i >= QAM_16_SOFT_2)
                    o_soft_bits[2:0] <= 3'b010;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_4 && abs_cons_i >= QAM_16_SOFT_3)
                    o_soft_bits[2:0] <= 3'b011;
                //
                else
                    o_soft_bits[2:0] <= 3'b011;

                // Quadrature soft decoded o_bits
                if(abs_cons_q < QAM_16_SOFT_12 && abs_cons_q >= QAM_16_SOFT_11)
                    o_soft_bits[5:3] <= 3'b011;
                else if(abs_cons_q < QAM_16_SOFT_11 && abs_cons_q >= QAM_16_SOFT_10)
                    o_soft_bits[5:3] <= 3'b010;
                else if(abs_cons_q < QAM_16_SOFT_10 && abs_cons_q >= QAM_16_SOFT_9)
                    o_soft_bits[5:3] <= 3'b001;
                else if(abs_cons_q < QAM_16_SOFT_9  && abs_cons_q >= QAM_16_SOFT_8)
                    o_soft_bits[5:3] <= 3'b000;
                else if(abs_cons_q < QAM_16_SOFT_8  && abs_cons_q >= QAM_16_SOFT_7)
                    o_soft_bits[5:3] <= 3'b100;
                else if(abs_cons_q < QAM_16_SOFT_7  && abs_cons_q >= QAM_16_SOFT_6)
                    o_soft_bits[5:3] <= 3'b101;
                else if(abs_cons_q < QAM_16_SOFT_6  && abs_cons_q >= QAM_16_SOFT_5)
                    o_soft_bits[5:3] <= 3'b110;
                else if(abs_cons_q < QAM_16_SOFT_5  && abs_cons_q >= QAM_16_SOFT_4)
                    o_soft_bits[5:3] <= 3'b111;
                //
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_4 && abs_cons_q >= QAM_16_SOFT_3)
                    o_soft_bits[5:3] <= 3'b111;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_3 && abs_cons_q >= QAM_16_SOFT_2)
                    o_soft_bits[5:3] <= 3'b110;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_2 && abs_cons_q >= QAM_16_SOFT_1)
                    o_soft_bits[5:3] <= 3'b101;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_1 && abs_cons_q >= QAM_16_SOFT_0)
                    o_soft_bits[5:3] <= 3'b100;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_1 && abs_cons_q >= QAM_16_SOFT_0)
                    o_soft_bits[5:3] <= 3'b000;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_2 && abs_cons_q >= QAM_16_SOFT_1)
                    o_soft_bits[5:3] <= 3'b001;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_3 && abs_cons_q >= QAM_16_SOFT_2)
                    o_soft_bits[5:3] <= 3'b010;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_4 && abs_cons_q >= QAM_16_SOFT_3)
                    o_soft_bits[5:3] <= 3'b011;
                //
                else
                    o_soft_bits[5:3] <= 3'b011;

                // Inphase soft decoded bit positions
                if(abs_cons_i < QAM_16_SOFT_12 && abs_cons_i >= QAM_16_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b01;
                else if(abs_cons_i < QAM_16_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b00;
                else
                    o_soft_bits_pos[1:0] <= 2'b11;

                // Quadrature soft decoded bit positions
                if(abs_cons_q < QAM_16_SOFT_12 && abs_cons_q >= QAM_16_SOFT_4)
                    o_soft_bits_pos[3:2] <= 2'b01;
                else if(abs_cons_q < QAM_16_SOFT_4)
                    o_soft_bits_pos[3:2] <= 2'b00;
                else
                    o_soft_bits_pos[3:2] <= 2'b11;
            end
            QAM_64: begin
                // Hard decoded o_bits
                o_bits[0] <= ~cons_i_delayed[15];
                o_bits[1] <= abs_cons_i < QAM_64_DIV_1? 1: 0;
                o_bits[2] <= abs_cons_i > QAM_64_DIV_0 &&
                    abs_cons_i < QAM_64_DIV_2? 1: 0;
                o_bits[3] <= ~cons_q_delayed[15];
                o_bits[4] <= abs_cons_q < QAM_64_DIV_1? 1: 0;
                o_bits[5] <= abs_cons_q > QAM_64_DIV_0 &&
                    abs_cons_q < QAM_64_DIV_2? 1: 0;

                // Inphase soft decoded o_bits
                if(abs_cons_i < QAM_64_SOFT_28 && abs_cons_i >= QAM_64_SOFT_27)
                    o_soft_bits[2:0] <= 3'b011;
                else if(abs_cons_i < QAM_64_SOFT_27 && abs_cons_i >= QAM_64_SOFT_26)
                    o_soft_bits[2:0] <= 3'b010;
                else if(abs_cons_i < QAM_64_SOFT_26 && abs_cons_i >= QAM_64_SOFT_25)
                    o_soft_bits[2:0] <= 3'b001;
                else if(abs_cons_i < QAM_64_SOFT_25 && abs_cons_i >= QAM_64_SOFT_24)
                    o_soft_bits[2:0] <= 3'b000;
                else if(abs_cons_i < QAM_64_SOFT_24 && abs_cons_i >= QAM_64_SOFT_23)
                    o_soft_bits[2:0] <= 3'b100;
                else if(abs_cons_i < QAM_64_SOFT_23 && abs_cons_i >= QAM_64_SOFT_22)
                    o_soft_bits[2:0] <= 3'b101;
                else if(abs_cons_i < QAM_64_SOFT_22 && abs_cons_i >= QAM_64_SOFT_21)
                    o_soft_bits[2:0] <= 3'b110;
                else if(abs_cons_i < QAM_64_SOFT_21 && abs_cons_i >= QAM_64_SOFT_20)
                    o_soft_bits[2:0] <= 3'b111;
                // 
                else if(abs_cons_i < QAM_64_SOFT_20 && abs_cons_i >= QAM_64_SOFT_19)
                    o_soft_bits[2:0] <= 3'b010;
                else if(abs_cons_i < QAM_64_SOFT_19 && abs_cons_i >= QAM_64_SOFT_18)
                    o_soft_bits[2:0] <= 3'b010;
                else if(abs_cons_i < QAM_64_SOFT_18 && abs_cons_i >= QAM_64_SOFT_17)
                    o_soft_bits[2:0] <= 3'b001;
                else if(abs_cons_i < QAM_64_SOFT_17 && abs_cons_i >= QAM_64_SOFT_16)
                    o_soft_bits[2:0] <= 3'b000;
                else if(abs_cons_i < QAM_64_SOFT_16 && abs_cons_i >= QAM_64_SOFT_15)
                    o_soft_bits[2:0] <= 3'b100;
                else if(abs_cons_i < QAM_64_SOFT_15 && abs_cons_i >= QAM_64_SOFT_14)
                    o_soft_bits[2:0] <= 3'b101;
                else if(abs_cons_i < QAM_64_SOFT_14 && abs_cons_i >= QAM_64_SOFT_13)
                    o_soft_bits[2:0] <= 3'b110;
                else if(abs_cons_i < QAM_64_SOFT_13 && abs_cons_i >= QAM_64_SOFT_12)
                    o_soft_bits[2:0] <= 3'b111;
                //
                else if(abs_cons_i < QAM_64_SOFT_12 && abs_cons_i >= QAM_64_SOFT_11)
                    o_soft_bits[2:0] <= 3'b111;
                else if(abs_cons_i < QAM_64_SOFT_11 && abs_cons_i >= QAM_64_SOFT_10)
                    o_soft_bits[2:0] <= 3'b110;
                else if(abs_cons_i < QAM_64_SOFT_10 && abs_cons_i >= QAM_64_SOFT_9)
                    o_soft_bits[2:0] <= 3'b101;
                else if(abs_cons_i < QAM_64_SOFT_9  && abs_cons_i >= QAM_64_SOFT_8)
                    o_soft_bits[2:0] <= 3'b100;
                else if(abs_cons_i < QAM_64_SOFT_8  && abs_cons_i >= QAM_64_SOFT_7)
                    o_soft_bits[2:0] <= 3'b000;
                else if(abs_cons_i < QAM_64_SOFT_7  && abs_cons_i >= QAM_64_SOFT_6)
                    o_soft_bits[2:0] <= 3'b001;
                else if(abs_cons_i < QAM_64_SOFT_6  && abs_cons_i >= QAM_64_SOFT_5)
                    o_soft_bits[2:0] <= 3'b010;
                else if(abs_cons_i < QAM_64_SOFT_5  && abs_cons_i >= QAM_64_SOFT_4)
                    o_soft_bits[2:0] <= 3'b011;
                //
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_4 && abs_cons_i >= QAM_64_SOFT_3)
                    o_soft_bits[2:0] <= 3'b111;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_3 && abs_cons_i >= QAM_64_SOFT_2)
                    o_soft_bits[2:0] <= 3'b110;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_2 && abs_cons_i >= QAM_64_SOFT_1)
                    o_soft_bits[2:0] <= 3'b101;
                else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_1 && abs_cons_i >= QAM_64_SOFT_0)
                    o_soft_bits[2:0] <= 3'b100;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_1 && abs_cons_i >= QAM_64_SOFT_0)
                    o_soft_bits[2:0] <= 3'b000;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_2 && abs_cons_i >= QAM_64_SOFT_1)
                    o_soft_bits[2:0] <= 3'b001;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_3 && abs_cons_i >= QAM_64_SOFT_2)
                    o_soft_bits[2:0] <= 3'b010;
                else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_4 && abs_cons_i >= QAM_64_SOFT_3)
                    o_soft_bits[2:0] <= 3'b011;
                //
                else
                    o_soft_bits[2:0] <= 3'b011;

                // Quadrature soft decoded o_bits
                if(abs_cons_q < QAM_64_SOFT_28 && abs_cons_q >= QAM_64_SOFT_27)
                    o_soft_bits[5:3] <= 3'b011;
                else if(abs_cons_q < QAM_64_SOFT_27 && abs_cons_q >= QAM_64_SOFT_26)
                    o_soft_bits[5:3] <= 3'b010;
                else if(abs_cons_q < QAM_64_SOFT_26 && abs_cons_q >= QAM_64_SOFT_25)
                    o_soft_bits[5:3] <= 3'b001;
                else if(abs_cons_q < QAM_64_SOFT_25 && abs_cons_q >= QAM_64_SOFT_24)
                    o_soft_bits[5:3] <= 3'b000;
                else if(abs_cons_q < QAM_64_SOFT_24 && abs_cons_q >= QAM_64_SOFT_23)
                    o_soft_bits[5:3] <= 3'b100;
                else if(abs_cons_q < QAM_64_SOFT_23 && abs_cons_q >= QAM_64_SOFT_22)
                    o_soft_bits[5:3] <= 3'b101;
                else if(abs_cons_q < QAM_64_SOFT_22 && abs_cons_q >= QAM_64_SOFT_21)
                    o_soft_bits[5:3] <= 3'b110;
                else if(abs_cons_q < QAM_64_SOFT_21 && abs_cons_q >= QAM_64_SOFT_20)
                    o_soft_bits[5:3] <= 3'b111;
                // 
                else if(abs_cons_q < QAM_64_SOFT_20 && abs_cons_q >= QAM_64_SOFT_19)
                    o_soft_bits[5:3] <= 3'b010;
                else if(abs_cons_q < QAM_64_SOFT_19 && abs_cons_q >= QAM_64_SOFT_18)
                    o_soft_bits[5:3] <= 3'b010;
                else if(abs_cons_q < QAM_64_SOFT_18 && abs_cons_q >= QAM_64_SOFT_17)
                    o_soft_bits[5:3] <= 3'b001;
                else if(abs_cons_q < QAM_64_SOFT_17 && abs_cons_q >= QAM_64_SOFT_16)
                    o_soft_bits[5:3] <= 3'b000;
                else if(abs_cons_q < QAM_64_SOFT_16 && abs_cons_q >= QAM_64_SOFT_15)
                    o_soft_bits[5:3] <= 3'b100;
                else if(abs_cons_q < QAM_64_SOFT_15 && abs_cons_q >= QAM_64_SOFT_14)
                    o_soft_bits[5:3] <= 3'b101;
                else if(abs_cons_q < QAM_64_SOFT_14 && abs_cons_q >= QAM_64_SOFT_13)
                    o_soft_bits[5:3] <= 3'b110;
                else if(abs_cons_q < QAM_64_SOFT_13 && abs_cons_q >= QAM_64_SOFT_12)
                    o_soft_bits[5:3] <= 3'b111;
                //
                else if(abs_cons_q < QAM_64_SOFT_12 && abs_cons_q >= QAM_64_SOFT_11)
                    o_soft_bits[5:3] <= 3'b111;
                else if(abs_cons_q < QAM_64_SOFT_11 && abs_cons_q >= QAM_64_SOFT_10)
                    o_soft_bits[5:3] <= 3'b110;
                else if(abs_cons_q < QAM_64_SOFT_10 && abs_cons_q >= QAM_64_SOFT_9)
                    o_soft_bits[5:3] <= 3'b101;
                else if(abs_cons_q < QAM_64_SOFT_9  && abs_cons_q >= QAM_64_SOFT_8)
                    o_soft_bits[5:3] <= 3'b100;
                else if(abs_cons_q < QAM_64_SOFT_8  && abs_cons_q >= QAM_64_SOFT_7)
                    o_soft_bits[5:3] <= 3'b000;
                else if(abs_cons_q < QAM_64_SOFT_7  && abs_cons_q >= QAM_64_SOFT_6)
                    o_soft_bits[5:3] <= 3'b001;
                else if(abs_cons_q < QAM_64_SOFT_6  && abs_cons_q >= QAM_64_SOFT_5)
                    o_soft_bits[5:3] <= 3'b010;
                else if(abs_cons_q < QAM_64_SOFT_5  && abs_cons_q >= QAM_64_SOFT_4)
                    o_soft_bits[5:3] <= 3'b011;
                //
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_4 && abs_cons_q >= QAM_64_SOFT_3)
                    o_soft_bits[5:3] <= 3'b111;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_3 && abs_cons_q >= QAM_64_SOFT_2)
                    o_soft_bits[5:3] <= 3'b110;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_2 && abs_cons_q >= QAM_64_SOFT_1)
                    o_soft_bits[5:3] <= 3'b101;
                else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_1 && abs_cons_q >= QAM_64_SOFT_0)
                    o_soft_bits[5:3] <= 3'b100;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_1 && abs_cons_q >= QAM_64_SOFT_0)
                    o_soft_bits[5:3] <= 3'b000;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_2 && abs_cons_q >= QAM_64_SOFT_1)
                    o_soft_bits[5:3] <= 3'b001;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_3 && abs_cons_q >= QAM_64_SOFT_2)
                    o_soft_bits[5:3] <= 3'b010;
                else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_4 && abs_cons_q >= QAM_64_SOFT_3)
                    o_soft_bits[5:3] <= 3'b011;
                //
                else
                    o_soft_bits[5:3] <= 3'b011;

                // Inphase soft decoded bit positions
                if(abs_cons_i < QAM_64_SOFT_28 && abs_cons_i >= QAM_64_SOFT_20)
                    o_soft_bits_pos[1:0] <= 2'b10;
                else if(abs_cons_i < QAM_64_SOFT_20 && abs_cons_i >= QAM_64_SOFT_12)
                    o_soft_bits_pos[1:0] <= 2'b01;
                else if(abs_cons_i < QAM_64_SOFT_12 && abs_cons_i >= QAM_64_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b10;
                else if(abs_cons_i < QAM_64_SOFT_4)
                    o_soft_bits_pos[1:0] <= 2'b00;
                else
                    o_soft_bits_pos[1:0] <= 2'b11;

                // Quadrature soft decoded bit positions
                if(abs_cons_q < QAM_64_SOFT_28 && abs_cons_q >= QAM_64_SOFT_20)
                    o_soft_bits_pos[3:2] <= 2'b10;
                else if(abs_cons_q < QAM_64_SOFT_20 && abs_cons_q >= QAM_64_SOFT_12)
                    o_soft_bits_pos[3:2] <= 2'b01;
                else if(abs_cons_q < QAM_64_SOFT_12 && abs_cons_q >= QAM_64_SOFT_4)
                    o_soft_bits_pos[3:2] <= 2'b10;
                else if(abs_cons_q < QAM_64_SOFT_4)
                    o_soft_bits_pos[3:2] <= 2'b00;
                else
                    o_soft_bits_pos[3:2] <= 2'b11;
            end
        endcase
    end
end

endmodule

