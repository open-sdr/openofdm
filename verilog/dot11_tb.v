`timescale 1ns/1ps

// Testbench for the dot11 receiver of the RA-Sentinel fork of openwifi/openofdm.
// Adapted from the upstream openwifi dot11_tb.v to the renamed (i_/o_ prefixed)
// port interface of this fork. All logging uses dot11 output ports instead of
// hierarchical references into renamed submodule internals.
// The upstream original is in this repository's history before commit 019cba8.
//
// Reads IQ samples from `SAMPLE_FILE (see openofdm_rx_pre_def.v) and writes
// decode results (fcs_out.txt, byte_out.txt, conv_out.txt, ...) to the
// simulation working directory.

`include "openofdm_rx_pre_def.v"

// Sample-times to keep feeding after the vector ends, so the decode pipeline
// can flush. Override with -d TB_TAIL_SAMPLES=<n> if a frame is longer still.
`ifndef TB_TAIL_SAMPLES
`define TB_TAIL_SAMPLES 3000
`endif

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
reg [31:0] sample_in;
reg sample_in_strobe;
reg [15:0] clk_count;

wire pkt_header_valid;
wire pkt_header_valid_strobe;
wire [15:0] pkt_len;

wire demod_is_ongoing;
wire receiver_rst;

wire sig_valid = (pkt_header_valid_strobe & pkt_header_valid);

wire [4:0] state;
wire signal_watchdog_enable;
wire [31:0] equalizer;
wire equalizer_valid;

// dot11 outputs used for logging
wire fcs_out_strobe;
wire fcs_ok;
wire [7:0] byte_out;
wire byte_out_strobe;
wire conv_decoder_out;
wire conv_decoder_out_stb;
wire descramble_out;
wire descramble_out_strobe;
wire [5:0] demod_out;
wire [5:0] demod_soft_bits;
wire [3:0] demod_soft_bits_pos;
wire demod_out_strobe;
wire [7:0] deinterleave_erase_out;
wire deinterleave_erase_out_strobe;
wire short_preamble_detected;
wire [15:0] phase_offset;
wire long_preamble_detected;
wire legacy_sig_stb;
wire [3:0] legacy_rate;
wire [11:0] legacy_len;
wire legacy_sig_parity_ok;
wire ht_sig_stb;
wire [6:0] ht_mcs;
wire [15:0] ht_len;
wire ht_sig_crc_ok;
wire [4:0] status_code;
wire [14:0] n_ofdm_sym;
wire [9:0] n_bit_in_last_sym;
wire phy_len_valid;

integer run_out_of_iq_sample;
integer iq_count, iq_count_tmp, end_dl_count;

// file descriptors
integer sample_file_name_fd;
integer short_preamble_detected_fd;
integer long_preamble_detected_fd;
integer demod_out_fd;
integer deinterleave_erase_out_fd;
integer conv_out_fd;
integer descramble_out_fd;
integer signal_fd;
integer ht_sig_fd;
integer byte_out_fd;
integer fcs_out_fd;
integer status_code_fd;
integer phy_len_fd;
integer equalizer_fd;

integer file_i, file_q, iq_sample_file;

assign signal_watchdog_enable = (state <= S_DECODE_SIGNAL);

// diagnostic: report state machine transitions and watchdog resets
reg [4:0] state_prev = 0;
reg receiver_rst_prev = 0;
always @(posedge clock) begin
    state_prev <= state;
    receiver_rst_prev <= receiver_rst;
    if (state != state_prev)
        $display("dot11_tb: dot11 state %0d -> %0d at iq sample %0d", state_prev, state, iq_count);
    if (receiver_rst && !receiver_rst_prev)
        $display("dot11_tb: signal_watchdog receiver_rst asserted at iq sample %0d", iq_count);
end

initial begin
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
end

integer file_open_trigger = 0;
always @(posedge clock) begin
    file_open_trigger = file_open_trigger + 1;
    if (file_open_trigger==1) begin
        iq_sample_file = $fopen(`SAMPLE_FILE, "r");

        short_preamble_detected_fd = $fopen("./short_preamble_detected.txt", "w");
        long_preamble_detected_fd = $fopen("./sync_long_frame_detected.txt", "w");

        demod_out_fd = $fopen("./demod_out.txt", "w");
        deinterleave_erase_out_fd = $fopen("./deinterleave_erase_out.txt", "w");
        conv_out_fd = $fopen("./conv_out.txt", "w");
        descramble_out_fd = $fopen("./descramble_out.txt", "w");

        signal_fd = $fopen("./signal_out.txt", "w");
        ht_sig_fd = $fopen("./ht_sig_out.txt", "w");
        byte_out_fd = $fopen("./byte_out.txt", "w");
        fcs_out_fd = $fopen("./fcs_out.txt", "w");
        status_code_fd = $fopen("./status_code.txt","w");

        phy_len_fd = $fopen("./phy_len.txt", "w");
        equalizer_fd = $fopen("./equalizer_out.txt", "w");
    end
end

    always begin
`ifdef CLK_SPEED_100M
        #5 clock = !clock;
`elsif CLK_SPEED_120M
        #4.1666666667 clock = !clock;
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
    end else if (enable) begin
        `ifdef CLK_SPEED_100M
    	if (clk_count == 4) begin  // for 100M; 100/20 = 5
    	`elsif CLK_SPEED_120M
        if (clk_count == 5) begin // for 120M; 120/20 = 6
    	`elsif CLK_SPEED_200M
        if (clk_count == 9) begin // for 200M; 200/20 = 10
        `elsif CLK_SPEED_240M
        if (clk_count == 11) begin // for 240M; 240/20 = 12
        `elsif CLK_SPEED_400M
        if (clk_count == 19) begin // for 400M; 400/20 = 20
        `endif
            iq_count_tmp = $fscanf(iq_sample_file, "%d %d", file_i, file_q);
            if (iq_count_tmp != 2)
                run_out_of_iq_sample = 1;

            sample_in[15:0] <= file_q;
            sample_in[31:16]<= file_i;
            rssi_half_db <= 0;
            iq_count <= iq_count + 1;
            clk_count <= 0;
        end else begin
            clk_count <= clk_count + 1;
        end

        // for finer sample_in_strobe phase control
        // must fire on the same edge the new sample is loaded, so that the strobe
        // is high during the FIRST clock of the new sample (downstream logic, e.g.
        // the sync_short correlator, reads i_sample_in 1-2 clocks after the strobe)
        `ifdef CLK_SPEED_100M
        if (clk_count == 4) begin
        `elsif CLK_SPEED_120M
        if (clk_count == 5) begin
        `elsif CLK_SPEED_200M
        if (clk_count == 9) begin
        `elsif CLK_SPEED_240M
        if (clk_count == 11) begin
        `elsif CLK_SPEED_400M
        if (clk_count == 19) begin
        `endif
            sample_in_strobe <= 1;
        end else begin
            sample_in_strobe <= 0;
        end

        if (sample_in_strobe) begin
            if (run_out_of_iq_sample) begin
                end_dl_count = end_dl_count+1;
            end

            /* Tail samples to keep feeding AFTER the vector runs out, so the
               decode pipeline can flush. 300 was NOT enough for a long
               high-rate frame: ag_54M_len1537 (58 OFDM symbols) decoded its
               SIGNAL correctly and emitted 1100 of 1537 bytes, then the bench
               called $finish before the last bytes and the FCS came out - it
               looked like a decoder failure at 54Mbps and was purely this
               cutoff. The vector itself is exactly 5040+300 samples, i.e. it
               has no spare tail of its own. */
            if(end_dl_count == `TB_TAIL_SAMPLES ) begin
                $fclose(iq_sample_file);

                $fclose(short_preamble_detected_fd);
                $fclose(long_preamble_detected_fd);
                $fclose(demod_out_fd);
                $fclose(deinterleave_erase_out_fd);
                $fclose(conv_out_fd);
                $fclose(descramble_out_fd);
                $fclose(signal_fd);
                $fclose(ht_sig_fd);
                $fclose(byte_out_fd);
                $fclose(fcs_out_fd);
                $fclose(status_code_fd);
                $fclose(phy_len_fd);
                $fclose(equalizer_fd);
                $display("dot11_tb: end of IQ sample file reached, finishing.");
                $finish;
            end
        end

        if(short_preamble_detected && state == S_SYNC_SHORT) begin
            $fwrite(short_preamble_detected_fd, "%d %d\n", iq_count, phase_offset);
            $fflush(short_preamble_detected_fd);
        end
        if(long_preamble_detected) begin
            $fwrite(long_preamble_detected_fd, "%d\n", iq_count);
            $fflush(long_preamble_detected_fd);
        end
        /* Equalised constellation point per subcarrier. Dumped so decode
           errors can be attributed: a channel estimate that drifts through a
           long frame looks completely different from a demapper that is wrong
           from the first symbol. */
        if(equalizer_valid) begin
            $fwrite(equalizer_fd, "%d %d %d\n", iq_count,
                    $signed(equalizer[31:16]), $signed(equalizer[15:0]));
        end
        if(fcs_out_strobe) begin
            $fwrite(fcs_out_fd, "%d %d\n", iq_count, fcs_ok);
            $fflush(fcs_out_fd);
            $display("dot11_tb: FCS check at iq sample %0d: fcs_ok = %0d", iq_count, fcs_ok);
        end
        if(fcs_out_strobe && phy_len_valid) begin
            $fwrite(phy_len_fd, "%d %d %d\n", iq_count, n_ofdm_sym, n_bit_in_last_sym);
            $fflush(phy_len_fd);
        end
        if(state == S_HT_SIG_ERROR || state == S_SIGNAL_ERROR) begin
            $fwrite(status_code_fd, "%d %d %d\n", iq_count, status_code, state);
            $fflush(status_code_fd);
        end
        if (legacy_sig_stb) begin
            $fwrite(signal_fd, "%d rate %d len %d parity_ok %d\n", iq_count, legacy_rate, legacy_len, legacy_sig_parity_ok);
            $fflush(signal_fd);
        end
        if (ht_sig_stb) begin
            $fwrite(ht_sig_fd, "%d mcs %d len %d crc_ok %d\n", iq_count, ht_mcs, ht_len, ht_sig_crc_ok);
            $fflush(ht_sig_fd);
        end

        if ((state == S_MPDU_DELIM || state == S_DECODE_DATA || state == S_MPDU_PAD) && demod_out_strobe) begin
            $fwrite(demod_out_fd, "%d %b %b %b %b %b %b\n", iq_count, demod_out[0], demod_out[1], demod_out[2], demod_out[3], demod_out[4], demod_out[5]);
            $fflush(demod_out_fd);
        end

        if ((state == S_MPDU_DELIM || state == S_DECODE_DATA || state == S_MPDU_PAD) && deinterleave_erase_out_strobe) begin
            $fwrite(deinterleave_erase_out_fd, "%d %b %b %b %b %b %b %b %b\n", iq_count, deinterleave_erase_out[0], deinterleave_erase_out[1], deinterleave_erase_out[2], deinterleave_erase_out[3], deinterleave_erase_out[4], deinterleave_erase_out[5], deinterleave_erase_out[6], deinterleave_erase_out[7]);
            $fflush(deinterleave_erase_out_fd);
        end

        if ((state == S_MPDU_DELIM || state == S_DECODE_DATA || state == S_MPDU_PAD) && conv_decoder_out_stb) begin
            $fwrite(conv_out_fd, "%d %b\n", iq_count, conv_decoder_out);
            $fflush(conv_out_fd);
        end

        if ((state == S_MPDU_DELIM || state == S_DECODE_DATA || state == S_MPDU_PAD) && descramble_out_strobe) begin
            $fwrite(descramble_out_fd, "%d %b\n", iq_count, descramble_out);
            $fflush(descramble_out_fd);
        end

        if ((state == S_MPDU_DELIM || state == S_DECODE_DATA || state == S_MPDU_PAD) && byte_out_strobe) begin
            $fwrite(byte_out_fd, "%d %02x\n", iq_count, byte_out);
            $fflush(byte_out_fd);
        end
    end
end

signal_watchdog signal_watchdog_inst (
    .i_clk(clock),
    .i_rstn(~reset),
    .i_enable(signal_watchdog_enable),

    .i_data(sample_in[31:16]),
    .q_data(sample_in[15:0]),
    .i_iq_valid(sample_in_strobe),

    .i_signal_len(pkt_len),
    .i_sig_valid(sig_valid),

    .i_power_trigger(1'b1),

    // configuration for normal operation
    .i_min_signal_len_th(16'd14),
    .i_max_signal_len_th(16'd1700),
    .i_dc_running_sum_th(8'd64),

    // equalizer monitor: the normalized constellation should not be too small
    .i_equalizer_monitor_enable(1'b1),
    .i_small_eq_out_counter_th(6'd8),
    .i_state(state),
    .i_equalizer(equalizer),
    .i_equalizer_valid(equalizer_valid),

    .o_receiver_rst(receiver_rst)
);

dot11 dot11_inst (
    .i_clock(clock),
    .i_enable(enable),
    .i_reset(reset | receiver_rst),
    .i_reset_without_watchdog(reset),

    .i_min_plateau(32'd100),
    .i_threshold_scale(`THRESHOLD_SCALE),
    .i_num_sample_changed(1'b0),
    .i_reg_num_sample_to_skip(32'd0),
    .i_reg_power_thres(16'd0),
    .i_reg_window_size(16'd80),

    .i_rssi_half_db(rssi_half_db),
    .i_sample_in(sample_in),
    .i_sample_in_strobe(sample_in_strobe),
    .i_soft_decoding(1'b1),
    .i_force_ht_smoothing(1'b0),
    .i_disable_all_smoothing(1'b0),
    .i_fft_win_shift(4'b1),

    .o_demod_is_ongoing(demod_is_ongoing),
    .o_pkt_header_valid(pkt_header_valid),
    .o_pkt_header_valid_strobe(pkt_header_valid_strobe),
    .o_pkt_len(pkt_len),

    .o_fcs_out_strobe(fcs_out_strobe),
    .o_fcs_ok(fcs_ok),
    .o_byte_out(byte_out),
    .o_byte_out_strobe(byte_out_strobe),

    .o_state(state),
    .o_status_code(status_code),
    .o_equalizer_out(equalizer),
    .o_equalizer_out_strobe(equalizer_valid),

    .o_short_preamble_detected(short_preamble_detected),
    .o_phase_offset(phase_offset),
    .o_long_preamble_detected(long_preamble_detected),

    .o_legacy_sig_stb(legacy_sig_stb),
    .o_legacy_rate(legacy_rate),
    .o_legacy_len(legacy_len),
    .o_legacy_sig_parity_ok(legacy_sig_parity_ok),

    .o_ht_sig_stb(ht_sig_stb),
    .o_ht_mcs(ht_mcs),
    .o_ht_len(ht_len),
    .o_ht_sig_crc_ok(ht_sig_crc_ok),

    .o_n_ofdm_sym(n_ofdm_sym),
    .o_n_bit_in_last_sym(n_bit_in_last_sym),
    .o_phy_len_valid(phy_len_valid),

    .o_demod_out(demod_out),
    .o_demod_soft_bits(demod_soft_bits),
    .o_demod_soft_bits_pos(demod_soft_bits_pos),
    .o_demod_out_strobe(demod_out_strobe),

    .o_deinterleave_erase_out(deinterleave_erase_out),
    .o_deinterleave_erase_out_strobe(deinterleave_erase_out_strobe),

    .o_conv_decoder_out(conv_decoder_out),
    .o_conv_decoder_out_stb(conv_decoder_out_stb),

    .o_descramble_out(descramble_out),
    .o_descramble_out_strobe(descramble_out_strobe)
);

endmodule
