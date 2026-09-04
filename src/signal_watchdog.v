// Xianjun jiao. putaoshu@msn.com; xianjun.jiao@imec.be;
`include "openofdm_rx_pre_def.v"

`ifdef OPENOFDM_RX_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

module signal_watchdog
#(
  parameter integer IQ_DATA_WIDTH	= 16,
  parameter integer COUNTER_WIDTH = 22,
  parameter LOG2_SUM_LEN = 6
)
(
  input clk,
  input rstn,
  input enable,

  input signed [(IQ_DATA_WIDTH-1):0] i_data,
  input signed [(IQ_DATA_WIDTH-1):0] q_data,
  input iq_valid,

  input power_trigger,

  input [15:0] signal_len,
  input sig_valid,

  input [15:0] min_signal_len_th,
  input [15:0] max_signal_len_th,
  input signed [(LOG2_SUM_LEN+2-1):0] dc_running_sum_th,

  // equalizer monitor: the normalized constellation shoud not be too small (like only has 1 or 2 bits effective)
  input wire equalizer_monitor_enable,
  input wire [5:0] small_eq_out_counter_th,
  `DEBUG_PREFIX input wire [4:0] state,
  `DEBUG_PREFIX input wire [31:0] equalizer,
  `DEBUG_PREFIX input wire equalizer_valid,

  `DEBUG_PREFIX input wire signed [15:0] phase_offset,
  `DEBUG_PREFIX input wire long_preamble_detected,
  `DEBUG_PREFIX input wire [16:0] phase_offset_abs_th,

  `DEBUG_PREFIX input  wire [2:0]  event_selector,
  `DEBUG_PREFIX output reg  [(COUNTER_WIDTH-1):0] event_counter,
  // from arm. capture reg write to clear the corresponding counter
  input wire slv_reg_wren_signal,
  input wire [4:0] axi_awaddr_core,

  `DEBUG_PREFIX output receiver_rst
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
  `DEBUG_PREFIX wire receiver_rst_pulse;

  `DEBUG_PREFIX wire equalizer_monitor_enable_internal;
  `DEBUG_PREFIX wire [15:0] eq_out_i;
  `DEBUG_PREFIX wire [15:0] eq_out_q;
  `DEBUG_PREFIX reg [15:0] abs_eq_i;
  `DEBUG_PREFIX reg [15:0] abs_eq_q;
  `DEBUG_PREFIX reg [5:0] small_abs_eq_i_counter;
  `DEBUG_PREFIX reg [5:0] small_abs_eq_q_counter;
  `DEBUG_PREFIX wire equalizer_monitor_rst;

  `DEBUG_PREFIX wire signed [16:0] phase_offset_sign_ext;
  `DEBUG_PREFIX wire [16:0] phase_offset_abs;
  `DEBUG_PREFIX reg sync_short_phase_offset_monitor_rst;

  `DEBUG_PREFIX wire event0;
  `DEBUG_PREFIX wire event1;
  `DEBUG_PREFIX wire event2;
  `DEBUG_PREFIX wire event3;
  `DEBUG_PREFIX wire event4;
	reg event0_delay;
	reg event1_delay;
	reg event2_delay;
	reg event3_delay;
	reg event4_delay;
  reg [COUNTER_WIDTH-1 : 0] counter0;
	reg [COUNTER_WIDTH-1 : 0] counter1;
	reg [COUNTER_WIDTH-1 : 0] counter2;
	reg [COUNTER_WIDTH-1 : 0] counter3;
	reg [COUNTER_WIDTH-1 : 0] counter4;
	wire counter0_rst;
	wire counter1_rst;
	wire counter2_rst;
	wire counter3_rst;
	wire counter4_rst;

  assign phase_offset_sign_ext = {phase_offset[15], phase_offset};
  assign phase_offset_abs = ((phase_offset_sign_ext[16]==1'b1)?(-phase_offset_sign_ext):(phase_offset_sign_ext));

  assign i_sign = (i_data == 0? fake_non_dc_in_case_all_zero : (i_data[(IQ_DATA_WIDTH-1)] ? -1 : 1) );
  assign q_sign = (q_data == 0? fake_non_dc_in_case_all_zero : (q_data[(IQ_DATA_WIDTH-1)] ? -1 : 1) );

  assign running_sum_result_i_abs = (running_sum_result_i[LOG2_SUM_LEN+2-1]?(-running_sum_result_i):running_sum_result_i);
  assign running_sum_result_q_abs = (running_sum_result_q[LOG2_SUM_LEN+2-1]?(-running_sum_result_q):running_sum_result_q);

  assign receiver_rst_internal = (running_sum_result_i_abs>=dc_running_sum_th || running_sum_result_q_abs>=dc_running_sum_th);

  assign receiver_rst_pulse = (receiver_rst_internal&&(~receiver_rst_reg));

  assign equalizer_monitor_enable_internal = (equalizer_monitor_enable && (state == S_DECODE_SIGNAL));
  assign eq_out_i = equalizer[31:16];
  assign eq_out_q = equalizer[15:0];

  assign equalizer_monitor_rst = ( (small_abs_eq_i_counter>=small_eq_out_counter_th) && (small_abs_eq_q_counter>=small_eq_out_counter_th) );

  assign event0 = sync_short_phase_offset_monitor_rst;
  assign event1 = equalizer_monitor_rst;
  assign event2 = receiver_rst_reg;
  assign event3 = (sig_valid && signal_len<min_signal_len_th);
  assign event4 = (sig_valid && signal_len>max_signal_len_th);
  assign receiver_rst = ( enable & power_trigger & ( event0 | event1 | event2 | event3 | event4 ) );

	assign counter0_rst = ((~rstn)|(slv_reg_wren_signal==1 && axi_awaddr_core==30 && event_selector==0));//slv_reg30 wr and event 0 is selected
	assign counter1_rst = ((~rstn)|(slv_reg_wren_signal==1 && axi_awaddr_core==30 && event_selector==1));//slv_reg30 wr and event 1 is selected
	assign counter2_rst = ((~rstn)|(slv_reg_wren_signal==1 && axi_awaddr_core==30 && event_selector==2));//slv_reg30 wr and event 2 is selected
	assign counter3_rst = ((~rstn)|(slv_reg_wren_signal==1 && axi_awaddr_core==30 && event_selector==3));//slv_reg30 wr and event 3 is selected
	assign counter4_rst = ((~rstn)|(slv_reg_wren_signal==1 && axi_awaddr_core==30 && event_selector==4));//slv_reg30 wr and event 4 is selected

  // event selector
  always @* begin
    case (event_selector)
      3'd0 : begin
        event_counter = counter0;
        end
      3'd1 : begin
        event_counter = counter1;
        end
      3'd2 : begin
        event_counter = counter2;
        end
      3'd3 : begin
        event_counter = counter3;
        end
      3'd4 : begin
        event_counter = counter4;
        end
      default: begin
        event_counter = counter0;
        end
    endcase
  end

  // abnormal signal monitor
  always @(posedge clk) begin
    if (~rstn) begin
      receiver_rst_reg <= 0;
      fake_non_dc_in_case_all_zero <= 1;
    end else begin
      receiver_rst_reg <= receiver_rst_internal;
      if (iq_valid) begin
        if (fake_non_dc_in_case_all_zero == 1) begin
          fake_non_dc_in_case_all_zero <= -1;
        end else begin
          fake_non_dc_in_case_all_zero <= 1;
        end
      end
    end
  end

  running_sum_dual_ch #(.DATA_WIDTH0(2), .DATA_WIDTH1(2), .LOG2_SUM_LEN(LOG2_SUM_LEN)) signal_watchdog_running_sum_inst (
    .clk(clk),
    .rstn(rstn),

    .data_in0(i_sign),
    .data_in1(q_sign),
    .data_in_valid(iq_valid),
    .running_sum_result0(running_sum_result_i),
    .running_sum_result1(running_sum_result_q),
    .data_out_valid()
  );

  // equalizer monitor
  always @(posedge clk) begin
    if (~equalizer_monitor_enable_internal) begin
      small_abs_eq_i_counter <= 0;
      small_abs_eq_q_counter <= 0;
      abs_eq_i <= 0;
      abs_eq_q <= 0;
    end else begin
      if (equalizer_valid) begin
        abs_eq_i <= eq_out_i[15]? ~eq_out_i+1: eq_out_i;
        abs_eq_q <= eq_out_q[15]? ~eq_out_q+1: eq_out_q;
        small_abs_eq_i_counter <= (abs_eq_i<=2?(small_abs_eq_i_counter+1):small_abs_eq_i_counter);
        small_abs_eq_q_counter <= (abs_eq_q<=2?(small_abs_eq_q_counter+1):small_abs_eq_q_counter);
      end
    end
  end

  // sync short phase offset monitor
  always @(posedge clk) begin
    if (~rstn) begin
      sync_short_phase_offset_monitor_rst <= 0;
    end else begin
      sync_short_phase_offset_monitor_rst <= (long_preamble_detected?(phase_offset_abs>phase_offset_abs_th):0);
    end
  end

  // event counter
  always @(posedge clk) begin
  if (counter0_rst) begin
    counter0 <= 0;
    event0_delay <= 0;
  end else begin
    event0_delay <= event0;
    if (event0==1 && event0_delay==0) begin
      counter0 <= counter0 + 1;
    end
  end
  end

  always @(posedge clk) begin
  if (counter1_rst) begin
    counter1 <= 0;
    event1_delay <= 0;
  end else begin
    event1_delay <= event1;
    if (event1==1 && event1_delay==0) begin
      counter1 <= counter1 + 1;
    end
  end
  end
  
  always @(posedge clk) begin
  if (counter2_rst) begin
    counter2 <= 0;
    event2_delay <= 0;
  end else begin
    event2_delay <= event2;
    if (event2==1 && event2_delay==0) begin
      counter2 <= counter2 + 1;
    end
  end
  end
  
  always @(posedge clk) begin
  if (counter3_rst) begin
    counter3 <= 0;
    event3_delay <= 0;
  end else begin
    event3_delay <= event3;
    if (event3==1 && event3_delay==0) begin
      counter3 <= counter3 + 1;
    end
  end
  end
  
  always @(posedge clk) begin
  if (counter4_rst) begin
    counter4 <= 0;
    event4_delay <= 0;
  end else begin
    event4_delay <= event4;
    if (event4==1 && event4_delay==0) begin
      counter4 <= counter4 + 1;
    end
  end
  end

endmodule
