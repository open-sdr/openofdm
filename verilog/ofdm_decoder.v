//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: ofdm_decoder
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

module ofdm_decoder
(
    input i_clock,
    input i_enable,
    input i_reset,

    input [31:0] i_sample_in,
    input i_sample_in_strobe,
    input i_soft_decoding,

    // decode instructions
    input [7:0] i_rate,
    input i_do_descramble,
    input [19:0] i_num_bits_to_decode, //4bits + ht_len: i_num_bits_to_decode <= (22+(ht_len<<3));

    output [5:0] o_demod_out,
    output [5:0] o_demod_soft_bits,
    output [3:0] o_demod_soft_bits_pos,
    output o_demod_out_strobe,

    output [7:0] o_deinterleave_erase_out,
    output o_deinterleave_erase_out_strobe,

    output o_conv_decoder_out,
    output o_conv_decoder_out_stb,

    output o_descramble_out,
    output o_descramble_out_strobe,

    output [7:0] o_byte_out,
    output o_byte_out_strobe
);

reg conv_in_stb, conv_in_stb_dly, do_descramble_dly;
reg [2:0] conv_in0, conv_in0_dly;
reg [2:0] conv_in1, conv_in1_dly;
reg [1:0] conv_erase, conv_erase_dly;

wire [15:0] input_i = i_sample_in[31:16];
wire [15:0] input_q = i_sample_in[15:0];

// wire vit_ce = i_reset | (i_enable & conv_in_stb) | conv_in_stb_dly; //Seems new viter decoder IP core does not need this complicated CE signal
wire vit_ce = 1'b1 ; //Need to be 1 to avoid the viterbi decoder freezing issue on adrv9364z7020 (demod_is_ongoing always high. dot11 stuck at state 3)
wire vit_clr = i_reset;
//reg vit_clr_dly;
(* keep = "true" *) wire vit_rdy;

wire [5:0] deinterleave_out;
wire deinterleave_out_strobe;
wire [1:0] erase;

(* keep = "true" *) wire m_axis_data_tvalid ;

// assign o_conv_decoder_out_stb = vit_ce & vit_rdy;
assign o_conv_decoder_out_stb = m_axis_data_tvalid; // vit_rdy was used as data valid in the old version of the core, which is no longer the case 
reg [3:0] skip_bit;
reg bit_in;
reg bit_in_stb;

reg [19:0] deinter_out_count; // bitwidth same as i_num_bits_to_decode
//reg flush;

assign o_deinterleave_erase_out = {erase,deinterleave_out};
assign o_deinterleave_erase_out_strobe = deinterleave_out_strobe;
demodulate demod_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),
    .i_enable(i_enable),

    .i_rate(i_rate),
    .i_cons_i(input_i),
    .i_cons_q(input_q),
    .i_input_strobe(i_sample_in_strobe),
    .o_bits(o_demod_out),
    .o_soft_bits(o_demod_soft_bits),
    .o_soft_bits_pos(o_demod_soft_bits_pos),
    .o_output_strobe(o_demod_out_strobe)
);

deinterleave deinterleave_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),
    .i_enable(i_enable),

    .i_rate(i_rate),
    .i_in_bits(o_demod_out),
    .i_soft_in_bits(o_demod_soft_bits),
    .i_soft_in_bits_pos(o_demod_soft_bits_pos),
    .i_input_strobe(o_demod_out_strobe),
    .i_soft_decoding(i_soft_decoding),

    .o_out_bits(deinterleave_out),
    .o_output_strobe(deinterleave_out_strobe),
    .o_erase(erase)
);
/*
viterbi_v7_0 viterbi_inst (
    .clk(i_clock),
    .ce(vit_ce),
    .sclr(vit_clr),
    .data_in0(conv_in0),
    .data_in1(conv_in1),
    .erase(conv_erase),
    .rdy(vit_rdy),
    .data_out(o_conv_decoder_out)
);
*/
//reg [4:0] idle_wire_5bit ;
//wire [6:0] idle_wire_7bit ; 
viterbi_v7_0 viterbi_inst (
  .aclk(i_clock),                              // input wire aclk
  .aresetn(~vit_clr),                        // input wire aresetn
  .aclken(vit_ce),                          // input wire aclken
  .s_axis_data_tdata({5'b0,conv_in1_dly,5'b0,conv_in0_dly}),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tuser({6'b0,conv_erase_dly}),    // input wire [7 : 0] s_axis_data_tuser
  .s_axis_data_tvalid(conv_in_stb_dly),  // input wire s_axis_data_tvalid
  .s_axis_data_tready(vit_rdy),  // output wire s_axis_data_tready
  .m_axis_data_tdata({idle_wire_7bit, o_conv_decoder_out}),    // output wire [7 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);

descramble decramble_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),
    
    .i_in_bit(o_conv_decoder_out),
    .i_input_strobe(o_conv_decoder_out_stb),

    .o_out_bit(o_descramble_out),
    .o_output_strobe(o_descramble_out_strobe)
);


bits_to_bytes byte_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .i_bit_in(bit_in),
    .i_input_strobe(bit_in_stb),

    .o_byte_out(o_byte_out),
    .o_output_strobe(o_byte_out_strobe)
);

always @(posedge i_clock) begin
    if (i_reset) begin
        conv_in_stb <= 0;
        conv_in0 <= 0;
        conv_in1 <= 0;
        conv_erase <= 0;

        bit_in <= 0;
        // skip the first 9 bits of descramble out (service bits)
        skip_bit <= 9;
        bit_in_stb <= 0;

        //flush <= 0;
        deinter_out_count <= 0;
    end else if (i_enable) begin
        if (deinterleave_out_strobe) begin
            deinter_out_count <= deinter_out_count + 1;
        end //else begin
            // wait for finishing deinterleaving current symbol
            // only do flush for non-DATA bits, such as SIG and HT-SIG, which
            // are not scrambled
            //if (~i_do_descramble && deinter_out_count >= i_num_bits_to_decode) begin
            //if (deinter_out_count >= i_num_bits_to_decode) begin // careful! deinter_out_count is only correct from 6M ~ 48M! under 54M, it should be 2*216, but actual value is 288!
                //flush <= 1;
            //end
        //end
        //if (!flush) begin
        if (!(deinter_out_count >= i_num_bits_to_decode)) begin
            conv_in_stb <= deinterleave_out_strobe;
            conv_in0 <= deinterleave_out[2:0];
            conv_in1 <= deinterleave_out[5:3];
            conv_erase <= erase;
        end else begin
            conv_in_stb <= 1;
            conv_in0 <= 3'b011;
            conv_in1 <= 3'b011;
            conv_erase <= 0;
        end

        if (deinter_out_count > 0) begin
            if (~do_descramble_dly) begin
                bit_in <= o_conv_decoder_out;
                bit_in_stb <= o_conv_decoder_out_stb;
            end else begin
                bit_in <= o_descramble_out;
                if (o_descramble_out_strobe) begin
                    if (skip_bit > 0 ) begin
                        skip_bit <= skip_bit - 1;
                        bit_in_stb <= 0;
                    end else begin
                        bit_in_stb <= 1;
                    end
                end else begin
                    bit_in_stb <= 0;
                end
            end
        end
    end
end

// process used to delay things
// TODO: this is only a temp solution, as tready only rise one i_clock after ce goes high, delay statically by one i_clock, in future should take into account tready
always @(posedge i_clock) begin
    conv_in1_dly <= conv_in1;
    conv_in0_dly <= conv_in0;
    conv_erase_dly <= conv_erase;
    conv_in_stb_dly <= conv_in_stb ;
    do_descramble_dly <= i_do_descramble;
end

endmodule

