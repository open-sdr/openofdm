`timescale 1ns/1ps

`include "openofdm_rx_pre_def.v"

module dot11_tb;

`include "common_params.v"

`ifdef BETTER_SENSITIVITY
`define THRESHOLD_SCALE 1
`else
`define THRESHOLD_SCALE 0
`endif

reg clock;
reg reset;
reg enable;

reg [10:0] rssi_half_db;
reg[31:0] sample_in;
reg [15:0] Fc_in_MHz;
reg sample_in_strobe;
reg [15:0] clk_count;

wire pkt_header_valid;
wire pkt_header_valid_strobe;
wire [15:0] pkt_len;

reg set_stb;
reg [7:0] set_addr;
reg [31:0] set_data;
// registers to comtain metadata used for HE decoding
reg [10:0] sta_id_to_decode;
reg tb_disambiguity;
reg [1:0] tb_pre_fec_padding_factor;
reg [3:0] tb_he_mcs;
reg [3:0] tb_ru_idx;
reg [1:0] tb_ru_width_i;
reg [1:0] tb_gi_he_ltf;

wire demod_is_ongoing;
wire receiver_rst;

wire sig_valid = (pkt_header_valid_strobe&pkt_header_valid);


wire [4:0] state;
wire signal_watchdog_enable;

wire short_preamble_detected;
wire long_preamble_detected;
wire signed [15:0] phase_offset_for_reg_read;

wire [31:0] equalizer;
wire equalizer_valid;

wire fcs_out_strobe;
wire fcs_ok;
  
integer run_out_of_iq_sample;
integer iq_count, iq_count_tmp, end_dl_count;

// file descriptors 
integer sample_file_name_fd;

// integer bb_sample_fd;
// integer power_trigger_fd;
integer short_preamble_detected_fd;

integer long_preamble_detected_fd;
integer sync_long_out_fd;

integer demod_csi_square_over_noise_var_fd;
integer demod_raw_llr_fd;
integer demod_raw_llr_mult_csi_square_over_noise_var_fd;
integer demod_raw_llr_mult_csi_square_over_noise_var_reduce_fd;
// integer demod_llr_quant_threshold_fd;

integer demod_out_fd;
integer demod_soft_bits_fd;
// integer demod_soft_bits_pos_fd;
integer deinterleave_erase_out_fd;
integer conv_out_fd;
integer descramble_out_fd;

integer signal_fd;
integer ht_sig_fd; 

integer byte_out_fd;
integer fcs_out_fd;
integer status_code_fd;

integer phy_len_fd;

// sync_short 
integer mag_sq_fd;
integer mag_sq_avg_fd;
integer prod_fd;
integer prod_avg_fd;
integer phase_in_fd;
integer phase_out_fd;
integer delay_prod_avg_mag_fd;

// sync_long
integer sum_fd;
integer metric_fd;
integer sync_long_prod_fd;
integer sync_long_prod_avg_fd;
integer sync_long_phase_out_fd;
integer raw_fd;
integer phase_correction_fd;
integer next_phase_correction_fd;
integer fft_in_fd;

// equalizer
integer new_lts_fd;
integer phase_offset_pilot_input_fd;
integer phase_offset_lts_input_fd;
integer phase_offset_pilot_fd;
//integer phase_offset_pilot_sum_fd;
//integer phase_offset_phase_out_fd;
integer cpe_fd;
integer lvpe_fd;
integer sxy_fd; 
integer peg_after_fft_fd;
integer scaled_phase_fd;
integer prev_peg_fd; 
integer peg_sym_scale_fd;
integer peg_pilot_scale_fd;
integer rot_in_fd;
integer rot_out_fd;
integer equalizer_prod_fd;
integer equalizer_prod_scaled_fd;
integer equalizer_mag_sq_fd;
integer equalizer_out_fd;

// Bit-true comparison of viterbi decoder input
integer vit_in_fd;

integer file_i, file_q, file_rssi_half_db, iq_sample_file;

integer result, dummy;
reg [100*8-1:0] string;

assign signal_watchdog_enable = (state <= S_DECODE_SIGNAL);

reg [15:0] s_packet_cnt = 0;
initial begin
  // $dumpfile("dot11.vcd");
  // $dumpvars;
  sample_file_name_fd = $fopen("./sample_file_name.txt", "w");
  $fwrite(sample_file_name_fd, "%s", `SAMPLE_FILE); 
  $fflush(sample_file_name_fd);
  $fclose(sample_file_name_fd);
  
  run_out_of_iq_sample = 0;
  end_dl_count = 0;

  clock = 0;
  reset = 1;
  enable = 0;

  # 86 reset = 0;
  enable = 1;

  set_stb = 1;

  # 20
  // do not skip sample
  set_addr = SR_SKIP_SAMPLE;
  set_data = 0;

  # 20 set_stb = 0;
end

integer file_open_trigger = 0;
always @(posedge clock) begin
  file_open_trigger = file_open_trigger + 1;
  if (file_open_trigger==1) begin
    iq_sample_file = $fopen(`SAMPLE_FILE, "r");
    // bb_sample_fd = $fopen("./sample_in.txt", "w");
    // power_trigger_fd = $fopen("./power_trigger.txt", "w");
    short_preamble_detected_fd = $fopen("./short_preamble_detected.txt", "w");
    long_preamble_detected_fd = $fopen("./sync_long_frame_detected.txt", "w");
    
    // sync_short 
    mag_sq_fd = $fopen("./mag_sq.txt", "w");
    mag_sq_avg_fd = $fopen("./mag_sq_avg.txt", "w");
    prod_fd = $fopen("./prod.txt", "w");
    prod_avg_fd = $fopen("./prod_avg.txt", "w");
    phase_in_fd = $fopen("./phase_in.txt", "w");
    phase_out_fd = $fopen("./phase_out.txt", "w");
    delay_prod_avg_mag_fd = $fopen("./delay_prod_avg_mag.txt", "w");

    // sync_long
    sum_fd = $fopen("./sum.txt", "w");
    metric_fd = $fopen("./metric.txt", "w");
    raw_fd = $fopen("./raw.txt", "w");
    phase_correction_fd = $fopen("./phase_correction.txt", "w");
    sync_long_prod_fd = $fopen("./sync_long_prod.txt","w");
    sync_long_prod_avg_fd = $fopen("./sync_long_prod_avg.txt","w");
    sync_long_phase_out_fd = $fopen("./sync_long_phase_out.txt","w");
    next_phase_correction_fd = $fopen("./next_phase_correction.txt", "w");
    fft_in_fd = $fopen("./fft_in.txt", "w");                   
    sync_long_out_fd = $fopen("./sync_long_out.txt", "w");
    
    // equalizer
    new_lts_fd = $fopen("./new_lts.txt", "w");
    phase_offset_pilot_input_fd = $fopen("./phase_offset_pilot_input.txt", "w");
    phase_offset_lts_input_fd = $fopen("./phase_offset_lts_input.txt", "w");
    phase_offset_pilot_fd = $fopen("./phase_offset_pilot.txt", "w");
    //phase_offset_pilot_sum_fd = $fopen("./phase_offset_pilot_sum.txt", "w");
    //phase_offset_phase_out_fd = $fopen("./phase_offset_phase_out.txt", "w");
    cpe_fd = $fopen("./cpe.txt", "w");
    //lvpe_fd = $fopen("./lvpe.txt", "w");
    //sxy_fd = $fopen("./sxy.txt", "w");
    peg_after_fft_fd = $fopen("./peg_after_fft.txt","w");
    scaled_phase_fd = $fopen("./scaled_phase.txt","w");
    //prev_peg_fd = $fopen("./prev_peg.txt", "w");
    //peg_sym_scale_fd = $fopen("./peg_sym_scale.txt", "w");
    //peg_pilot_scale_fd = $fopen("./peg_pilot_scale.txt", "w");
    rot_in_fd = $fopen("./rot_in.txt", "w");
    rot_out_fd = $fopen("./rot_out.txt", "w");
    equalizer_prod_fd = $fopen("./equalizer_prod.txt", "w");
    equalizer_prod_scaled_fd = $fopen("./equalizer_prod_scaled.txt", "w");
    equalizer_mag_sq_fd = $fopen("./equalizer_mag_sq.txt", "w");
    equalizer_out_fd = $fopen("./equalizer_out.txt", "w");        

    // ofdm decoder
    demod_csi_square_over_noise_var_fd = $fopen("./demod_csi_square_over_noise_var.txt", "w");
    demod_raw_llr_fd = $fopen("./demod_raw_llr.txt", "w");
    demod_raw_llr_mult_csi_square_over_noise_var_fd = $fopen("./demod_raw_llr_mult_csi_square_over_noise_var.txt", "w");
    demod_raw_llr_mult_csi_square_over_noise_var_reduce_fd = $fopen("./demod_raw_llr_mult_csi_square_over_noise_var_reduce.txt", "w");
    // demod_llr_quant_threshold_fd = $fopen("./demod_llr_quant_threshold.txt", "w");

    demod_out_fd = $fopen("./demod_out.txt", "w");
    demod_soft_bits_fd = $fopen("./demod_soft_bits.txt", "w");
    // demod_soft_bits_pos_fd = $fopen("./demod_soft_bits_pos.txt", "w");
    deinterleave_erase_out_fd = $fopen("./deinterleave_erase_out.txt", "w");
    conv_out_fd = $fopen("./conv_out.txt", "w");
    descramble_out_fd = $fopen("./descramble_out.txt", "w");

    signal_fd = $fopen("./signal_out.txt", "w");
    ht_sig_fd = $fopen("./ht_sig_out.txt", "w");
    byte_out_fd = $fopen("./byte_out.txt", "w");
    fcs_out_fd = $fopen("./fcs_out.txt", "w");
    status_code_fd = $fopen("./status_code.txt","w");

    phy_len_fd = $fopen("./phy_len.txt", "w");

    // Bit-true soft bits 
    vit_in_fd = $fopen("./conv_vit_sb_in.txt", "w");

  end
end

always begin
`ifdef CLK_SPEED_100M
  #5 clock = !clock;
`elsif CLK_SPEED_200M
  #2.5 clock = !clock;
`elsif CLK_SPEED_240M
  #2.0833333333 clock = !clock;
`elsif CLK_SPEED_400M
  #1.25 clock = !clock;
`endif
end

always @(posedge clock) begin
  if (reset) begin
    sample_in <= 0;
    clk_count <= 0;
    sample_in_strobe <= 0;
    iq_count <= 0;
    s_packet_cnt <= 0;
  end else if (enable) begin
    `ifdef CLK_SPEED_100M
    if (clk_count == 4) begin  // for 100M; 100/20 = 5
    `elsif CLK_SPEED_200M
    if (clk_count == 9) begin // for 200M; 200/20 = 10
    `elsif CLK_SPEED_240M
    if (clk_count == 11) begin // for 200M; 240/20 = 12
    `elsif CLK_SPEED_400M
    if (clk_count == 19) begin // for 200M; 400/20 = 20
    `endif
      // sample_in_strobe <= 1;
      // $fscanf(iq_sample_file, "%d %d %d", file_i, file_q, file_rssi_half_db);
      result = $fgets(string, iq_sample_file);
      if (result == 0) begin
        run_out_of_iq_sample = 1;
      end
      iq_count_tmp = $sscanf(string, "%d %d %d", file_i, file_q, dummy);
      if (iq_count_tmp != 2) begin
        // Get decode info for TB
        iq_count_tmp = $sscanf(string, "%d %d %d %d %d %d %d %d", sta_id_to_decode, tb_disambiguity, tb_pre_fec_padding_factor, tb_he_mcs, tb_ru_idx, tb_ru_width_i, tb_gi_he_ltf, Fc_in_MHz);
        // Continue with sample already on this clock cycle
        result = $fgets(string, iq_sample_file);
        iq_count_tmp = $sscanf(string, "%d %d %d", file_i, file_q, dummy);
      end
      sample_in[15:0] <= file_q;
      sample_in[31:16]<= file_i;             
      // rssi_half_db <= file_rssi_half_db;
      rssi_half_db <= 0;
      iq_count <= iq_count + 1;
      clk_count <= 0;
    end else begin
      // sample_in_strobe <= 0;
      clk_count <= clk_count + 1;
    end
    
    // for finer sample_in_strobe phase control
    if (clk_count == 4) begin
      sample_in_strobe <= 1;
    end else begin
      sample_in_strobe <= 0;
    end
    
    if (dot11_inst.legacy_sig_stb) begin
    end

    //if (sample_in_strobe && power_trigger) begin
    if (sample_in_strobe) begin
      // $fwrite(bb_sample_fd, "%d %d %d\n", iq_count, $signed(sample_in[31:16]), $signed(sample_in[15:0]));
      // $fwrite(power_trigger_fd, "%d %d\n", iq_count, dot11_inst.power_trigger);
      // $fflush(bb_sample_fd);
      // $fflush(power_trigger_fd);

      if ((iq_count % 100) == 0) begin
        // $display("%d", iq_count);
      end

      if (run_out_of_iq_sample) begin
        end_dl_count = end_dl_count+1;
      end
      
      if(end_dl_count == 300 ) begin
        $fclose(iq_sample_file);

        // $fclose(bb_sample_fd);
        // $fclose(power_trigger_fd);
        $fclose(short_preamble_detected_fd);
        $fclose(long_preamble_detected_fd);
        
        // close short preamble detection output files
        $fclose(mag_sq_fd);
        $fclose(mag_sq_avg_fd);
        $fclose(prod_fd);
        $fclose(prod_avg_fd);
        $fclose(phase_in_fd);
        $fclose(phase_out_fd);
        $fclose(delay_prod_avg_mag_fd);
        // close long preamble detection output files
        $fclose(sum_fd);
        $fclose(metric_fd);
        $fclose(sync_long_prod_fd);
        $fclose(sync_long_prod_avg_fd);
        $fclose(sync_long_phase_out_fd);
        $fclose(raw_fd);
        $fclose(phase_correction_fd);
        $fclose(next_phase_correction_fd);
        $fclose(fft_in_fd);
        $fclose(sync_long_out_fd);
        // close equalizer output files
        $fclose(new_lts_fd);
        $fclose(phase_offset_pilot_input_fd);
        $fclose(phase_offset_lts_input_fd);
        $fclose(phase_offset_pilot_fd);
        //$fclose(phase_offset_pilot_sum_fd);
        //$fclose(phase_offset_phase_out_fd);
        $fclose(cpe_fd);
        //$fclose(lvpe_fd);
        //$fclose(sxy_fd);
        $fclose(peg_after_fft_fd);
        $fclose(scaled_phase_fd);
        //$fclose(prev_peg_fd);
        //$fclose(peg_sym_scale_fd);
        //$fclose(peg_pilot_scale_fd);
        $fclose(rot_in_fd);
        $fclose(rot_out_fd);
        $fclose(equalizer_prod_fd);
        $fclose(equalizer_prod_scaled_fd);
        $fclose(equalizer_mag_sq_fd);
        $fclose(equalizer_out_fd);
        // close ofdm decode files
        $fclose(demod_csi_square_over_noise_var_fd);
        $fclose(demod_raw_llr_fd);
        $fclose(demod_raw_llr_mult_csi_square_over_noise_var_fd);
        $fclose(demod_raw_llr_mult_csi_square_over_noise_var_reduce_fd);
        // $fclose(demod_llr_quant_threshold_fd);
        $fclose(demod_out_fd);
        $fclose(demod_soft_bits_fd);
        // $fclose(demod_soft_bits_pos_fd);
        $fclose(deinterleave_erase_out_fd);
        $fclose(conv_out_fd);
        $fclose(descramble_out_fd);

        $fclose(signal_fd);
        $fclose(ht_sig_fd);
        $fclose(byte_out_fd);
        $fclose(fcs_out_fd);
        $fclose(status_code_fd);

        $fclose(vit_in_fd); // compare soft bits viterbi decoder input   

        $fclose(phy_len_fd);
        $finish;
      end
    end
    if(dot11_inst.short_preamble_detected && dot11_inst.state == S_SYNC_SHORT) begin
      $fwrite(short_preamble_detected_fd, "%d\n", iq_count);
      $fflush(short_preamble_detected_fd);
    end
    if(dot11_inst.long_preamble_detected) begin
      $fwrite(long_preamble_detected_fd, "%d %d %d\n", iq_count, dot11_inst.sync_long_inst.addr1, dot11_inst.sync_long_inst.ltf_phase_offset);
      $fflush(long_preamble_detected_fd);
    end
    if(dot11_inst.fcs_out_strobe) begin
      $fwrite(fcs_out_fd, "%d %d\n", iq_count, dot11_inst.fcs_ok);
      $fflush(fcs_out_fd);
      s_packet_cnt <= s_packet_cnt + 1;
    end
    if(dot11_inst.fcs_out_strobe && dot11_inst.phy_len_valid) begin
      $fwrite(phy_len_fd, "%d %d %d\n", iq_count, dot11_inst.n_ofdm_sym, dot11_inst.n_bit_in_last_sym);
      $fflush(phy_len_fd);
    end
    if(dot11_inst.state == S_HT_SIG_ERROR || dot11_inst.state == S_SIGNAL_ERROR) begin
      $fwrite(status_code_fd, "%d %d %d\n", iq_count, dot11_inst.status_code, dot11_inst.state);
      $fflush(status_code_fd);    
    end
    if (dot11_inst.state == S_CHECK_SIGNAL) begin
      $fwrite(signal_fd, "%d %d\n", iq_count, dot11_inst.signal_bits);
      $fflush(signal_fd);
    end
    if (dot11_inst.ht_sig_stb) begin
      $fwrite(ht_sig_fd, "%d %d %d\n", iq_count, dot11_inst.ht_sig1, dot11_inst.ht_sig2);
      $fflush(ht_sig_fd);
    end

    if (dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_strobe && dot11_inst.demod_is_ongoing && dot11_inst.ofdm_decoder_inst.reset==0) begin
      $fwrite(demod_csi_square_over_noise_var_fd,"%d %d\n", iq_count, 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.csi_square_over_noise_var_for_llr_delay1);
      $fwrite(demod_raw_llr_fd, "%d %d %d %d %d %d %d\n",   iq_count, 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i[0], 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i[1], 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i[2], 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q[0], 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q[1], 
                                                            dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q[2]);
      $fflush(demod_csi_square_over_noise_var_fd);
      $fflush(demod_raw_llr_fd);
    end
    if (dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_mult_csi_square_over_noise_var_strobe && dot11_inst.demod_is_ongoing && dot11_inst.ofdm_decoder_inst.reset==0) begin
      $fwrite(demod_raw_llr_mult_csi_square_over_noise_var_fd, "%d %d %d %d %d %d %d\n", iq_count, 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var[0], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var[1], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var[2], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var[0], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var[1], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var[2]);
      $fwrite(demod_raw_llr_mult_csi_square_over_noise_var_reduce_fd, "%d %d %d %d %d %d %d\n", iq_count, 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var_reduce[0], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var_reduce[1], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_i_mult_csi_square_over_noise_var_reduce[2], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var_reduce[0], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var_reduce[1], 
                                                                                          dot11_inst.ofdm_decoder_inst.demod_inst.raw_llr_q_mult_csi_square_over_noise_var_reduce[2]);
      // $fwrite(demod_llr_quant_threshold_fd, "%d %d %d %d %d %d %d %d\n",                 iq_count, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold1, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold2, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold3, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold4, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold5, 
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold6,
      //                                                                                    dot11_inst.ofdm_decoder_inst.demod_inst.threshold7);
      // $fflush(demod_llr_quant_threshold_fd);
      $fflush(demod_raw_llr_mult_csi_square_over_noise_var_fd);
      $fflush(demod_raw_llr_mult_csi_square_over_noise_var_reduce_fd);
    end

    // if ((dot11_inst.state == S_MPDU_DELIM || dot11_inst.state == S_DECODE_DATA || dot11_inst.state == S_MPDU_PAD) && dot11_inst.ofdm_decoder_inst.demod_out_strobe) begin
    if (dot11_inst.ofdm_decoder_inst.demod_out_strobe && dot11_inst.demod_is_ongoing && dot11_inst.ofdm_decoder_inst.reset==0) begin
      $fwrite(demod_out_fd, "%d %b %b %b %b %b %b\n",iq_count, dot11_inst.ofdm_decoder_inst.demod_out[0],dot11_inst.ofdm_decoder_inst.demod_out[1],dot11_inst.ofdm_decoder_inst.demod_out[2],dot11_inst.ofdm_decoder_inst.demod_out[3],dot11_inst.ofdm_decoder_inst.demod_out[4],dot11_inst.ofdm_decoder_inst.demod_out[5]);
      $fwrite(demod_soft_bits_fd, "%d %d %d %d %d %d %d\n",iq_count, dot11_inst.ofdm_decoder_inst.demod_soft_bits[2:0],dot11_inst.ofdm_decoder_inst.demod_soft_bits[5:3],dot11_inst.ofdm_decoder_inst.demod_soft_bits[8:6],dot11_inst.ofdm_decoder_inst.demod_soft_bits[11:9],dot11_inst.ofdm_decoder_inst.demod_soft_bits[14:12],dot11_inst.ofdm_decoder_inst.demod_soft_bits[17:15]);
      // $fwrite(demod_soft_bits_pos_fd, "%d %b %b %b %b\n",iq_count, dot11_inst.ofdm_decoder_inst.demod_soft_bits_pos[0],dot11_inst.ofdm_decoder_inst.demod_soft_bits_pos[1],dot11_inst.ofdm_decoder_inst.demod_soft_bits_pos[2],dot11_inst.ofdm_decoder_inst.demod_soft_bits_pos[3]);
      $fflush(demod_out_fd);
      $fflush(demod_soft_bits_fd);
      // $fflush(demod_soft_bits_pos_fd);
    end

    // if ((dot11_inst.state == S_MPDU_DELIM || dot11_inst.state == S_DECODE_DATA || dot11_inst.state == S_MPDU_PAD) && dot11_inst.deinterleave_erase_out_strobe) begin
    if (dot11_inst.deinterleave_erase_out_strobe && dot11_inst.demod_is_ongoing && dot11_inst.ofdm_decoder_inst.reset==0) begin
      // $fwrite(deinterleave_erase_out_fd, "%d %b %b %b %b %b %b %b %b\n", iq_count, dot11_inst.deinterleave_erase_out[0], dot11_inst.deinterleave_erase_out[1], dot11_inst.deinterleave_erase_out[2], dot11_inst.deinterleave_erase_out[3], dot11_inst.deinterleave_erase_out[4], dot11_inst.deinterleave_erase_out[5], dot11_inst.deinterleave_erase_out[6],  dot11_inst.deinterleave_erase_out[7]);
      $fwrite(deinterleave_erase_out_fd, "%d %d %d %d %d\n", iq_count, dot11_inst.deinterleave_erase_out[2:0], dot11_inst.deinterleave_erase_out[5:3], dot11_inst.deinterleave_erase_out[6], dot11_inst.deinterleave_erase_out[7]);
      $fflush(deinterleave_erase_out_fd);
    end

    // comparing conv out is difficult for L-SIG HT-SIG1-2 due to some deinterleaver decoder and descrambler delay
    // since byte out is compared for L-SIG HT-SIG1-2 later on, just skip conv out copmarison for L-SIG HT-SIG1-2
    if ((dot11_inst.state == S_MPDU_DELIM || dot11_inst.state == S_DECODE_DATA || dot11_inst.state == S_MPDU_PAD) && dot11_inst.conv_decoder_out_stb && dot11_inst.ofdm_decoder_inst.reset==0) begin
    // if (dot11_inst.conv_decoder_out_stb && dot11_inst.ofdm_decoder_inst.reset==0) begin
      $fwrite(conv_out_fd, "%d %b\n", iq_count, dot11_inst.conv_decoder_out);
      $fflush(conv_out_fd);
    end

    // No need to compare descramble out for L-SIG, HT-SIG1 and HT-SIG2 because they do not use it.
    if ((dot11_inst.state == S_MPDU_DELIM || dot11_inst.state == S_DECODE_DATA || dot11_inst.state == S_MPDU_PAD) && dot11_inst.descramble_out_strobe && dot11_inst.ofdm_decoder_inst.reset==0) begin
    // if (dot11_inst.descramble_out_strobe) begin
      $fwrite(descramble_out_fd, "%d %b\n", iq_count, dot11_inst.descramble_out);
      $fflush(descramble_out_fd);
    end

    if ((dot11_inst.state == S_DECODE_SIGNAL || dot11_inst.state == S_HT_SIGNAL || dot11_inst.state == S_MPDU_DELIM || dot11_inst.state == S_DECODE_DATA || dot11_inst.state == S_MPDU_PAD) && dot11_inst.byte_out_strobe && dot11_inst.ofdm_decoder_inst.reset==0) begin
    // if (dot11_inst.byte_out_strobe) begin
      $fwrite(byte_out_fd, "%d %02x\n", iq_count, dot11_inst.byte_out);
      $fflush(byte_out_fd);
    end

    // sync_short 
    if (dot11_inst.sync_short_inst.mag_sq_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
    //if (dot11_inst.sync_short_inst.mag_sq_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
      $fwrite(mag_sq_fd, "%d %d\n", iq_count, dot11_inst.sync_short_inst.mag_sq);
      $fflush(mag_sq_fd);
    end
    if (dot11_inst.sync_short_inst.mag_sq_avg_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
    //if (dot11_inst.sync_short_inst.mag_sq_avg_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
      $fwrite(mag_sq_avg_fd, "%d %d\n", iq_count, dot11_inst.sync_short_inst.mag_sq_avg);
      $fflush(mag_sq_avg_fd);
    end
    if (dot11_inst.sync_short_inst.prod_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
    //if (dot11_inst.sync_short_inst.prod_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
      $fwrite(prod_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.sync_short_inst.prod[63:32]), $signed(dot11_inst.sync_short_inst.prod[31:0]));
      $fflush(prod_fd);
    end
    if (dot11_inst.sync_short_inst.prod_avg_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
    //if (dot11_inst.sync_short_inst.prod_avg_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
      $fwrite(prod_avg_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.sync_short_inst.prod_avg[63:32]), $signed(dot11_inst.sync_short_inst.prod_avg[31:0]));
      $fflush(prod_avg_fd);
    end
//        if (dot11_inst.sync_short_inst.phase_in_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
//        //if (dot11_inst.sync_short_inst.phase_in_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
//            $fwrite(phase_in_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.sync_short_inst.phase_in_i), $signed(dot11_inst.sync_short_inst.phase_in_q));
//            $fflush(phase_in_fd);
//        end
//        if (dot11_inst.sync_short_inst.phase_out_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
//        //if (dot11_inst.sync_short_inst.phase_out_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
//            $fwrite(phase_out_fd, "%d %d\n", iq_count, $signed(dot11_inst.sync_short_inst.phase_out));
//            $fflush(phase_out_fd);
//        end
    if (dot11_inst.sync_short_inst.delay_prod_avg_mag_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset && dot11_inst.state == S_SYNC_SHORT) begin
    //if (dot11_inst.sync_short_inst.delay_prod_avg_mag_stb && dot11_inst.sync_short_inst.enable && ~dot11_inst.sync_short_inst.reset) begin
      $fwrite(delay_prod_avg_mag_fd, "%d %d\n", iq_count, dot11_inst.sync_short_inst.delay_prod_avg_mag);
      $fflush(delay_prod_avg_mag_fd);
    end

    // sync_long 
    if (dot11_inst.sync_long_inst.sum_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset) begin
      $fwrite(sum_fd, "%d %d %d\n", iq_count, dot11_inst.sync_long_inst.sum_i, dot11_inst.sync_long_inst.sum_q);
      $fflush(sum_fd);
    end
    if (dot11_inst.sync_long_inst.metric_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset) begin
      $fwrite(metric_fd, "%d %d\n", iq_count, dot11_inst.sync_long_inst.metric);
      $fflush(metric_fd);
    end
    if (dot11_inst.sync_long_inst.prod_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset) begin
      $fwrite(sync_long_prod_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.sync_long_inst.prod[63:32]), $signed(dot11_inst.sync_long_inst.prod[31:0]));
      $fflush(sync_long_prod_fd);
    end    
    if (dot11_inst.sync_long_inst.phase_in_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset) begin
      $fwrite(sync_long_prod_avg_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.sync_long_inst.phase_in_i), $signed(dot11_inst.sync_long_inst.phase_in_q));
      $fflush(sync_long_prod_avg_fd);
    end
    if (dot11_inst.sync_long_inst.phase_out_stb && dot11_inst.sync_long_inst.state > 1 && dot11_inst.state == S_SYNC_LONG && ~dot11_inst.sync_long_inst.reset) begin
      $fwrite(sync_long_phase_out_fd, "%d %d\n", iq_count, $signed(dot11_inst.sync_long_inst.phase_out));
      $fflush(sync_long_phase_out_fd);
    end
    if (dot11_inst.sync_long_inst.raw_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset && dot11_inst.sync_long_inst.state == dot11_inst.sync_long_inst.S_FFT) begin
      $fwrite(raw_fd, "%d %d %d\n", iq_count, dot11_inst.sync_long_inst.raw_i, dot11_inst.sync_long_inst.raw_q);
      $fflush(raw_fd);
      $fwrite(phase_correction_fd, "%d %d\n", iq_count, dot11_inst.sync_long_inst.phase_correction);
      $fflush(phase_correction_fd);
      $fwrite(next_phase_correction_fd, "%d %d\n", iq_count, dot11_inst.sync_long_inst.next_phase_correction);
      $fflush(next_phase_correction_fd);
    end
    if (dot11_inst.sync_long_inst.fft_in_stb && dot11_inst.sync_long_inst.enable && ~dot11_inst.sync_long_inst.reset && dot11_inst.demod_is_ongoing) begin//add demod_is_ongoing to prevent the garbage fft in after decoding is done overlap with the early sync_short of next packet
      $fwrite(fft_in_fd, "%d %d %d\n", iq_count, dot11_inst.sync_long_inst.fft_in_re_bitshift, dot11_inst.sync_long_inst.fft_in_im_bitshift);
      $fflush(fft_in_fd);
    end
    if (dot11_inst.rotafft_inst.output_strobe) begin
      $fwrite(sync_long_out_fd, "%d %d %d\n",iq_count, $signed(dot11_inst.rotafft_inst.out_fft_i), $signed(dot11_inst.rotafft_inst.out_fft_q));
      $fflush(sync_long_out_fd);
    end
    // rot after fft
    if (dot11_inst.rotafft_inst.sc_count == 63 && dot11_inst.demod_is_ongoing) begin
      $fwrite(peg_after_fft_fd, "%d %d\n", iq_count, $signed(dot11_inst.rotafft_inst.Sxy));
      $fflush(peg_after_fft_fd);
    end
    if (dot11_inst.rotafft_inst.sc_count == 63 && dot11_inst.demod_is_ongoing) begin
      $fwrite(scaled_phase_fd, "%d %d\n", iq_count, $signed(dot11_inst.rotafft_inst.scaled_phase));
      $fflush(scaled_phase_fd);
    end        
    // equalizer 
    if ((dot11_inst.equalizer_inst.num_ofdm_sym == 1 || (dot11_inst.equalizer_inst.pkt_ht==1 && dot11_inst.equalizer_inst.num_ofdm_sym==5)) && dot11_inst.equalizer_inst.state == dot11_inst.equalizer_inst.S_CPE_ESTIMATE && dot11_inst.equalizer_inst.sample_in_strobe_dly == 1 && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset) begin
      $fwrite(new_lts_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.lts_i_out, dot11_inst.equalizer_inst.lts_q_out);
      $fflush(new_lts_fd);
    end
    if (dot11_inst.equalizer_inst.pilot_in_stb && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_CPE_ESTIMATE && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(phase_offset_pilot_input_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.input_i, dot11_inst.equalizer_inst.input_q);
      $fflush(phase_offset_pilot_input_fd);
      $fwrite(phase_offset_lts_input_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.lts_i_out, dot11_inst.equalizer_inst.lts_q_out);
      $fflush(phase_offset_lts_input_fd);
    end
    if (dot11_inst.equalizer_inst.pilot_out_stb && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_CPE_ESTIMATE && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(phase_offset_pilot_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.pilot_i, dot11_inst.equalizer_inst.pilot_q);
      $fflush(phase_offset_pilot_fd);
    end
//        if (dot11_inst.equalizer_inst.phase_in_stb && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_PILOT_PE_CORRECTION && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(phase_offset_pilot_sum_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.pilot_sum_i, dot11_inst.equalizer_inst.pilot_sum_q);
//            $fflush(phase_offset_pilot_sum_fd);
//        end
//        if (dot11_inst.equalizer_inst.phase_out_stb && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_PILOT_PE_CORRECTION && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(phase_offset_phase_out_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.phase_out));
//            $fflush(phase_offset_phase_out_fd);
//        end
    if (dot11_inst.equalizer_inst.rot_in_stb && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(cpe_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.cpe));
      $fflush(cpe_fd);
    end
//        if (dot11_inst.equalizer_inst.lvpe_out_stb && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(lvpe_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.lvpe));
//            $fflush(lvpe_fd);
//        end
//        if (dot11_inst.equalizer_inst.lvpe_out_stb && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(sxy_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.Sxy));
//            $fflush(sxy_fd);
//        end
//        if (dot11_inst.equalizer_inst.num_output == dot11_inst.equalizer_inst.num_data_carrier && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_ALL_SC_PE_CORRECTION && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(prev_peg_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.prev_peg_reg));
//            $fflush(prev_peg_fd);
//        end
//        if (dot11_inst.equalizer_inst.lvpe_out_stb && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(peg_sym_scale_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.peg_sym_scale));
//            $fflush(peg_sym_scale_fd);
//        end
//        if (dot11_inst.equalizer_inst.pilot_count1 < 4 && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_PILOT_PE_CORRECTION && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
//            $fwrite(peg_pilot_scale_fd, "%d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.peg_pilot_scale));
//            $fflush(peg_pilot_scale_fd);
//        end
    if (dot11_inst.equalizer_inst.rot_in_stb && dot11_inst.equalizer_inst.enable && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_ALL_SC_PE_CORRECTION && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(rot_in_fd, "%d %d %d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.buf_i_out), $signed(dot11_inst.equalizer_inst.buf_q_out), $signed(dot11_inst.equalizer_inst.sym_phase));
      $fflush(rot_in_fd);
    end
    if (dot11_inst.equalizer_inst.rot_out_stb && dot11_inst.equalizer_inst.state==dot11_inst.equalizer_inst.S_ALL_SC_PE_CORRECTION && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      // when enable is 0, it locked equalizer all internal variables till the next reset/enable, some large delayed signal, such as rot out, logged with some garbage
      // limite the log to dot11_inst.equalizer_inst.S_ALL_SC_PE_CORRECTION state
      $fwrite(rot_out_fd, "%d %d %d\n", iq_count, dot11_inst.equalizer_inst.rot_i, dot11_inst.equalizer_inst.rot_q);
      $fflush(rot_out_fd);
    end
    if (dot11_inst.equalizer_inst.prod_out_strobe && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(equalizer_prod_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.prod_i), $signed(dot11_inst.equalizer_inst.prod_q));
      $fflush(equalizer_prod_fd);
      $fwrite(equalizer_prod_scaled_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.prod_i_scaled), $signed(dot11_inst.equalizer_inst.prod_q_scaled));
      $fflush(equalizer_prod_scaled_fd);
      $fwrite(equalizer_mag_sq_fd, "%d %d\n", iq_count, dot11_inst.equalizer_inst.mag_sq);
      $fflush(equalizer_mag_sq_fd);
    end
    if (dot11_inst.equalizer_inst.sample_out_strobe && dot11_inst.equalizer_inst.enable && ~dot11_inst.equalizer_inst.reset && dot11_inst.demod_is_ongoing) begin
      $fwrite(equalizer_out_fd, "%d %d %d\n", iq_count, $signed(dot11_inst.equalizer_inst.sample_out[31:16]), $signed(dot11_inst.equalizer_inst.sample_out[15:0]));
      $fflush(equalizer_out_fd);
    end

  end
end

signal_watchdog signal_watchdog_inst (
  .clk(clock),
  .rstn(~reset),
  // .enable(~demod_is_ongoing),
  .enable(signal_watchdog_enable),

  .i_data(sample_in[31:16]),
  .q_data(sample_in[15:0]),
  .iq_valid(sample_in_strobe),

  .power_trigger(1),

  .signal_len(pkt_len),
  .sig_valid(sig_valid),

  // // configuration for disabling
  // .min_signal_len_th(0),
  // .max_signal_len_th(16'hFFFF),
  // .dc_running_sum_th(65),

  // // configuration for normal
  .min_signal_len_th(14),
  .max_signal_len_th(1700),
  .dc_running_sum_th(64),
  
  // equalizer monitor: the normalized constellation shoud not be too small (like only has 1 or 2 bits effective)
  .equalizer_monitor_enable(1),
  .small_eq_out_counter_th(48),
  .state(state),
  .equalizer(equalizer),
  .equalizer_valid(equalizer_valid),

  // frequency offset monitor: too big fo estimated by sync_short means sth wrong
  .phase_offset(phase_offset_for_reg_read),
  .long_preamble_detected(long_preamble_detected),
  .phase_offset_abs_th(22),

  .event_selector(0),
  .event_counter(),
  .slv_reg_wren_signal(0),
  .axi_awaddr_core(0),
  
  .receiver_rst(receiver_rst)
);

dot11 dot11_inst (
  .clock(clock),
  .enable(enable),
  .reset(reset | receiver_rst),
  .reset_without_watchdog(reset),

  //.set_stb(set_stb),
  //.set_addr(set_addr),
  //.set_data(set_data),

  .power_thres(11'd0),
  .min_plateau(32'd100),
  .threshold_scale(`THRESHOLD_SCALE),
  .Fc_in_MHz(Fc_in_MHz),

  .rssi_half_db(rssi_half_db),
  .sample_in(sample_in),
  .sample_in_strobe(sample_in_strobe),
  .soft_decoding(1'b1),
  .soft_bits_method(1'b0),
  .force_ht_smoothing(1'b1),
  .disable_all_smoothing(1'b0),
  .fft_win_shift(4'd4),

  .demod_is_ongoing(demod_is_ongoing),
  .pkt_header_valid(pkt_header_valid),
  .pkt_header_valid_strobe(pkt_header_valid_strobe),
  .pkt_len(pkt_len),

  .state(state),

  // sync short
  .short_preamble_detected(short_preamble_detected),
  .phase_offset(phase_offset_for_reg_read),

  // sync long
  .long_preamble_detected(long_preamble_detected),
  .phase_offset_override_en(0),
  .phase_offset_override_val(0),

  .equalizer_out(equalizer),
  .equalizer_out_strobe(equalizer_valid),

  .fcs_out_strobe(fcs_out_strobe),
  .fcs_ok(fcs_ok)
);

/*
byte_to_word_fcs_sn_insert byte_to_word_fcs_sn_insert_inst (
  .clk(clock),
  .rstn((~reset)&(~pkt_header_valid_strobe)),

  .byte_in(byte_out),
  .byte_in_strobe(byte_out_strobe),
  .byte_count(byte_count),
  .num_byte(pkt_len),
  .fcs_in_strobe(fcs_out_strobe),
  .fcs_ok(fcs_ok),
  .rx_pkt_sn_plus_one(0),

  .word_out(word_out),
  .word_out_strobe(word_out_strobe)
);
*/

endmodule
