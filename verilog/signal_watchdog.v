//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: signal_watchdog
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

`include "openofdm_rx_pre_def.v"

`ifdef OPENOFDM_RX_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

module signal_watchdog
#(
    parameter integer IQ_DATA_WIDTH	= 16,
    parameter LOG2_SUM_LEN = 6
)
(
    input i_clk,
    input i_rstn,
    input i_enable,

    input signed [(IQ_DATA_WIDTH-1):0] i_data,
    input signed [(IQ_DATA_WIDTH-1):0] q_data,
    input i_iq_valid,

    input i_power_trigger,

    input [15:0] i_signal_len,
    input i_sig_valid,

    input [15:0] i_min_signal_len_th,
    input [15:0] i_max_signal_len_th,
    input signed [(LOG2_SUM_LEN+2-1):0] i_dc_running_sum_th,

    // i_equalizer monitor: the normalized constellation shoud not be too small (like only has 1 or 2 bits effective)
    input wire i_equalizer_monitor_enable,
    input wire [5:0] i_small_eq_out_counter_th,
    `DEBUG_PREFIX input wire [4:0] i_state,
		`DEBUG_PREFIX input wire [31:0] i_equalizer,
		`DEBUG_PREFIX input wire i_equalizer_valid,

    `DEBUG_PREFIX output o_receiver_rst
);
`include "common_params.v"

    wire signed [1:0] i_sign;
    wire signed [1:0] q_sign;
    reg  signed [1:0] fake_non_dc_in_case_all_zero;
    wire signed [(LOG2_SUM_LEN+2-1):0] running_sum_result_i;
    wire signed [(LOG2_SUM_LEN+2-1):0] running_sum_result_q;
    `DEBUG_PREFIX wire signed [(LOG2_SUM_LEN+2-1):0] running_sum_result_i_abs;
    `DEBUG_PREFIX wire signed [(LOG2_SUM_LEN+2-1):0] running_sum_result_q_abs;

    `DEBUG_PREFIX wire receiver_rst_internal;
    `DEBUG_PREFIX reg receiver_rst_reg;
    //`DEBUG_PREFIX wire receiver_rst_pulse;

    `DEBUG_PREFIX wire equalizer_monitor_enable_internal;
    `DEBUG_PREFIX wire [15:0] eq_out_i;
    `DEBUG_PREFIX wire [15:0] eq_out_q;
    `DEBUG_PREFIX reg [15:0] abs_eq_i;
    `DEBUG_PREFIX reg [15:0] abs_eq_q;
    `DEBUG_PREFIX reg [5:0] small_abs_eq_i_counter;
    `DEBUG_PREFIX reg [5:0] small_abs_eq_q_counter;
    `DEBUG_PREFIX wire equalizer_monitor_rst;

    assign i_sign = (i_data == 0? fake_non_dc_in_case_all_zero : (i_data[(IQ_DATA_WIDTH-1)] ? -1 : 1) );
    assign q_sign = (q_data == 0? fake_non_dc_in_case_all_zero : (q_data[(IQ_DATA_WIDTH-1)] ? -1 : 1) );

    assign running_sum_result_i_abs = (running_sum_result_i[LOG2_SUM_LEN+2-1]?(-running_sum_result_i):running_sum_result_i);
    assign running_sum_result_q_abs = (running_sum_result_q[LOG2_SUM_LEN+2-1]?(-running_sum_result_q):running_sum_result_q);

    assign receiver_rst_internal = (i_enable&(running_sum_result_i_abs>=i_dc_running_sum_th || running_sum_result_q_abs>=i_dc_running_sum_th));

    //assign receiver_rst_pulse = (receiver_rst_internal&&(~receiver_rst_reg));

    assign equalizer_monitor_enable_internal = (i_equalizer_monitor_enable && (i_state == S_DECODE_SIGNAL));
    assign eq_out_i = i_equalizer[31:16];
    assign eq_out_q = i_equalizer[15:0];

    assign equalizer_monitor_rst = ( (small_abs_eq_i_counter >= i_small_eq_out_counter_th) && (small_abs_eq_q_counter >= i_small_eq_out_counter_th) );

    assign o_receiver_rst = ( i_power_trigger & ( equalizer_monitor_rst | receiver_rst_reg | (i_sig_valid && (i_signal_len<i_min_signal_len_th || i_signal_len>i_max_signal_len_th)) ) );

    // abnormal signal monitor
    always @(posedge i_clk) begin
      if (~i_rstn) begin
        receiver_rst_reg <= 0;
        fake_non_dc_in_case_all_zero <= 1;
      end else begin
        receiver_rst_reg <= receiver_rst_internal;
        if (i_iq_valid) begin
          if (fake_non_dc_in_case_all_zero == 1) begin
            fake_non_dc_in_case_all_zero <= -1;
          end else begin
            fake_non_dc_in_case_all_zero <= 1;
          end
        end
      end
    end

    running_sum_dual_ch #(.DATA_WIDTH0(2), .DATA_WIDTH1(2), .LOG2_SUM_LEN(LOG2_SUM_LEN)) signal_watchdog_running_sum_inst (
      .i_clock(i_clk),
      .i_nreset(i_rstn),

      .i_data_in0(i_sign),
      .i_data_in1(q_sign),
      .i_data_in_valid(i_iq_valid),
      
      .o_running_sum_result0(running_sum_result_i),
      .o_running_sum_result1(running_sum_result_q),
      .o_data_out_valid()
    );

    // i_equalizer monitor
    always @(posedge i_clk) begin
      if (~equalizer_monitor_enable_internal) begin
        small_abs_eq_i_counter <= 0;
        small_abs_eq_q_counter <= 0;
        abs_eq_i <= 0;
        abs_eq_q <= 0;
      end else begin
        if (i_equalizer_valid) begin
          abs_eq_i <= eq_out_i[15]? ~eq_out_i+1: eq_out_i;
          abs_eq_q <= eq_out_q[15]? ~eq_out_q+1: eq_out_q;
          small_abs_eq_i_counter <= (abs_eq_i<=2?(small_abs_eq_i_counter+1):small_abs_eq_i_counter);
          small_abs_eq_q_counter <= (abs_eq_q<=2?(small_abs_eq_q_counter+1):small_abs_eq_q_counter);
        end
      end
    end

endmodule

