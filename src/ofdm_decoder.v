module ofdm_decoder
(
  input clock,
  input enable,
  input reset,

  input       reset_dot11,
  input [4:0] state,
  input [4:0] old_state,

  input [31:0] sample_in,
  input sample_in_strobe,
  input soft_decoding,
  input soft_bits_method,

  // decode instructions
  input [7:0] rate,
  input do_descramble,
  input [19:0] num_bits_to_decode, //4bits + ht_len: num_bits_to_decode <= (22+(ht_len<<3));

  input [31:0] csi,
  input csi_valid,
  input [31:0] noise_var,
  input noise_var_valid,

  output reg bit_in,
  output reg bit_in_stb,

  output [5:0] demod_out,
  output [17:0] demod_soft_bits,
  output demod_out_strobe,

  output [7:0] deinterleave_erase_out,
  output deinterleave_erase_out_strobe,

  output conv_decoder_out,
  output conv_decoder_out_stb,

  output descramble_out,
  output descramble_out_strobe,

  output [7:0] byte_out,
  output byte_out_strobe
);

`include "common_params.v"

reg conv_in_stb, conv_in_stb_dly, do_descramble_dly;
wire conv_in_stb_auto_zero_while_not_enable; // to avoid conv decoder continue working during this module disable
reg [2:0] conv_in0, conv_in0_dly;
reg [2:0] conv_in1, conv_in1_dly;
reg [1:0] conv_erase, conv_erase_dly;

wire [15:0] input_i = sample_in[31:16];
wire [15:0] input_q = sample_in[15:0];

wire [(31-7):0] noise_var_new; //25bit. Matlab: noise_var_new = floor(noise_var/128);
wire        csi_square_valid;
wire [31:0] csi_square;
wire [31:0] csi_square_raw;
wire [33:0] csi_square_scaled;

wire [33:0] csi_square_over_noise_var;
wire        csi_square_over_noise_var_valid;
wire [35:0] csi_square_over_noise_var_full;

wire [33:0] csi_square_over_noise_var_for_write;
wire [33:0] csi_square_over_noise_var_for_llr;
wire        csi_square_over_noise_var_write_enable;
reg  [5:0]  csi_square_over_noise_var_write_addr;
wire [7:0]  csi_square_over_noise_var_read_addr;

wire        csi_square_over_noise_var_write_reset;

// wire vit_ce = reset | (enable & conv_in_stb) | conv_in_stb_dly; //Seems new viter decoder IP core does not need this complicated CE signal
wire vit_ce = 1'b1 ; //Need to be 1 to avoid the viterbi decoder freezing issue on adrv9364z7020 (demod_is_ongoing always high. dot11 stuck at state 3)
wire vit_clr = reset;
// reg vit_clr_dly;
wire vit_rdy;

wire [5:0] deinterleave_out;
wire deinterleave_out_strobe;
wire [1:0] erase;

wire m_axis_data_tvalid;

reg [3:0] skip_bit;
wire bit_in_stb_auto_zero_while_not_enable;

reg [19:0] deinter_out_count; // bitwidth same as num_bits_to_decode
//reg flush;

assign noise_var_new = (noise_var[31:7] == 0? 1 : noise_var[31:7]); //25bit. Matlab: noise_var_new = floor(noise_var/128);
// noise_var_new = floor(noise_var/128);
// if noise_var_new == 0
//   noise_var_new = 1;
// end

assign csi_square = {csi_square_raw[30:0], 1'd0}; // csi_square = 2*floor(real(new_lts .* conj(new_lts))/2); % Follow the way CSI^2 is calculated on FPGA.
assign csi_square_scaled = {csi_square, 2'd0}; // 34bit. csi_square.*4 in matlab use_llr_soft_bit == 5 in bit_true_ofdm_decoder.m
assign csi_square_over_noise_var = csi_square_over_noise_var_full[35:2]; //34bit. remove the 2 fractional bits from full 36bit. now it is fix(csi_square.*4./noise_var_new);

assign csi_square_over_noise_var_write_reset = ( (state == S_DECODE_SIGNAL && old_state == S_SYNC_LONG) || (old_state == S_CHECK_HT_SIG && state > S_CHECK_HT_SIG) );

// assign conv_decoder_out_stb = vit_ce & vit_rdy;
assign conv_decoder_out_stb = m_axis_data_tvalid; // vit_rdy was used as data valid in the old version of the core, which is no longer the case 
assign deinterleave_erase_out = {erase,deinterleave_out};
assign deinterleave_erase_out_strobe = deinterleave_out_strobe;

assign csi_square_over_noise_var_for_write = csi_square_over_noise_var;
assign csi_square_over_noise_var_write_enable = csi_square_over_noise_var_valid;

assign conv_in_stb_auto_zero_while_not_enable = (enable? conv_in_stb : 0); // avoid stay high during disable
assign bit_in_stb_auto_zero_while_not_enable = (enable? bit_in_stb : 0); // avoid stay high during disable

// calculate csi_square/noise_var and store for further steps
// partially from Colvin's csi_calc.v
complex_to_mag_sq csi_square_inst (
  .clock(clock),
  .enable(1),
  .reset(reset_dot11|csi_square_over_noise_var_write_reset),

  .i(csi[31:16]),
  .q(csi[15:0]),
  .input_strobe(csi_valid), 
  .mag_sq(csi_square_raw),
  .mag_sq_strobe(csi_square_valid)
);
div_gen_csi_over_nova div_gen_csi_over_nova_inst (
  .aclk(clock),
  .s_axis_divisor_tvalid(csi_square_valid),
  .s_axis_divisor_tdata(noise_var_new), //25bit
  .s_axis_dividend_tvalid(csi_square_valid),
  .s_axis_dividend_tdata(csi_square_scaled), //34bit
  .m_axis_dout_tvalid(csi_square_over_noise_var_valid),
  .m_axis_dout_tdata(csi_square_over_noise_var_full) //36bit
);
dpram #(.DATA_WIDTH(34), .ADDRESS_WIDTH(6)) lts_inst (
  .clock(clock),
  .reset(reset_dot11),
  .enable_a(1),
  .write_enable(csi_square_over_noise_var_write_enable),
  .write_address(csi_square_over_noise_var_write_addr),
  .write_data(csi_square_over_noise_var_for_write),
  .read_data_a(),
  .enable_b(1),
  .read_address(csi_square_over_noise_var_read_addr[5:0]),
  .read_data(csi_square_over_noise_var_for_llr)
);

demodulate demod_inst (
  .clock(clock),
  .reset(reset),
  .enable(enable),

  .rate(rate),
  .cons_i(input_i),
  .cons_q(input_q),
  .input_strobe(sample_in_strobe),

  .soft_bits_method(soft_bits_method),

  .csi_square_over_noise_var_read_addr(csi_square_over_noise_var_read_addr),
  .csi_square_over_noise_var_for_llr(csi_square_over_noise_var_for_llr),
  
  .bits_output(demod_out),
  .soft_bits(demod_soft_bits),
  .output_strobe(demod_out_strobe)
);

deinterleave deinterleave_inst (
  .clock(clock),
  .reset(reset),
  .enable(enable),

  .reset_dot11(reset_dot11),

  .rate(rate),
  .in_bits(demod_out),
  .soft_in_bits(demod_soft_bits),
  .input_strobe(demod_out_strobe),
  .soft_decoding(soft_decoding),

  .out_bits(deinterleave_out),
  .output_strobe(deinterleave_out_strobe),
  .erase(erase)
);
/*
viterbi_v7_0 viterbi_inst (
  .clk(clock),
  .ce(vit_ce),
  .sclr(vit_clr),
  .data_in0(conv_in0),
  .data_in1(conv_in1),
  .erase(conv_erase),
  .rdy(vit_rdy),
  .data_out(conv_decoder_out)
);
*/
//reg [4:0] idle_wire_5bit ;
wire [6:0] idle_wire_7bit; 
viterbi_v7_0 viterbi_inst (
  .aclk(clock),                              // input wire aclk
  .aresetn(~vit_clr),                        // input wire aresetn
  .aclken(vit_ce),                          // input wire aclken
  .s_axis_data_tdata({5'b0,conv_in1_dly,5'b0,conv_in0_dly}),    // input wire [15 : 0] s_axis_data_tdata
  .s_axis_data_tuser({6'b0,conv_erase_dly}),    // input wire [7 : 0] s_axis_data_tuser
  .s_axis_data_tvalid(conv_in_stb_dly),  // input wire s_axis_data_tvalid
  .s_axis_data_tready(vit_rdy),  // output wire s_axis_data_tready
  .m_axis_data_tdata({idle_wire_7bit, conv_decoder_out}),    // output wire [7 : 0] m_axis_data_tdata
  .m_axis_data_tvalid(m_axis_data_tvalid)  // output wire m_axis_data_tvalid
);

descramble decramble_inst (
  .clock(clock),
  .enable(enable),
  .reset(reset),
  
  .in_bit(conv_decoder_out),
  .input_strobe(conv_decoder_out_stb),

  .out_bit(descramble_out),
  .output_strobe(descramble_out_strobe)
);

bits_to_bytes byte_inst (
  .clock(clock),
  .enable(enable),
  .reset(reset),

  .bit_in(bit_in),
  .input_strobe(bit_in_stb_auto_zero_while_not_enable),

  .byte_out(byte_out),
  .output_strobe(byte_out_strobe)
);

// store csi_square_over_noise_var to dpram
always @(posedge clock) begin
  if (reset_dot11|csi_square_over_noise_var_write_reset) begin
    csi_square_over_noise_var_write_addr <= 0;
  end else begin
    csi_square_over_noise_var_write_addr <= (csi_square_over_noise_var_write_enable ? (csi_square_over_noise_var_write_addr+1) : csi_square_over_noise_var_write_addr);
  end
end

always @(posedge clock) begin
  if (reset) begin
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
  end else if (enable) begin
    if (deinterleave_out_strobe) begin
      deinter_out_count <= deinter_out_count + 1;
    end //else begin
      // wait for finishing deinterleaving current symbol
      // only do flush for non-DATA bits, such as SIG and HT-SIG, which
      // are not scrambled
      //if (~do_descramble && deinter_out_count >= num_bits_to_decode) begin
      //if (deinter_out_count >= num_bits_to_decode) begin // careful! deinter_out_count is only correct from 6M ~ 48M! under 54M, it should be 2*216, but actual value is 288!
          //flush <= 1;
      //end
    //end
    //if (!flush) begin
    if (!(deinter_out_count >= num_bits_to_decode)) begin
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
        bit_in <= conv_decoder_out;
        bit_in_stb <= conv_decoder_out_stb;
      end else begin
        bit_in <= descramble_out;
        if (descramble_out_strobe) begin
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
// TODO: this is only a temp solution, as tready only rise one clock after ce goes high, delay statically by one clock, in future should take into account tready
always @(posedge clock) begin
  conv_in1_dly <= conv_in1;
  conv_in0_dly <= conv_in0;
  conv_erase_dly <= conv_erase;
  conv_in_stb_dly <= conv_in_stb_auto_zero_while_not_enable;
  do_descramble_dly <= do_descramble;
end

endmodule
