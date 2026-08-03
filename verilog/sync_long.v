//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: sync_long
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

module sync_long (
    input i_clock,
    input i_reset,
    input i_enable,

    input [31:0] i_sample_in,
    input i_sample_in_strobe,
    input signed [15:0] i_phase_offset,
    input i_short_gi,
    input [3:0] i_fft_win_shift,

    output [`ROTATE_LUT_LEN_SHIFT-1:0] o_rot_addr,
    input [31:0] i_rot_data,

    output [31:0] o_metric,
    output o_metric_stb,
    output reg o_long_preamble_detected,

    output reg [31:0] o_spectrum_out,
    output reg o_spectrum_out_stb,
    output reg [15:0] o_num_ofdm_symbol,

    output reg signed [31:0] o_phase_offset_taken,
    output reg [1:0] o_state
);
`include "common_params.v"

localparam IN_BUF_LEN_SHIFT = 8;

localparam NUM_STS_TAIL = 32;

reg [15:0] in_offset;
reg [IN_BUF_LEN_SHIFT-1:0] in_waddr;
reg [IN_BUF_LEN_SHIFT-1:0] in_raddr;
wire [IN_BUF_LEN_SHIFT-1:0] gi_skip = i_short_gi? 9: 17;
reg signed [31:0] num_input_produced;
reg signed [31:0] num_input_consumed;
reg signed [31:0] num_input_avail;

reg [2:0] mult_stage;
reg [1:0] sum_stage;
reg  mult_strobe;

wire signed [31:0] stage_sum_i;
wire signed [31:0] stage_sum_q;

wire stage_sum_stb;

reg signed [31:0] sum_i;
reg signed [31:0] sum_q;
reg sum_stb;

reg signed [31:0] phase_correction;
reg signed [31:0] next_phase_correction;

reg i_reset_delay ; // add i_reset signal for fft, somehow all kinds of event flag raises when feeding real rf signal, maybe i_reset will help
wire fft_i_resetn ;

always @(posedge i_clock) begin
    i_reset_delay = i_reset ;
end
assign fft_i_resetn = (~i_reset) & (~i_reset_delay); // make sure i_resetn is at least 2 i_clock cycles low 

complex_to_mag #(.DATA_WIDTH(32)) sum_mag_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .i_i(sum_i),
    .i_q(sum_q),
    .i_input_strobe(sum_stb),

    .o_mag(o_metric),
    .o_mag_stb(o_metric_stb)
);

reg [31:0] metric_max1;
reg [(IN_BUF_LEN_SHIFT-1):0] addr1;

reg [31:0] cross_corr_buf[0:31];

reg [31:0] stage_X0;
reg [31:0] stage_X1;
reg [31:0] stage_X2;
reg [31:0] stage_X3;
reg [31:0] stage_X4;
reg [31:0] stage_X5;
reg [31:0] stage_X6;
reg [31:0] stage_X7;

reg [31:0] stage_Y0;
reg [31:0] stage_Y1;
reg [31:0] stage_Y2;
reg [31:0] stage_Y3;
reg [31:0] stage_Y4;
reg [31:0] stage_Y5;
reg [31:0] stage_Y6;
reg [31:0] stage_Y7;

stage_mult stage_mult_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .X0(stage_X0),
    .X1(stage_X1),
    .X2(stage_X2),
    .X3(stage_X3),
    .X4(stage_X4),
    .X5(stage_X5),
    .X6(stage_X6),
    .X7(stage_X7),

    .Y0(stage_Y0),
    .Y1(stage_Y1),
    .Y2(stage_Y2),
    .Y3(stage_Y3),
    .Y4(stage_Y4),
    .Y5(stage_Y5),
    .Y6(stage_Y6),
    .Y7(stage_Y7),

    .input_strobe(mult_strobe),

    .sum({stage_sum_i, stage_sum_q}),
    .output_strobe(stage_sum_stb)
);

localparam S_SKIPPING = 0;
localparam S_WAIT_FOR_FIRST_PEAK = 1;
localparam S_IDLE = 2;
localparam S_FFT = 3;

reg fft_start;
//wire fft_start_delayed;

wire fft_in_stb;
reg fft_loading;
wire signed [15:0] fft_in_re;
wire signed [15:0] fft_in_im;
wire [22:0] fft_out_re;
wire [22:0] fft_out_im;
wire fft_ready;
//wire fft_done;
//wire fft_busy;
wire fft_valid;

wire [31:0] fft_out = {fft_out_re[22:7], fft_out_im[22:7]};

wire signed [15:0] raw_i;
wire signed [15:0] raw_q;
reg raw_stb;
wire idle_line1, idle_line2 ;
reg fft_din_data_tlast ;
wire fft_din_data_tlast_delayed ;
wire event_frame_started;
wire event_tlast_unexpected;
wire event_tlast_missing;
wire event_status_channel_halt;
wire event_data_in_channel_halt;
wire event_data_out_channel_halt;
wire s_axis_config_tready;
wire m_axis_data_tlast;

ram_2port  #(.DWIDTH(32), .AWIDTH(IN_BUF_LEN_SHIFT)) in_buf (
    .i_clka(i_clock),
    .i_ena(1),
    .i_wea(i_sample_in_strobe),
    .i_addra(in_waddr),
    .i_dia(i_sample_in),
    .o_doa(),
    .i_clkb(i_clock),
    .i_enb(fft_start | fft_loading),
    .i_web(1'b0),
    .i_addrb(in_raddr),
    .i_dib(32'hFFFF),
    .o_dob({raw_i, raw_q})
);

rotate rotate_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .i_in_i(raw_i),
    .i_in_q(raw_q),
    .i_phase(phase_correction),
    .i_input_strobe(raw_stb),

    .o_rot_addr(o_rot_addr),
    .i_rot_data(i_rot_data),
    
    .o_out_i(fft_in_re),
    .o_out_q(fft_in_im),
    .o_output_strobe(fft_in_stb)
);

delayT #(.DATA_WIDTH(1), .DELAY(10)) fft_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in(fft_din_data_tlast),
    .o_data_out(fft_din_data_tlast_delayed)
);

///the fft7_1 isntance is commented out, as it is upgraded to fft9 version
/*xfft_v7_1 dft_inst (
    .clk(i_clock),
    .fwd_inv(1),
    .start(fft_start_delayed),
    .fwd_inv_we(1),

    .xn_re(fft_in_re),
    .xn_im(fft_in_im),
    .xk_re(fft_out_re),
    .xk_im(fft_out_im),
    .rfd(fft_ready),
    .done(fft_done),
    .busy(fft_busy),
    .dv(fft_valid)
);*/


xfft_v9 dft_inst (
  .aclk(i_clock),       // input wire aclk
  .aresetn(fft_i_resetn),                                               
  .s_axis_config_tdata({7'b0, 1'b1}),                          // input wire [7 : 0] s_axis_config_tdata, use LSB to indicate it is forward transform, the rest should be ignored
  .s_axis_config_tvalid(1'b1),                                 // input wire s_axis_config_tvalid
  .s_axis_config_tready(s_axis_config_tready),                // output wire s_axis_config_tready
  .s_axis_data_tdata({fft_in_im, fft_in_re}),                      // input wire [31 : 0] s_axis_data_tdata
  .s_axis_data_tvalid(fft_in_stb),                    // input wire s_axis_data_tvalid
  .s_axis_data_tready(fft_ready),                    // output wire s_axis_data_tready
  .s_axis_data_tlast(fft_din_data_tlast_delayed),                      // input wire s_axis_data_tlast
  .m_axis_data_tdata({idle_line1,fft_out_im, idle_line2, fft_out_re}),                      // output wire [47 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(fft_valid),                    // output wire m_axis_data_tvalid
  .m_axis_data_tready(1'b1),                    // input wire m_axis_data_tready
  .m_axis_data_tlast(m_axis_data_tlast),                      // output wire m_axis_data_tlast
  .event_frame_started(event_frame_started),                  // output wire event_frame_started
  .event_tlast_unexpected(event_tlast_unexpected),            // output wire event_tlast_unexpected
  .event_tlast_missing(event_tlast_missing),                  // output wire event_tlast_missing
  .event_status_channel_halt(event_status_channel_halt),      // output wire event_status_channel_halt
  .event_data_in_channel_halt(event_data_in_channel_halt),    // output wire event_data_in_channel_halt
  .event_data_out_channel_halt(event_data_out_channel_halt)  // output wire event_data_out_channel_halt
);

reg [15:0] num_sample;

//integer i;
integer j;
always @(posedge i_clock) begin
    if (i_reset) begin
        for (j = 0; j < 32; j= j+1) begin
            cross_corr_buf[j] <= 0;
        end
        do_clear();
        o_state <= S_SKIPPING;
        fft_din_data_tlast <= 1'b0;
        o_long_preamble_detected <= 0;
    end else if (i_enable) begin
        if (i_sample_in_strobe && o_state != S_SKIPPING) begin
            in_waddr <= in_waddr + 1;
            num_input_produced <= num_input_produced + 1;
        end
        num_input_avail <= num_input_produced - num_input_consumed;

        case(o_state)
            S_SKIPPING: begin
                // skip the tail of  short preamble
                if (num_sample >= NUM_STS_TAIL) begin
                    num_sample <= 0;
                    o_state <= S_WAIT_FOR_FIRST_PEAK;
                end else if (i_sample_in_strobe) begin
                    num_sample <= num_sample + 1;
                end
            end

            S_WAIT_FOR_FIRST_PEAK: begin
                do_mult();

                if (o_metric_stb && (o_metric > metric_max1)) begin
                    metric_max1 <= o_metric;
                    addr1 <= in_raddr - 1 -i_fft_win_shift;
                end

                if (num_sample >= 88) begin
                    o_long_preamble_detected <= 1;
                    num_sample <= 0;
                    mult_strobe <= 0;
                    sum_stb <= 0;
                    // offset it by the length of cross correlation buffer
                    // size
                    in_raddr <= addr1 - 32;
                    num_input_consumed <= addr1 - 32;
                    in_offset <= 0;
                    o_num_ofdm_symbol <= 0;
                    phase_correction <= 0;
                    next_phase_correction <= i_phase_offset;
                    o_phase_offset_taken <= i_phase_offset;
                    o_state <= S_FFT;
                end else if (o_metric_stb) begin
                    num_sample <= num_sample + 1;
                end

            end

            S_FFT: begin
                if (o_long_preamble_detected) begin
                    `ifdef DEBUG_PRINT
                        $display("Long preamble detected");
                    `endif
                    o_long_preamble_detected <= 0;
                end

                if (~fft_loading && num_input_avail > 88) begin
                    fft_start <= 1;
                    in_offset <= 0;
                end

                if (fft_start) begin
                    fft_start <= 0;
                    fft_loading <= 1;
                end

                raw_stb <= fft_start | fft_loading;
                if (raw_stb) begin
                    if (i_phase_offset > 0) begin
                        if (next_phase_correction > PI) begin
                            phase_correction <= next_phase_correction - DOUBLE_PI;
                            if(in_offset == 63 && o_num_ofdm_symbol > 0)
                                next_phase_correction <= next_phase_correction - DOUBLE_PI + i_phase_offset + (i_short_gi ? i_phase_offset<<<3 : i_phase_offset<<<4);
                            else
                                next_phase_correction <= next_phase_correction - DOUBLE_PI + i_phase_offset;
                        end else begin
                            phase_correction <= next_phase_correction;
                            if(in_offset == 63 && o_num_ofdm_symbol > 0)
                                next_phase_correction <= next_phase_correction + i_phase_offset + (i_short_gi ? i_phase_offset<<<3 : i_phase_offset<<<4);
                            else
                                next_phase_correction <= next_phase_correction + i_phase_offset;
                        end
                    end else begin
                        if (next_phase_correction < -PI) begin
                            phase_correction <= next_phase_correction + DOUBLE_PI;
                            if(in_offset == 63 && o_num_ofdm_symbol > 0)
                                next_phase_correction <= next_phase_correction + DOUBLE_PI + i_phase_offset + (i_short_gi ? i_phase_offset<<<3 : i_phase_offset<<<4);
                            else
                                next_phase_correction <= next_phase_correction + DOUBLE_PI + i_phase_offset;
                        end else begin
                            phase_correction <= next_phase_correction;
                            if(in_offset == 63 && o_num_ofdm_symbol > 0)
                                next_phase_correction <= next_phase_correction + i_phase_offset + (i_short_gi ? i_phase_offset<<<3 : i_phase_offset<<<4);
                            else
                                next_phase_correction <= next_phase_correction + i_phase_offset;
                        end
                    end
                end

                if (fft_start | fft_loading) begin
                    in_offset <= in_offset + 1;
                    
                    if( in_offset == 62) begin
                        fft_din_data_tlast <= 1'b1;
                    end

                    if (in_offset == 63) begin
                        fft_din_data_tlast <= 1'b0;
                        fft_loading <= 0;
                        o_num_ofdm_symbol <= o_num_ofdm_symbol + 1;
                        if (o_num_ofdm_symbol > 0) begin
                            // skip the Guard Interval for data symbols
                            in_raddr <= in_raddr + gi_skip;
                            num_input_consumed <= num_input_consumed + gi_skip;
                        end else begin
                            in_raddr <= in_raddr + 1;
                            num_input_consumed <= num_input_consumed + 1;
                        end
                    end else begin
                        in_raddr <= in_raddr + 1;
                        num_input_consumed <= num_input_consumed + 1;
                    end
                end

                o_spectrum_out_stb <= fft_valid;
                o_spectrum_out <= fft_out;
            end

            S_IDLE: begin
            end

            default: begin
                o_state <= S_WAIT_FOR_FIRST_PEAK;
            end
        endcase
    end else begin
        o_spectrum_out_stb <= 0;
    end
end

integer do_mult_i;
task do_mult; begin
    // cross correlation of the first 16 samples of LTS
    if (i_sample_in_strobe) begin
        cross_corr_buf[31] <= i_sample_in;
        for (do_mult_i = 0; do_mult_i < 31; do_mult_i = do_mult_i+1) begin
            cross_corr_buf[do_mult_i] <= cross_corr_buf[do_mult_i+1];
        end

        sum_stage <= 0;
        sum_i <= 0;
        sum_q <= 0;
        sum_stb <= 0;

        stage_X0 <= cross_corr_buf[1];
        stage_X1 <= cross_corr_buf[2];
        stage_X2 <= cross_corr_buf[3];
        stage_X3 <= cross_corr_buf[4];
        stage_X4 <= cross_corr_buf[5];
        stage_X5 <= cross_corr_buf[6];
        stage_X6 <= cross_corr_buf[7];
        stage_X7 <= cross_corr_buf[8];

        stage_Y0 <= { 16'd156, 16'd0};
        stage_Y1 <= {-16'd5,   16'd120};
        stage_Y2 <= { 16'd40,  16'd111};
        stage_Y3 <= { 16'd97, -16'd83};
        stage_Y4 <= { 16'd21, -16'd28};
        stage_Y5 <= { 16'd60,  16'd88};
        stage_Y6 <= {-16'd115, 16'd55};
        stage_Y7 <= {-16'd38,  16'd106};

        mult_strobe <= 1;
        mult_stage <= 1;
    end

    if (mult_stage == 1) begin
        stage_X0 <= cross_corr_buf[8];
        stage_X1 <= cross_corr_buf[9];
        stage_X2 <= cross_corr_buf[10];
        stage_X3 <= cross_corr_buf[11];
        stage_X4 <= cross_corr_buf[12];
        stage_X5 <= cross_corr_buf[13];
        stage_X6 <= cross_corr_buf[14];
        stage_X7 <= cross_corr_buf[15];

        stage_Y0 <= { 16'd98,  16'd26};
        stage_Y1 <= { 16'd53, -16'd4};
        stage_Y2 <= { 16'd1,   16'd115};
        stage_Y3 <= {-16'd137, 16'd47};
        stage_Y4 <= { 16'd24,  16'd59};
        stage_Y5 <= { 16'd59,  16'd15};
        stage_Y6 <= {-16'd22, -16'd161};
        stage_Y7 <= { 16'd119, 16'd4};

        mult_stage <= 2;
    end else if (mult_stage == 2) begin
        stage_X0 <= cross_corr_buf[16];
        stage_X1 <= cross_corr_buf[17];
        stage_X2 <= cross_corr_buf[18];
        stage_X3 <= cross_corr_buf[19];
        stage_X4 <= cross_corr_buf[20];
        stage_X5 <= cross_corr_buf[21];
        stage_X6 <= cross_corr_buf[22];
        stage_X7 <= cross_corr_buf[23];

        stage_Y0 <= { 16'd62,    16'd62};
        stage_Y1 <= { 16'd37,  -16'd98};
        stage_Y2 <= {-16'd57,  -16'd39};
        stage_Y3 <= {-16'd131, -16'd65};
        stage_Y4 <= { 16'd82,  -16'd92};
        stage_Y5 <= { 16'd70,  -16'd14};
        stage_Y6 <= {-16'd60,  -16'd81};
        stage_Y7 <= {-16'd56,   16'd22};

        mult_stage <= 3;
    end else if (mult_stage == 3) begin
        stage_X0 <= cross_corr_buf[24];
        stage_X1 <= cross_corr_buf[25];
        stage_X2 <= cross_corr_buf[26];
        stage_X3 <= cross_corr_buf[27];
        stage_X4 <= cross_corr_buf[28];
        stage_X5 <= cross_corr_buf[29];
        stage_X6 <= cross_corr_buf[30];
        stage_X7 <= cross_corr_buf[31];

        stage_Y0 <= {-16'd35,  16'd151};
        stage_Y1 <= {-16'd122, 16'd17};
        stage_Y2 <= {-16'd127, 16'd21};
        stage_Y3 <= { 16'd75,  16'd74};
        stage_Y4 <= {-16'd3,  -16'd54};
        stage_Y5 <= {-16'd92, -16'd115};
        stage_Y6 <= { 16'd92, -16'd106};
        stage_Y7 <= { 16'd12, -16'd98};

        mult_stage <= 4;
    end else if (mult_stage == 4) begin
        mult_stage <= 0;
        mult_strobe <= 0;
        in_raddr <= in_raddr + 1;
        num_input_consumed <= num_input_consumed + 1;
    end

    if (stage_sum_stb) begin
        sum_stage <= sum_stage + 1;
        sum_i <= sum_i + stage_sum_i;
        sum_q <= sum_q + stage_sum_q;
        if (sum_stage == 3) begin
            sum_stb <= 1;
        end
    end else begin
        sum_stb <= 0;
        sum_i <= 0;
        sum_q <= 0;
    end
end
endtask

task do_clear; begin

    in_waddr <= 0;
    in_raddr <= 0;
    in_offset <= 0;
    num_input_produced <= 0;
    num_input_consumed <= 0;
    num_input_avail <= 0;

    phase_correction <= 0;
    next_phase_correction <= 0;

    raw_stb <= 0;

    sum_i <= 0;
    sum_q <= 0;
    sum_stb <= 0;
    sum_stage <= 0;
    mult_strobe <= 0;

    metric_max1 <= 0;
    addr1 <= 0;

    mult_stage <= 0;

    o_long_preamble_detected <= 0;
    num_sample <= 0;
    o_num_ofdm_symbol <= 0;

    fft_start <= 0;
    fft_loading <= 0;

    o_spectrum_out_stb <= 0;
    o_spectrum_out <= 0;

    stage_X0 <= 0;
    stage_X1 <= 0;
    stage_X2 <= 0;
    stage_X3 <= 0;
    stage_X4 <= 0;
    stage_X5 <= 0;
    stage_X6 <= 0;
    stage_X7 <= 0;

    stage_Y0 <= 0;
    stage_Y1 <= 0;
    stage_Y2 <= 0;
    stage_Y3 <= 0;
    stage_Y4 <= 0;
    stage_Y5 <= 0;
    stage_Y6 <= 0;
    stage_Y7 <= 0;
end
endtask

endmodule

