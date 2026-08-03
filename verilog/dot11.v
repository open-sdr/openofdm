//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: dot11
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
`include "openofdm_rx_pre_def.v"

`ifdef OPENOFDM_RX_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

`define USE_POWER_TRIGGER

module dot11 (
    input i_clock,
    input i_enable,
    input i_reset,
    input i_reset_without_watchdog,

    // setting registers
    //input set_stb,
    //input [7:0] set_addr,
    //input [31:0] set_data,
    
    // add ports for register based inputs
    //input signed [10:0] i_power_thres,
    input [31:0] i_min_plateau,
    input i_threshold_scale,
    input i_num_sample_changed,
    input [31:0] i_reg_num_sample_to_skip,
    input [15:0] i_reg_power_thres, //signal power threshold that asserts trigger
    input [15:0] i_reg_window_size,

    // INPUT: RSSI
    input signed [10:0] i_rssi_half_db,
    // INPUT: I/Q sample
    input [31:0] i_sample_in,
    input i_sample_in_strobe,
    input i_soft_decoding,
    input wire i_force_ht_smoothing,
    input wire i_disable_all_smoothing,
    input [3:0] i_fft_win_shift, 

    // OUTPUT: bytes and FCS status
    output reg o_demod_is_ongoing,
    output reg o_pkt_begin,
    output reg o_pkt_ht,
    output reg o_pkt_header_valid,
    output reg o_pkt_header_valid_strobe,
    output reg o_ht_unsupport,
    output reg [7:0] o_pkt_rate,
    output reg [15:0] o_pkt_len,
    output reg [15:0] o_pkt_len_total,
    output o_byte_out_strobe,
    output [7:0] o_byte_out,
    output reg [15:0] o_byte_count_total,
    output reg [15:0] o_byte_count,
    output reg o_fcs_out_strobe,
    output reg o_fcs_ok, //frame checksum OK pulse. Is valid for one falling edge of i_clock.

    // Equalizer Output
    output [15:0] o_eq_phase_out,
    output o_eq_phase_out_stb,

    /////////////////////////////////////////////////////////
    // DEBUG PORTS
    /////////////////////////////////////////////////////////
    
    // decode status
    // (* mark_debug = "true", DONT_TOUCH = "TRUE" *) 
    `DEBUG_PREFIX output reg [4:0] o_state,
    (* keep = "true" *) output reg [4:0] o_status_code,
    `DEBUG_PREFIX output o_state_changed,
    `DEBUG_PREFIX output reg [31:0] o_state_history,

    // power trigger
    `DEBUG_PREFIX  output o_power_trigger,

    // sync short
    `DEBUG_PREFIX output o_short_preamble_detected,
    `DEBUG_PREFIX  output [15:0] o_phase_offset,

    // sync long
    output [31:0] o_sync_long_metric,
    `DEBUG_PREFIX output o_sync_long_metric_stb,
    `DEBUG_PREFIX output o_long_preamble_detected,
    `DEBUG_PREFIX output [31:0] o_sync_long_out,
    `DEBUG_PREFIX output o_sync_long_out_strobe,
    `DEBUG_PREFIX output wire signed [31:0] o_phase_offset_taken,
    `DEBUG_PREFIX output [2:0] o_sync_long_state,

    // equalizer
    `DEBUG_PREFIX output [31:0] o_equalizer_out,
    `DEBUG_PREFIX output o_equalizer_out_strobe,
    (* keep = "true" *) output [3:0] o_equalizer_state,
    `DEBUG_PREFIX output wire o_ofdm_symbol_eq_out_pulse,

    // legacy signal info
    output reg o_legacy_sig_stb,
    output [3:0] o_legacy_rate,
    output o_legacy_sig_rsvd,
    output [11:0] o_legacy_len,
    output o_legacy_sig_parity,
    output o_legacy_sig_parity_ok,
    output [5:0] o_legacy_sig_tail,

    // ht signal info
    output reg o_ht_sig_stb,
    output [6:0] o_ht_mcs,
    output o_ht_cbw,
    output [15:0] o_ht_len,
    output o_ht_smoothing,
    output o_ht_not_sounding,
    output o_ht_aggr,
    output reg o_ht_aggr_last,
    output [1:0] o_ht_stbc,
    output o_ht_fec_coding,
    output o_ht_sgi,
    output [1:0] o_ht_num_ext,
    output reg o_ht_sig_crc_ok,

    `DEBUG_PREFIX output [14:0] o_n_ofdm_sym,//max 20166 = (22+65535*8)/26 (max ht len 65535 in sig, min ndbps 26 for mcs0)
    `DEBUG_PREFIX output [9:0]  o_n_bit_in_last_sym,//max ht ndbps 260 (ht mcs7)
    `DEBUG_PREFIX output        o_phy_len_valid,

    // decoding pipeline
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

    // for side channel
    output wire [31:0] o_csi,
    output wire o_csi_valid
);

/********************************************************************************
/
/ END OF MODULE PORT DEFINITION 
/
*********************************************************************************/


`include "common_params.v"

wire [19:0] n_bit_in_last_sym_tmp;
assign o_n_bit_in_last_sym = n_bit_in_last_sym_tmp[9:0];

// -------------- DEBUG for rx_stop_state4e012345-------------------------------
`DEBUG_PREFIX reg  [14:0] timeout_counter;
always @(posedge i_clock) begin
  if ( (i_reset==1) || (~(o_state==S_DETECT_HT)) ) begin
    timeout_counter <= 0;
  end else begin
    timeout_counter <= ( (timeout_counter == 15'h7fff)? timeout_counter : (timeout_counter+1) );
  end
end
// -------------- DEBUG for rx_stop_state4e012345-------------------------------

////////////////////////////////////////////////////////////////////////////////
// extra info output to ease side info and viterbi o_state monitor
////////////////////////////////////////////////////////////////////////////////
`DEBUG_PREFIX reg  [3:0] equalizer_state_reg;

assign o_ofdm_symbol_eq_out_pulse = (o_equalizer_state == 4 && equalizer_state_reg == 8);

always @(posedge i_clock) begin
    if (i_reset_without_watchdog == 1) begin
        o_state_history <= 0;
        equalizer_state_reg <= 0;
    end else begin
        equalizer_state_reg <= o_equalizer_state;
        if (o_state_changed) begin
            o_state_history[3:0] <= o_state;
            o_state_history[31:4] <= o_state_history[27:0];
        end 
    end
end
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// Shared rotation LUT for sync_long and equalizer
////////////////////////////////////////////////////////////////////////////////
wire [`ROTATE_LUT_LEN_SHIFT-1:0] sync_long_rot_addr;
wire [31:0] sync_long_rot_data;

(* keep = "true" *) wire [`ROTATE_LUT_LEN_SHIFT-1:0] eq_rot_addr;
(* keep = "true" *) wire [31:0] eq_rot_data;

rot_lut rot_lut_inst (
    .clka(i_clock),
    .addra(sync_long_rot_addr),
    .douta(sync_long_rot_data),

    .enb(1),
    .clkb(i_clock),
    .addrb(eq_rot_addr),
    .doutb(eq_rot_data)
);
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// Shared phase module for sync_short and equalizer
////////////////////////////////////////////////////////////////////////////////
wire [31:0] sync_short_phase_in_i;
wire [31:0] sync_short_phase_in_q;
wire sync_short_phase_in_stb;
wire [15:0] sync_short_phase_out;
wire sync_short_phase_out_stb;

wire [31:0] eq_phase_in_i;
wire [31:0] eq_phase_in_q;
wire eq_phase_in_stb;
//wire [15:0] o_eq_phase_out;
//wire o_eq_phase_out_stb;

wire[31:0] phase_in_i = o_state == S_SYNC_SHORT?
    sync_short_phase_in_i: eq_phase_in_i;
wire[31:0] phase_in_q = o_state == S_SYNC_SHORT?
    sync_short_phase_in_q: eq_phase_in_q;
wire phase_in_stb = o_state == S_SYNC_SHORT?
    sync_short_phase_in_stb: eq_phase_in_stb;

wire [15:0] phase_out;
wire phase_out_stb;

assign sync_short_phase_out = phase_out;
assign sync_short_phase_out_stb = phase_out_stb;
assign o_eq_phase_out = phase_out;
assign o_eq_phase_out_stb = phase_out_stb;

phase phase_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),
    .i_enable(i_enable),

    .i_in_i(phase_in_i),
    .i_in_q(phase_in_q),
    .i_input_strobe(phase_in_stb),

    .o_phase(phase_out),
    .o_output_strobe(phase_out_stb)
);
////////////////////////////////////////////////////////////////////////////////

reg sync_short_reset;
reg sync_long_reset;
// wire sync_short_enable = o_state == S_SYNC_SHORT;
wire sync_short_enable = 1;
reg sync_long_enable;
wire [15:0] num_ofdm_symbol;

reg equalizer_reset;
reg equalizer_enable;

reg ht_next;

wire eq_out_stb_delayed;
wire [15:0] eq_out_i = o_equalizer_out[31:16];
wire [15:0] eq_out_q = o_equalizer_out[15:0];
wire [15:0] eq_out_i_delayed;
wire [15:0] eq_out_q_delayed;
reg [15:0] abs_eq_i;
reg [15:0] abs_eq_q;
reg [3:0] rot_eq_count;
reg [3:0] normal_eq_count;

// OFDM control
reg ofdm_reset;
reg ofdm_enable;
reg ofdm_in_stb;
reg [15:0] ofdm_in_i;
reg [15:0] ofdm_in_q;

reg do_descramble;
reg [19:0] num_bits_to_decode; //4bits + o_ht_len: num_bits_to_decode <= (22+(o_ht_len<<3));
reg short_gi;

reg [4:0] old_state;

`ifndef USE_POWER_TRIGGER
assign o_power_trigger = (rssi_half_db>=i_power_thres? 1: 0);
`endif // USE_POWER_TRIGGER
assign o_state_changed = o_state != old_state;

// SIGNAL information
reg [23:0] signal_bits;

assign o_legacy_rate = signal_bits[3:0];
assign o_legacy_sig_rsvd = signal_bits[4];
assign o_legacy_len = signal_bits[16:5];
assign o_legacy_sig_parity = signal_bits[17];
assign o_legacy_sig_tail = signal_bits[23:18];
assign o_legacy_sig_parity_ok = ~^signal_bits[17:0];

// HT-SIG information
reg [23:0] o_ht_sig1;
reg [23:0] o_ht_sig2;

assign o_ht_mcs = o_ht_sig1[6:0];
assign o_ht_cbw = o_ht_sig1[7];
assign o_ht_len = o_ht_sig1[23:8];

assign o_ht_smoothing = o_ht_sig2[0];
assign o_ht_not_sounding = o_ht_sig2[1];
assign o_ht_aggr = o_ht_sig2[3];
assign o_ht_stbc = o_ht_sig2[5:4];
assign o_ht_fec_coding = o_ht_sig2[6];
assign o_ht_sgi = o_ht_sig2[7];
assign o_ht_num_ext = o_ht_sig2[9:8];

wire ht_rsvd = o_ht_sig2[2];
wire [7:0] crc = o_ht_sig2[17:10];
wire [5:0] ht_sig_tail = o_ht_sig2[23:18];

reg [15:0] pkt_len_rem;
reg [7:0] mpdu_del_crc;
reg [1:0] mpdu_pad;

reg crc_in_stb;
reg crc_in;
reg [7:0] crc_count;
reg crc_reset;
wire [7:0] crc_out;

reg [31:0] sample_count;

wire fcs_enable = o_state == S_DECODE_DATA && o_byte_out_strobe;
wire fcs_reset = o_state_changed && o_state == S_DECODE_DATA;
wire [7:0] byte_reversed;
wire [31:0] pkt_fcs;

assign byte_reversed[0] = o_byte_out[7];
assign byte_reversed[1] = o_byte_out[6];
assign byte_reversed[2] = o_byte_out[5];
assign byte_reversed[3] = o_byte_out[4];
assign byte_reversed[4] = o_byte_out[3];
assign byte_reversed[5] = o_byte_out[2];
assign byte_reversed[6] = o_byte_out[1];
assign byte_reversed[7] = o_byte_out[0];

reg [15:0] sync_long_out_count;

`ifdef USE_POWER_TRIGGER
power_trigger power_trigger_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset),

    .i_sample_in(i_sample_in),
    .i_sample_in_strobe(i_sample_in_strobe),

    //.i_power_thres(i_power_thres),
    //.window_size(window_size),
    //.num_sample_to_skip(num_sample_to_skip),
    //.num_sample_changed(num_sample_changed),
    .i_num_sample_changed(i_num_sample_changed),
    .i_reg_num_sample_to_skip(i_reg_num_sample_to_skip),
    .i_reg_power_thres(i_reg_power_thres),
    .i_reg_window_size(i_reg_window_size),

    //.pw_state_spy(pw_state_spy),
    .o_trigger(o_power_trigger)
);
`endif // USE_POWER_TRIGGER

sync_short sync_short_inst (
    .i_clock(i_clock),
    .i_reset(i_reset | sync_short_reset),
    .i_enable(i_enable & sync_short_enable),

    .i_min_plateau(i_min_plateau),
    .i_threshold_scale(i_threshold_scale),
    
    .i_sample_in(i_sample_in),
    .i_sample_in_strobe(i_sample_in_strobe),

    .o_phase_in_i(sync_short_phase_in_i),
    .o_phase_in_q(sync_short_phase_in_q),
    .o_phase_in_stb(sync_short_phase_in_stb),

    .i_phase_out(sync_short_phase_out),
    .i_phase_out_stb(sync_short_phase_out_stb),

    .i_demod_is_ongoing(o_demod_is_ongoing),
    .o_short_preamble_detected(o_short_preamble_detected),
    .o_phase_offset(o_phase_offset)
);

sync_long sync_long_inst (
    .i_clock(i_clock),
    .i_reset(i_reset | sync_long_reset),
    .i_enable(i_enable & sync_long_enable),

    .i_sample_in(i_sample_in),
    .i_sample_in_strobe(i_sample_in_strobe),
    .i_phase_offset(o_phase_offset),
    .i_short_gi(short_gi),
    .i_fft_win_shift(i_fft_win_shift),

    .o_rot_addr(sync_long_rot_addr),
    .i_rot_data(sync_long_rot_data),

    .o_metric(o_sync_long_metric),
    .o_metric_stb(o_sync_long_metric_stb),
    .o_long_preamble_detected(o_long_preamble_detected),
    .o_phase_offset_taken(o_phase_offset_taken),
    .o_state(o_sync_long_state),

    .o_spectrum_out(o_sync_long_out),
    .o_spectrum_out_stb(o_sync_long_out_strobe),
    .o_num_ofdm_symbol(num_ofdm_symbol)
);

/*************************************************************************************
    #######   #####   #     #     #     #        ###  #######  #######  ######
    #        #     #  #     #    # #    #         #        #   #        #     #
    #        #     #  #     #   #   #   #         #       #    #        #     #
    #####    #     #  #     #  #     #  #         #     #      #####    ######
    #        #   # #  #     #  #######  #         #    #       #        #   #
    #        #    #   #     #  #     #  #         #   #        #        #    #
    #######   #### #   #####   #     #  #######  ###  #######  #######  #     #
**************************************************************************************/
equalizer equalizer_inst (
    .i_clock(i_clock),
    .i_reset(i_reset | equalizer_reset),
    .i_enable(i_enable & equalizer_enable),

    .i_sample_in(o_sync_long_out),
    .i_sample_in_strobe(o_sync_long_out_strobe && !(o_state==S_HT_SIGNAL && num_ofdm_symbol==6)),
    .i_ht_next(ht_next),
    .i_pkt_ht(o_pkt_ht),
    .i_ht_smoothing(o_ht_smoothing|i_force_ht_smoothing),
    .i_disable_all_smoothing(i_disable_all_smoothing),

    .o_phase_in_i(eq_phase_in_i),
    .o_phase_in_q(eq_phase_in_q),
    .o_phase_in_stb(eq_phase_in_stb),

    .i_phase_out(o_eq_phase_out),
    .i_phase_out_stb(o_eq_phase_out_stb),

    .o_rot_addr(eq_rot_addr),
    .i_rot_data(eq_rot_data),

    .o_sample_out(o_equalizer_out),
    .o_sample_out_strobe(o_equalizer_out_strobe),

    .o_state(o_equalizer_state),

    .o_csi(o_csi),
    .o_csi_valid(o_csi_valid)
);


delayT #(.DATA_WIDTH(33), .DELAY(9)) eq_delay_inst (
    .i_clock(i_clock),
    .i_reset(i_reset),

    .i_data_in({o_equalizer_out_strobe, o_equalizer_out}),
    .o_data_out({eq_out_stb_delayed, eq_out_i_delayed, eq_out_q_delayed})
);

/**************************************************************************************************************

 #####   #######  ######   #     #     ######   #######   #####    #####   ######   #######  ######
#     #  #        #     #  ##   ##     #     #  #        #     #  #     #  #     #  #        #     #
#     #  #        #     #  # # # #     #     #  #        #        #     #  #     #  #        #     #
#     #  #####    #     #  #  #  #     #     #  #####    #        #     #  #     #  #####    ######
#     #  #        #     #  #     #     #     #  #        #        #     #  #     #  #        #   #
#     #  #        #     #  #     #     #     #  #        #     #  #     #  #     #  #        #    #
 #####   #        ######   #     #     ######   #######   #####    #####   ######   #######  #     #

/**************************************************************************************************************/

ofdm_decoder ofdm_decoder_inst (
    .i_clock(i_clock),
    .i_reset(i_reset|ofdm_reset),
    .i_enable(i_enable & ofdm_enable),

    .i_sample_in({ofdm_in_i, ofdm_in_q}),
    .i_sample_in_strobe(ofdm_in_stb),
    .i_soft_decoding(i_soft_decoding),

    .i_do_descramble(do_descramble),
    .i_num_bits_to_decode(num_bits_to_decode),
    .i_rate(o_pkt_rate),

    .o_byte_out(o_byte_out),
    .o_byte_out_strobe(o_byte_out_strobe),

    .o_demod_out(o_demod_out),
    .o_demod_soft_bits(o_demod_soft_bits),
    .o_demod_soft_bits_pos(o_demod_soft_bits_pos),
    .o_demod_out_strobe(o_demod_out_strobe),

    .o_deinterleave_erase_out(o_deinterleave_erase_out),
    .o_deinterleave_erase_out_strobe(o_deinterleave_erase_out_strobe),

    .o_conv_decoder_out(o_conv_decoder_out),
    .o_conv_decoder_out_stb(o_conv_decoder_out_stb),

    .o_descramble_out(o_descramble_out),
    .o_descramble_out_strobe(o_descramble_out_strobe)
);

ht_sig_crc crc_inst (
    .i_clock(i_clock),
    .i_enable(i_enable),
    .i_reset(i_reset | crc_reset),

    .i_bit(crc_in),
    .i_input_strobe(crc_in_stb),
    .o_crc(crc_out)
);

crc32 fcs_inst (
    .i_clock(i_clock),
    .i_crc_en(i_enable & fcs_enable),
    .i_reset(i_reset | fcs_reset),
    .i_data_in(byte_reversed),
    .o_crc_out(pkt_fcs)
);

phy_len_calculation phy_len_calculation_inst(
    .i_clock(i_clock),
    .i_reset(i_reset_without_watchdog | o_long_preamble_detected),
    .i_enable(),

    .i_state(o_state),
    .i_old_state(old_state),
    .i_num_bits_to_decode(num_bits_to_decode),
    .i_pkt_rate(o_pkt_rate),//bit [7] 1 means ht; 0 means non-ht
    
    .o_n_ofdm_sym(o_n_ofdm_sym),//max 20166 = (22+65535*8)/26
    .o_n_bit_in_last_sym(n_bit_in_last_sym_tmp),//max ht ndbps 260
    .o_phy_len_valid(o_phy_len_valid)
);

always @(posedge i_clock) begin
    if (i_reset) begin
        o_status_code <= E_OK;
        o_state <= S_WAIT_POWER_TRIGGER;
        old_state <= 0;

        sync_short_reset <= 0;

        sync_long_reset <= 0;
        sync_long_enable <= 0;

        o_byte_count <= 0;
        o_byte_count_total <= 0;

        o_demod_is_ongoing <= 0;
        o_pkt_begin <= 0;
        o_pkt_ht <= 0;
        o_pkt_header_valid <= 0;
        o_pkt_header_valid_strobe <= 0;
        o_ht_unsupport <= 0;

        rot_eq_count <= 0;
        normal_eq_count <= 0;
        abs_eq_i <= 0;
        abs_eq_q <= 0;

        do_descramble <= 0;
        num_bits_to_decode <= 0;
        short_gi <= 0;
        o_pkt_rate <= 0;

        equalizer_reset <= 0;
        equalizer_enable <= 0;
        ht_next <= 0;

        pkt_len_rem <= 0;
        mpdu_del_crc <= 0;
        mpdu_pad <= 0;
        o_pkt_len <= 0;
        o_pkt_len_total <= 0;

        ofdm_reset <= 0;
        ofdm_enable <= 0;
        ofdm_in_stb <= 0;
        ofdm_in_i <= 0;
        ofdm_in_q <= 0;

        sample_count <= 0;

        sync_long_out_count <= 0;

        signal_bits <= 0;
        o_legacy_sig_stb <= 0;

        o_ht_sig1 <= 0;
        o_ht_sig2 <= 0;
        crc_in_stb <= 0;
        crc_in <= 0;
        crc_count <= 0;
        crc_reset <= 0;
        o_ht_sig_crc_ok <= 0;
        o_ht_sig_stb <= 0;
        o_ht_aggr_last <= 0;

        o_fcs_out_strobe <= 0;
        o_fcs_ok <= 0;
    end else if (i_enable) begin
        old_state <= o_state;

        case(o_state)
            S_WAIT_POWER_TRIGGER: begin
                sync_short_reset <= 0;

                o_pkt_begin <= 0;
                o_pkt_ht <= 0;
                crc_reset <= 0;
                short_gi <= 0;
                o_demod_is_ongoing <= 0;
                sync_long_enable <= 0;
                equalizer_enable <= 0;
                ofdm_enable <= 0;
                ofdm_reset <= 0;
                o_pkt_len_total <= 16'hffff;
                o_ht_sig1 <= 0;
                o_ht_sig2 <= 0;
                pkt_len_rem <= 0;

                if (o_power_trigger) begin
                    `ifdef DEBUG_PRINT
                        $display("Power triggered.");
                    `endif
                    // sync_short_reset <= 1;
                    o_state <= S_SYNC_SHORT;
                end
            end

            S_SYNC_SHORT: begin

                if (~o_power_trigger) begin
                    // power level drops before finding STS
                    o_state <= S_WAIT_POWER_TRIGGER;
                    sync_short_reset <= 1;
                end

                if (o_short_preamble_detected) begin
                    `ifdef DEBUG_PRINT
                        $display("Short preamble detected");
                    `endif
                    sync_long_reset <= 1;
                    sync_long_enable <= 1;
                    sample_count <= 0;
                    o_state <= S_SYNC_LONG;
                end
                
            end

            S_SYNC_LONG: begin
                if (sync_long_reset) begin
                    sync_long_reset <= 0;
                end

                if (i_sample_in_strobe) begin
                    sample_count <= sample_count + 1;
                end
                if (sample_count > 320) begin
                    o_state <= S_WAIT_POWER_TRIGGER;
                    sync_short_reset <= 1;
                end

                if (~o_power_trigger) begin
                    o_state <= S_WAIT_POWER_TRIGGER;
                    sync_short_reset <= 1;
                end

                if (o_long_preamble_detected) begin
                    o_demod_is_ongoing <= 1;
                    o_pkt_rate <= {1'b0, 3'b0, 4'b1011};
                    do_descramble <= 0;
                    num_bits_to_decode <= 24;

                    ofdm_reset <= 1;
                    ofdm_enable <= 1;

                    equalizer_enable <= 1;
                    equalizer_reset <= 1;

                    o_byte_count <= 0;
                    o_byte_count_total <= 0;
                    o_state <= S_DECODE_SIGNAL;
                    sync_short_reset <= 1;
                end
            end

            S_DECODE_SIGNAL: begin
                sync_short_reset <= 0;
                ofdm_reset <= 0;

                if (equalizer_reset) begin
                    equalizer_reset <= 0;
                end

                ofdm_in_stb <= o_equalizer_out_strobe;
                ofdm_in_i <= eq_out_i;
                ofdm_in_q <= eq_out_q;

                if (o_byte_out_strobe) begin
                    signal_bits <= {o_byte_out, signal_bits[23:8]};
                    o_byte_count <= o_byte_count + 1;
                    o_byte_count_total <= o_byte_count_total + 1;
                end

                if (o_byte_count == 3) begin
                    o_byte_count <= 0;
                    `ifdef DEBUG_PRINT
                        $display("[SIGNAL] rate = %04b, ", o_legacy_rate,
                            "length = %012b (%d), ", o_legacy_len, o_legacy_len,
                            "parity = %b, ", o_legacy_sig_parity,
                            "tail = %6b", o_legacy_sig_tail);
                    `endif

                    num_bits_to_decode <= (22+(o_legacy_len<<3));
                    o_pkt_rate <= {1'b0, 3'b0, o_legacy_rate};
                    o_pkt_len <= o_legacy_len;
                    o_pkt_len_total <= o_legacy_len+3;
                    
                    ofdm_reset <= 1;
                    o_state <= S_CHECK_SIGNAL;
                end
            end

            S_CHECK_SIGNAL: begin
                if (~o_legacy_sig_parity_ok) begin
                    o_pkt_header_valid_strobe <= 1;
                    o_status_code <= E_PARITY_FAIL;
                    o_state <= S_SIGNAL_ERROR;
                end else if (o_legacy_sig_rsvd) begin
                    o_pkt_header_valid_strobe <= 1;
                    o_status_code <= E_WRONG_RSVD;
                    o_state <= S_SIGNAL_ERROR;
                end else if (|o_legacy_sig_tail) begin
                    o_pkt_header_valid_strobe <= 1;
                    o_status_code <= E_WRONG_TAIL;
                    o_state <= S_SIGNAL_ERROR;
                end else if (o_legacy_rate[3]==0) begin
                    o_pkt_header_valid_strobe <= 1;
                    o_status_code <= E_UNSUPPORTED_RATE;
                    o_state <= S_SIGNAL_ERROR;
                end else begin
                    o_legacy_sig_stb <= 1;
                    o_status_code <= E_OK;
                    if (o_legacy_rate == 4'b1011) begin
                        abs_eq_i <= 0;
                        abs_eq_q <= 0;
                        rot_eq_count <= 0;
                        normal_eq_count <= 0;
                        o_state <= S_DETECT_HT;
                    end else begin
                        //num_bits_to_decode <= (o_legacy_len+3)<<4;
                        do_descramble <= 1;
                        o_pkt_header_valid <= 1;
                        o_pkt_header_valid_strobe <= 1;
                        o_pkt_begin <= 1;
                        o_state <= S_DECODE_DATA;
                    end
                end
            end

            S_SIGNAL_ERROR: begin
                o_pkt_header_valid_strobe <= 0;
                o_byte_count <= 0;
                o_byte_count_total <= 0;
                o_state <= S_WAIT_POWER_TRIGGER;
            end

            S_DETECT_HT: begin
                o_legacy_sig_stb <= 0;
                ofdm_reset <= 0;
                
                ofdm_in_stb <= eq_out_stb_delayed;
                // rotate clockwise by 90 degree
                ofdm_in_i <= eq_out_q_delayed;
                ofdm_in_q <= ~eq_out_i_delayed+1;

                if (o_equalizer_out_strobe) begin
                    abs_eq_i <= eq_out_i[15]? ~eq_out_i+1: eq_out_i;
                    abs_eq_q <= eq_out_q[15]? ~eq_out_q+1: eq_out_q;
                    if (abs_eq_q >= abs_eq_i) begin // Add "=" to prevent o_state stuck. Push to S_HT_SIGNAL and hope there is error
                        rot_eq_count <= rot_eq_count + 1;
                    end else if (abs_eq_q < abs_eq_i) begin
                        normal_eq_count <= normal_eq_count + 1;
                    end
                end

                if (rot_eq_count >= 4) begin
                    // HT-SIG detected
                    num_bits_to_decode <= 48;
                    do_descramble <= 0;
                    o_state <= S_HT_SIGNAL;
                end else if (normal_eq_count > 4) begin
                    //num_bits_to_decode <= (o_legacy_len+3)<<4;
                    do_descramble <= 1;
                    o_pkt_header_valid <= 1;
                    o_pkt_header_valid_strobe <= 1;
                    o_pkt_begin <= 1;
                    o_state <= S_DECODE_DATA;
                end
            end

            S_HT_SIGNAL: begin
                ofdm_reset <= 0;

                ofdm_in_stb <= eq_out_stb_delayed;
                // rotate clockwise by 90 degree
                ofdm_in_i <= eq_out_q_delayed;
                ofdm_in_q <= ~eq_out_i_delayed+1;

                if (o_byte_out_strobe) begin
                    if (o_byte_count < 3) begin
                        o_ht_sig1 <= {o_byte_out, o_ht_sig1[23:8]};
                    end else begin
                        o_ht_sig2 <= {o_byte_out, o_ht_sig2[23:8]};
                    end
                    o_byte_count <= o_byte_count + 1;
                    o_byte_count_total <= o_byte_count_total + 1;
                end

                if (o_byte_count == 6) begin
                    o_byte_count <= 0;
                    `ifdef DEBUG_PRINT
                        $display("[HT SIGNAL] mcs = %07b (%d), ", o_ht_mcs, o_ht_mcs,
                            "CBW: %d, ", o_ht_cbw? 40: 20,
                            "length = %012b (%d), ", o_ht_len, o_ht_len,
                            "rsvd = %d, ", ht_rsvd,
                            "aggr = %d, ", o_ht_aggr,
                            "aggr_last = %d, ", o_ht_aggr_last,
                            "stbd = %02b, ", o_ht_stbc,
                            "fec = %d, ", o_ht_fec_coding,
                            "sgi = %d, ", o_ht_sgi,
                            "num_ext = %d, ", o_ht_num_ext,
                            "crc = %08b, ", crc,
                            "tail = %06b", ht_sig_tail);
                    `endif

                    num_bits_to_decode <= (22+(o_ht_len<<3));
                    o_pkt_rate <= {1'b1, o_ht_mcs};
                    pkt_len_rem <= o_ht_len;
                    o_pkt_len <= o_ht_len;
                    o_pkt_len_total <= o_ht_len+3+6; //(6 bytes for 3 byte HT-SIG1 and 3 byte HT-SIG2)

                    crc_count <= 0;
                    crc_reset <= 1;
                    crc_in_stb <= 0;
                    o_ht_sig_crc_ok <= 0;
                    o_state <= S_CHECK_HT_SIG_CRC;
                end
            end

            S_CHECK_HT_SIG_CRC: begin
                ofdm_reset <= 1;
                crc_reset <= 0;
                crc_count <= crc_count + 1;

                if (crc_count < 24) begin
                    crc_in_stb <= 1;
                    crc_in <= o_ht_sig1[crc_count];
                end else if (crc_count < 34) begin
                    crc_in_stb <= 1;
                    crc_in <= o_ht_sig2[crc_count-24];
                end else if (crc_count == 34) begin
                    crc_in_stb <= 0;
                end else if (crc_count == 35) begin
                    o_ht_sig_stb <= 1;
                    o_pkt_ht <= 1;
                    if (crc_out ^ crc) begin
                        o_pkt_header_valid_strobe <= 1;
                        o_status_code <= E_WRONG_CRC;
                        o_state <= S_HT_SIG_ERROR;
                    end else begin
                        `ifdef DEBUG_PRINT
                            $display("[HT SIGNAL] CRC OK");
                        `endif
                        o_ht_sig_crc_ok <= 1;
                        o_state <= S_CHECK_HT_SIG;
                    end
                end
            end

            S_CHECK_HT_SIG: begin
                ofdm_reset <= 1;
                o_ht_sig_stb <= 0;
                o_ht_aggr_last <= 0;

                if (o_ht_mcs > 7) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_UNSUPPORTED_MCS;
                    o_state <= S_HT_SIG_ERROR;
                end else if (o_ht_cbw) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_UNSUPPORTED_CBW;
                    o_state <= S_HT_SIG_ERROR;
                end else if (ht_rsvd == 0) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_HT_WRONG_RSVD;
                    o_state <= S_HT_SIG_ERROR;
                end else if (o_ht_stbc != 0) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_UNSUPPORTED_STBC;
                    o_state <= S_HT_SIG_ERROR;
                end else if (o_ht_fec_coding) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_UNSUPPORTED_FEC;
                    o_state <= S_HT_SIG_ERROR;
                // end else if (o_ht_sgi) begin // seems like it supports ht short_gi, we should proceed
                //     o_ht_unsupport <= 1;
                //     o_status_code <= E_UNSUPPORTED_SGI;
                //     o_state <= S_HT_SIG_ERROR;
                end else if (o_ht_num_ext != 0) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_UNSUPPORTED_SPATIAL;
                    o_state <= S_HT_SIG_ERROR;
                end else if (ht_sig_tail != 0) begin
                    o_ht_unsupport <= 1;
                    o_status_code <= E_HT_WRONG_TAIL;
                    o_state <= S_HT_SIG_ERROR;
                end else begin
                    sync_long_out_count <= 0;
                    // When decoding 80211n packets, a lower i_clock running platform (i.e. zedboard @ 100MHz) will spend more than 4usec to decode an entire OFDM symbol.
                    // This creates misalignment between the control o_state and the actual decoding process since a feedback mechanism is not applied.
                    // By the time the 1st OFDM DATA symbol is being decoded, the control is in HT-LTS o_state and the equalizer module mistakenly calculates the channel gain.
                    // A quick fix for this is to bypass the HT-STS symbol to re-establish the alignment. Afterall, HT-STS is not used in this module.
                    if (num_ofdm_symbol == 5) begin
                        o_state <= S_HT_STS;
                    end else begin
                        ht_next <= 1;
                        o_state <= S_HT_LTS;
                    end
                end
            end

            S_HT_SIG_ERROR: begin
                o_ht_unsupport <= 0;
                o_pkt_header_valid <= 0;
                o_pkt_header_valid_strobe <= 0;
                o_byte_count <= 0;
                o_byte_count_total <= 0;
                o_ht_sig_stb <= 0;
                o_state <= S_WAIT_POWER_TRIGGER;
            end

            S_HT_STS: begin
                if (o_sync_long_out_strobe) begin
                    sync_long_out_count <= sync_long_out_count + 1;
                end
                if (sync_long_out_count == 64) begin
                    sync_long_out_count <= 0;
                    ht_next <= 1;
                    o_state <= S_HT_LTS;
                end
            end

            S_HT_LTS: begin
                short_gi <= o_ht_sgi;
                if (o_sync_long_out_strobe) begin
                    sync_long_out_count <= sync_long_out_count + 1;
                end
                if (sync_long_out_count == 64) begin
                    ht_next <= 0;
                    //num_bits_to_decode <= (o_ht_len+3)<<4;
                    do_descramble <= 1;
                    ofdm_reset <= 1;
                    if(o_ht_aggr) begin
                        crc_reset <= 1;
                        crc_count <= 0;
                        o_state <= S_MPDU_DELIM;
                    end else begin
                        o_pkt_header_valid <= 1;
                        o_pkt_header_valid_strobe <= 1;
                        o_pkt_begin <= 1;
                        pkt_len_rem <= 0;
                        o_state <= S_DECODE_DATA;
                    end
                end
            end

            S_MPDU_DELIM: begin

                crc_reset <= 0;
                ofdm_reset <= 0;

                ofdm_in_stb <= eq_out_stb_delayed;
                ofdm_in_i <= eq_out_i_delayed;
                ofdm_in_q <= eq_out_q_delayed;

                if(o_byte_out_strobe) begin

                    if(o_byte_count == 3) begin

                        o_byte_count <= 0;
                        o_byte_count_total <= 3+6;
                        if(crc_out == mpdu_del_crc && o_byte_out == 8'h4e) begin

                            // Jump over an empty MPDU delimiter
                            if(o_pkt_len == 0) begin
                                pkt_len_rem <= pkt_len_rem - 4;
                                crc_reset <= 1;
                                crc_count <= 0;
                                o_state <= S_MPDU_DELIM;

                            // Start actual packet decoding
                            end else begin
                                o_pkt_header_valid <= 1;
                                o_pkt_header_valid_strobe <= 1;
                                o_pkt_len_total <= o_pkt_len+3+6;
                                o_pkt_begin <= 1;
                                o_state <= S_DECODE_DATA;

                                // All MPDUs except last one does include padding
                                if((pkt_len_rem-o_pkt_len-mpdu_pad) > 4) begin
                                    o_ht_aggr_last <= 0;
                                    pkt_len_rem <= pkt_len_rem - (4 + o_pkt_len + mpdu_pad);
                                end else begin
                                    o_ht_aggr_last <= 1;
                                    pkt_len_rem <= 0;
                                end
                            end

                        // MPDU delimiter is erroneous and remaining packet length is less than 8. Stop searching
                        end else if(|pkt_len_rem[15:3] == 0) begin

                            o_ht_aggr_last <= 1;
                            o_fcs_out_strobe <= 1;
                            o_fcs_ok <= 0;
                            o_status_code <= E_HT_AMPDU_ERROR;
                            o_state <= S_DECODE_DONE;

                        // Else, restart searching
                        end else begin
                            pkt_len_rem <= pkt_len_rem - 4;
                            crc_reset <= 1;
                            crc_count <= 0;
                            o_status_code <= E_HT_AMPDU_WARN;
                            o_state <= S_MPDU_DELIM;
                        end

                    end else begin
                        o_byte_count <= o_byte_count + 1;
                        o_byte_count_total <= o_byte_count_total + 1;
                        if(o_byte_count == 0) begin
                            o_pkt_len[3:0] <= o_byte_out[7:4];
                        end else if(o_byte_count == 1) begin
                            o_pkt_len[11:4] <= o_byte_out;
                        end else if(o_byte_count == 2) begin
                            o_pkt_len[15:12] <= 0;
                            mpdu_del_crc <= o_byte_out;
                            if(o_pkt_len[1:0] == 0)
                                mpdu_pad <= 0;
                            else if(o_pkt_len[1:0] == 1)
                                mpdu_pad <= 3;
                            else if(o_pkt_len[1:0] == 2)
                                mpdu_pad <= 2;
                            else
                                mpdu_pad <= 1;
                        end

                        // i_enable CRC calculation on the first two bytes
                        if(crc_count[4] == 0) begin
                            crc_in <= o_byte_out[crc_count[2:0]];
                            crc_in_stb <= 1;
                            crc_count <= crc_count + 1;
                        end else begin
                            crc_in_stb <= 0;
                        end
                    end

                // i_enable CRC calculation on the first two bytes
                end else if((^o_byte_count[1:0] == 1) && (|crc_count[2:0] == 1)) begin
                    crc_in <= o_byte_out[crc_count[2:0]];
                    crc_in_stb <= 1;
                    crc_count <= crc_count + 1;

                end else begin
                    crc_in_stb <= 0;
                end
            end

            S_DECODE_DATA: begin
                o_pkt_begin <= 0;
                o_legacy_sig_stb <= 0;

                o_pkt_header_valid <= 0;
                o_pkt_header_valid_strobe <= 0;

                ofdm_reset <= 0;

                ofdm_in_stb <= eq_out_stb_delayed;
                ofdm_in_i <= eq_out_i_delayed;
                ofdm_in_q <= eq_out_q_delayed;

                if (o_byte_out_strobe) begin
                    `ifdef DEBUG_PRINT
                        $display("[BYTE] [%4d / %-4d] %02x", o_byte_count+1, o_pkt_len,
                            o_byte_out);
                    `endif
                    o_byte_count <= o_byte_count + 1;
                    o_byte_count_total <= o_byte_count_total + 1;
                end

                if (o_byte_count >= o_pkt_len) begin
                    o_fcs_out_strobe <= 1;
                    o_byte_count <= 0;
                    o_byte_count_total <= 0;
                    if (pkt_fcs == EXPECTED_FCS) begin
                        o_fcs_ok <= 1;
                        o_status_code <= E_OK;
                    end else begin
                        o_fcs_ok <= 0;
                        o_status_code <= E_WRONG_FCS;
                    end

                    // restart the decoding process on remaining MPDUs
                    if(|pkt_len_rem[15:2] == 1) begin
                        o_state <= S_MPDU_PAD;
                    end else begin
                        o_state <= S_DECODE_DONE;
                    end
                end
            end

            S_MPDU_PAD: begin
                o_fcs_out_strobe <= 0;
                o_fcs_ok <= 0;

                ofdm_in_stb <= eq_out_stb_delayed;
                ofdm_in_i <= eq_out_i_delayed;
                ofdm_in_q <= eq_out_q_delayed;

                if (o_byte_out_strobe)
                    mpdu_pad <= mpdu_pad - 1;

                if (mpdu_pad == 0) begin
                    crc_reset <= 1;
                    crc_count <= 0;
                    o_state <= S_MPDU_DELIM;
                end
            end

            S_DECODE_DONE: begin
                `ifdef DEBUG_PRINT
                    $display("===== PACKET DECODE DONE =====");
                    if (o_status_code == E_OK) begin
                        $display("FCS CORRECT");
                    end else begin
                        $display("FCS WRONG");
                    end
                `endif
                o_ht_aggr_last <= 0;
                o_fcs_out_strobe <= 0;
                o_fcs_ok <= 0;
                o_state <= S_WAIT_POWER_TRIGGER;
            end

            default: begin
                o_byte_count <= 0;
                o_byte_count_total <= 0;
                o_state <= S_WAIT_POWER_TRIGGER;
            end
        endcase
    end
end

endmodule

