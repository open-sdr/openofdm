`include "openofdm_rx_pre_def.v"
`include "common_defs.v"

module demodulate (
    input clock,
    input enable,
    input reset,

    input [7:0] rate,
    input signed [15:0] cons_i,
    input signed [15:0] cons_q,
    input input_strobe,

    input soft_bits_method,

    output reg [7:0] csi_square_over_noise_var_read_addr,
    input signed [33:0] csi_square_over_noise_var_for_llr,

    output wire [5:0] bits_output,
    output wire [17:0] soft_bits,
    output output_strobe
);

//localparam MAX = 1<<`CONS_SCALE_SHIFT;

localparam QAM_16_DIV = 648;

localparam QAM_64_DIV_0 = 316;
localparam QAM_64_DIV_1 = 632;
localparam QAM_64_DIV_2 = 948;

localparam BPSK_SOFT_4  = 1024;
localparam BPSK_SOFT_3  = 768;
localparam BPSK_SOFT_2  = 512;
localparam BPSK_SOFT_1  = 256;
localparam BPSK_SOFT_0  = 0;

localparam QPSK_SOFT_4  = 724;
localparam QPSK_SOFT_3  = 543;
localparam QPSK_SOFT_2  = 362;
localparam QPSK_SOFT_1  = 181;
localparam QPSK_SOFT_0  = 0;

localparam QAM_16_SOFT_12 = 971;
localparam QAM_16_SOFT_11 = 890;
localparam QAM_16_SOFT_10 = 810;
localparam QAM_16_SOFT_9  = 729;
localparam QAM_16_SOFT_8  = 648;
localparam QAM_16_SOFT_7  = 567;
localparam QAM_16_SOFT_6  = 486;
localparam QAM_16_SOFT_5  = 405;
localparam QAM_16_SOFT_4  = 324;
localparam QAM_16_SOFT_3  = 243;
localparam QAM_16_SOFT_2  = 162;
localparam QAM_16_SOFT_1  = 81;
localparam QAM_16_SOFT_0  = 0;

localparam QAM_64_SOFT_28 = 1106;
localparam QAM_64_SOFT_27 = 1067;
localparam QAM_64_SOFT_26 = 1027;
localparam QAM_64_SOFT_25 = 988;
localparam QAM_64_SOFT_24 = 948;
localparam QAM_64_SOFT_23 = 909;
localparam QAM_64_SOFT_22 = 869;
localparam QAM_64_SOFT_21 = 830;
localparam QAM_64_SOFT_20 = 790;
localparam QAM_64_SOFT_19 = 751;
localparam QAM_64_SOFT_18 = 711;
localparam QAM_64_SOFT_17 = 672;
localparam QAM_64_SOFT_16 = 632;
localparam QAM_64_SOFT_15 = 593;
localparam QAM_64_SOFT_14 = 553;
localparam QAM_64_SOFT_13 = 514;
localparam QAM_64_SOFT_12 = 474;
localparam QAM_64_SOFT_11 = 435;
localparam QAM_64_SOFT_10 = 395;
localparam QAM_64_SOFT_9  = 356;
localparam QAM_64_SOFT_8  = 316;
localparam QAM_64_SOFT_7  = 277;
localparam QAM_64_SOFT_6  = 237;
localparam QAM_64_SOFT_5  = 198;
localparam QAM_64_SOFT_4  = 158;
localparam QAM_64_SOFT_3  = 119;
localparam QAM_64_SOFT_2  = 79;
localparam QAM_64_SOFT_1  = 40;
localparam QAM_64_SOFT_0  = 0;

// % for QPSK, the constellation is at -1, 1
// % value1_raw means 1024 / sqrt(1)
// value4 = 4096; %round(4*value1_raw);
localparam BPSK_VALUE4 = 4096;

// % for QPSK, the constellation is at -1, 1
// % value1_raw means 1024 / sqrt(2)
// value4 = 2896; %round(4*value1_raw);
localparam QPSK_VALUE4 = 2896;

// % for 16QAM, the constellation is at -3, -1, 1, 3
// % value1_raw means 1024 / sqrt(10)
// value1 = 324; %round(value1_raw);
// value2 = 648; %round(2*value1_raw);
// value4 = 1295; %round(4*value1_raw);
// value8 = 2591; %round(8*value1_raw);
localparam QAM16_VALUE1 = 324;
localparam QAM16_VALUE2 = 648;
localparam QAM16_VALUE4 = 1295;
localparam QAM16_VALUE8 = 2591;
localparam QAM16_VALUE8_1 = 838861; //round(8*1024*1024/10)
localparam QAM16_VALUE4_2 = 838861; //round(8*1024*1024/10)

// % for 64QAM, the constellation is at -7 -5 -3, -1, 1, 3, 5, 7
// % value1_raw means 1024 / sqrt(42)
// value1 = 158; %round(value1_raw);
// value2 = 316; %round(2*value1_raw);
// value3 = 474; %round(3*value1_raw);
// value4 = 632; %round(4*value1_raw);
// value5 = 790; %round(5*value1_raw);
// value6 = 948; %round(6*value1_raw);
// value8 = 1264; %round(8*value1_raw);
// value12 = 1896; %round(12*value1_raw);
// value16 = 2528; %round(16*value1_raw);
localparam QAM64_VALUE1 = 158;
localparam QAM64_VALUE2 = 316;
localparam QAM64_VALUE3 = 474;
localparam QAM64_VALUE4 = 632;
localparam QAM64_VALUE5 = 790;
localparam QAM64_VALUE6 = 948;
localparam QAM64_VALUE8 = 1264;
localparam QAM64_VALUE12 = 1896;
localparam QAM64_VALUE16 = 2528;
localparam QAM64_VALUE16_3 = 1198373; //round(16*3*1024*1024/42);
localparam QAM64_VALUE12_2 = 599186; //round(12*2*1024*1024/42);
localparam QAM64_VALUE8_1 = 199729; //round(8*1*1024*1024/42);
localparam QAM64_VALUE8_5 = 998644; //round(8*5*1024*1024/42);
localparam QAM64_VALUE4_4 = 399458; //round(4*4*1024*1024/42);
localparam QAM64_VALUE8_3 = 599186;
localparam QAM64_VALUE4_6 = 599186;
localparam QAM64_VALUE4_2 = 199729;

localparam BPSK = 1;
localparam QPSK = 2;
localparam QAM_16 = 3;
localparam QAM_64 = 4;

localparam THRESHOLD_BASE_LEGACY = 413;
localparam THRESHOLD1_LEGACY = (-3*THRESHOLD_BASE_LEGACY);
localparam THRESHOLD2_LEGACY = (-2*THRESHOLD_BASE_LEGACY);
localparam THRESHOLD3_LEGACY = (-1*THRESHOLD_BASE_LEGACY);
localparam THRESHOLD4_LEGACY = 0;
localparam THRESHOLD5_LEGACY = ( 1*THRESHOLD_BASE_LEGACY);
localparam THRESHOLD6_LEGACY = ( 2*THRESHOLD_BASE_LEGACY);
localparam THRESHOLD7_LEGACY = ( 3*THRESHOLD_BASE_LEGACY);

localparam THRESHOLD_BASE_HT = 550;
localparam THRESHOLD1_HT = (-3*THRESHOLD_BASE_HT);
localparam THRESHOLD2_HT = (-2*THRESHOLD_BASE_HT);
localparam THRESHOLD3_HT = (-1*THRESHOLD_BASE_HT);
localparam THRESHOLD4_HT = 0;
localparam THRESHOLD5_HT = ( 1*THRESHOLD_BASE_HT);
localparam THRESHOLD6_HT = ( 2*THRESHOLD_BASE_HT);
localparam THRESHOLD7_HT = ( 3*THRESHOLD_BASE_HT);

reg signed [15:0] cons_i_delayed;
reg signed [15:0] cons_q_delayed;
reg [15:0] abs_cons_i;
reg [15:0] abs_cons_q;

reg [2:0] mod;

reg [5:0] bits;
reg [5:0] bits_delay1;
reg [5:0] bits_delay2;

reg  signed [(16+12):0] QAM16_VALUE8_mult_i;
reg  signed [(16+12):0] QAM16_VALUE8_mult_q;

reg  signed [(16+12):0] QAM64_VALUE16_mult_i;
reg  signed [(16+12):0] QAM64_VALUE12_mult_i;
reg  signed [(16+12):0] QAM64_VALUE16_mult_q;
reg  signed [(16+12):0] QAM64_VALUE12_mult_q;

wire signed [(16+12):0] QAM16_VALUE4_mult_i;
wire signed [(16+12):0] QAM16_VALUE4_mult_q;

wire signed [(16+12):0] QAM64_VALUE8_mult_i;
wire signed [(16+12):0] QAM64_VALUE4_mult_i;
wire signed [(16+12):0] QAM64_VALUE8_mult_q;
wire signed [(16+12):0] QAM64_VALUE4_mult_q;

reg signed [(16+12):0] raw_llr_i [2:0]; //16bit I/Q, BPSK_VALUE4 4096 == 12bit
reg signed [(16+12):0] raw_llr_q [2:0];
wire raw_llr_strobe;

reg signed [(16+12+34):0] raw_llr_i_mult_csi_square_over_noise_var [2:0];
reg signed [(16+12+34):0] raw_llr_q_mult_csi_square_over_noise_var [2:0];
wire raw_llr_mult_csi_square_over_noise_var_strobe;

// wire signed [12:0] raw_llr_i_mult_csi_square_over_noise_var_reduce [2:0];
// wire signed [12:0] raw_llr_q_mult_csi_square_over_noise_var_reduce [2:0];
wire signed [(12+34):0] raw_llr_i_mult_csi_square_over_noise_var_reduce [2:0];
wire signed [(12+34):0] raw_llr_q_mult_csi_square_over_noise_var_reduce [2:0];

reg [4:0] input_strobe_delay;
reg [7:0] csi_square_over_noise_var_addr_top; //48 for 11a/g; 52 for 11n; 242 for 11ax
reg signed [33:0] csi_square_over_noise_var_for_llr_delay1;//for aligning of raw_llr_i_mult_csi_square_over_noise_var[0] <= raw_llr_i[0] * csi_square_over_noise_var_for_llr;

reg signed [11:0] threshold1;//the range of threshold is like -3*550 ~ 3*550, so reduce it to signed 12bit -2048 ~ 2047
reg signed [11:0] threshold2;
reg signed [11:0] threshold3;
reg signed [11:0] threshold4;
reg signed [11:0] threshold5;
reg signed [11:0] threshold6;
reg signed [11:0] threshold7;

integer i;
reg [2:0] soft_bits_i [2:0];
reg [2:0] soft_bits_q [2:0];

reg [2:0] soft_bits_i_old_delay2 [2:0]; // old method (hard partition) of soft bits
reg [2:0] soft_bits_q_old_delay2 [2:0]; // old method (hard partition) of soft bits

assign bits_output = bits_delay2;//two extral clock to sync with soft_bits_i/soft_bits_q

// assign QAM16_VALUE8_mult_i = QAM16_VALUE8*cons_i_delayed;
assign QAM16_VALUE4_mult_i = {QAM16_VALUE8_mult_i[16+12], QAM16_VALUE8_mult_i[(16+12):1]};
// assign QAM16_VALUE8_mult_q = QAM16_VALUE8*cons_q_delayed;
assign QAM16_VALUE4_mult_q = {QAM16_VALUE8_mult_q[16+12], QAM16_VALUE8_mult_q[(16+12):1]};

// assign QAM64_VALUE16_mult_i = QAM64_VALUE16*cons_i_delayed;
assign  QAM64_VALUE8_mult_i = {QAM64_VALUE16_mult_i[16+12], QAM64_VALUE16_mult_i[(16+12):1]};
assign  QAM64_VALUE4_mult_i = {QAM64_VALUE8_mult_i[16+12], QAM64_VALUE8_mult_i[(16+12):1]};
// assign QAM64_VALUE12_mult_i = QAM64_VALUE12*cons_i_delayed;
// assign QAM64_VALUE16_mult_q = QAM64_VALUE16*cons_q_delayed;
assign  QAM64_VALUE8_mult_q = {QAM64_VALUE16_mult_q[16+12], QAM64_VALUE16_mult_q[(16+12):1]};
assign  QAM64_VALUE4_mult_q = {QAM64_VALUE8_mult_q[16+12], QAM64_VALUE8_mult_q[(16+12):1]};
// assign QAM64_VALUE12_mult_q = QAM64_VALUE12*cons_q_delayed;

// assign raw_llr_i_mult_csi_square_over_noise_var_reduce[0] = ($signed(raw_llr_i_mult_csi_square_over_noise_var[0][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_i_mult_csi_square_over_noise_var[0][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_i_mult_csi_square_over_noise_var[0][(16+12+34):16])));
// assign raw_llr_q_mult_csi_square_over_noise_var_reduce[0] = ($signed(raw_llr_q_mult_csi_square_over_noise_var[0][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_q_mult_csi_square_over_noise_var[0][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_q_mult_csi_square_over_noise_var[0][(16+12+34):16])));
// assign raw_llr_i_mult_csi_square_over_noise_var_reduce[1] = ($signed(raw_llr_i_mult_csi_square_over_noise_var[1][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_i_mult_csi_square_over_noise_var[1][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_i_mult_csi_square_over_noise_var[1][(16+12+34):16])));
// assign raw_llr_q_mult_csi_square_over_noise_var_reduce[1] = ($signed(raw_llr_q_mult_csi_square_over_noise_var[1][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_q_mult_csi_square_over_noise_var[1][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_q_mult_csi_square_over_noise_var[1][(16+12+34):16])));
// assign raw_llr_i_mult_csi_square_over_noise_var_reduce[2] = ($signed(raw_llr_i_mult_csi_square_over_noise_var[2][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_i_mult_csi_square_over_noise_var[2][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_i_mult_csi_square_over_noise_var[2][(16+12+34):16])));
// assign raw_llr_q_mult_csi_square_over_noise_var_reduce[2] = ($signed(raw_llr_q_mult_csi_square_over_noise_var[2][(16+12+34):16])<$signed(-2048)?$signed(-2048):($signed(raw_llr_q_mult_csi_square_over_noise_var[2][(16+12+34):16])>$signed(2047)?$signed(2047):$signed(raw_llr_q_mult_csi_square_over_noise_var[2][(16+12+34):16])));
assign raw_llr_i_mult_csi_square_over_noise_var_reduce[0] = $signed(raw_llr_i_mult_csi_square_over_noise_var[0][(16+12+34):16]);
assign raw_llr_q_mult_csi_square_over_noise_var_reduce[0] = $signed(raw_llr_q_mult_csi_square_over_noise_var[0][(16+12+34):16]);
assign raw_llr_i_mult_csi_square_over_noise_var_reduce[1] = $signed(raw_llr_i_mult_csi_square_over_noise_var[1][(16+12+34):16]);
assign raw_llr_q_mult_csi_square_over_noise_var_reduce[1] = $signed(raw_llr_q_mult_csi_square_over_noise_var[1][(16+12+34):16]);
assign raw_llr_i_mult_csi_square_over_noise_var_reduce[2] = $signed(raw_llr_i_mult_csi_square_over_noise_var[2][(16+12+34):16]);
assign raw_llr_q_mult_csi_square_over_noise_var_reduce[2] = $signed(raw_llr_q_mult_csi_square_over_noise_var[2][(16+12+34):16]);

assign raw_llr_strobe = input_strobe_delay[1];
assign raw_llr_mult_csi_square_over_noise_var_strobe = input_strobe_delay[2];

assign soft_bits = ( soft_bits_method? {soft_bits_q_old_delay2[2], soft_bits_q_old_delay2[1], soft_bits_q_old_delay2[0], soft_bits_i_old_delay2[2], soft_bits_i_old_delay2[1], soft_bits_i_old_delay2[0]} : {soft_bits_q[2], soft_bits_q[1], soft_bits_q[0], soft_bits_i[2], soft_bits_i[1], soft_bits_i[0]} );

assign output_strobe = (enable? input_strobe_delay[3] : 0);//sync with soft_bits_i/soft_bits_q

always @(posedge clock) begin
  if (reset) begin
    bits <= 0;
    bits_delay1 <= 0;
    bits_delay2 <= 0;
    raw_llr_i[0] <= 0;
    raw_llr_i[1] <= 0;
    raw_llr_i[2] <= 0;
    raw_llr_q[0] <= 0;
    raw_llr_q[1] <= 0;
    raw_llr_q[2] <= 0;
    abs_cons_i <= 0;
    abs_cons_q <= 0;
    cons_i_delayed <= 0;
    cons_q_delayed <= 0;
    mod <= 0;

    QAM16_VALUE8_mult_i <= 0;
    QAM16_VALUE8_mult_q <= 0;

    QAM64_VALUE16_mult_i <= 0;
    QAM64_VALUE12_mult_i <= 0;
    QAM64_VALUE16_mult_q <= 0;
    QAM64_VALUE12_mult_q <= 0;

    raw_llr_i_mult_csi_square_over_noise_var[0] <= 0;
    raw_llr_i_mult_csi_square_over_noise_var[1] <= 0;
    raw_llr_i_mult_csi_square_over_noise_var[2] <= 0;
    raw_llr_q_mult_csi_square_over_noise_var[0] <= 0;
    raw_llr_q_mult_csi_square_over_noise_var[1] <= 0;
    raw_llr_q_mult_csi_square_over_noise_var[2] <= 0;

    input_strobe_delay[0]   <= input_strobe;
    input_strobe_delay[4:1] <= 0;
    csi_square_over_noise_var_for_llr_delay1 <= csi_square_over_noise_var_for_llr;
    csi_square_over_noise_var_addr_top <= (rate[7]?51:47);
    csi_square_over_noise_var_read_addr <= 0;

    threshold1 <= THRESHOLD1_LEGACY;
    threshold2 <= THRESHOLD2_LEGACY;
    threshold3 <= THRESHOLD3_LEGACY;
    threshold4 <= THRESHOLD4_LEGACY;
    threshold5 <= THRESHOLD5_LEGACY;
    threshold6 <= THRESHOLD6_LEGACY;
    threshold7 <= THRESHOLD7_LEGACY;

    soft_bits_i[0] <= 0;
    soft_bits_i[1] <= 4;
    soft_bits_i[2] <= 7;
    soft_bits_q[0] <= 7;
    soft_bits_q[1] <= 0;
    soft_bits_q[2] <= 4;
  end else if (enable) begin
    bits_delay1 <= bits;
    bits_delay2 <= bits_delay1;
    input_strobe_delay[0]   <= input_strobe;
    input_strobe_delay[4:1] <= input_strobe_delay[3:0];
    csi_square_over_noise_var_for_llr_delay1 <= csi_square_over_noise_var_for_llr;

    abs_cons_i <= cons_i[15]? ~cons_i+1: cons_i;
    abs_cons_q <= cons_q[15]? ~cons_q+1: cons_q;
    cons_i_delayed <= cons_i;
    cons_q_delayed <= cons_q;

    QAM16_VALUE8_mult_i <= QAM16_VALUE8*cons_i;
    QAM16_VALUE8_mult_q <= QAM16_VALUE8*cons_q;

    QAM64_VALUE16_mult_i <= QAM64_VALUE16*cons_i;
    QAM64_VALUE12_mult_i <= QAM64_VALUE12*cons_i;
    QAM64_VALUE16_mult_q <= QAM64_VALUE16*cons_q;
    QAM64_VALUE12_mult_q <= QAM64_VALUE12*cons_q;

    case({rate[7], rate[3:0]})
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
        // Hard decoded bits
        bits[0] <= ~cons_i_delayed[15];
        bits[5:1] <= 0;

        // Inphase soft decoded bits
        raw_llr_i[0] <= -BPSK_VALUE4*cons_i_delayed;
        raw_llr_i[1] <= 0;
        raw_llr_i[2] <= 0;

        // Quadrature soft decoded bits
        raw_llr_q[0] <= 0;
        raw_llr_q[1] <= 0;
        raw_llr_q[2] <= 0;
      end
      QPSK: begin
        // Hard decoded bits
        bits[0] <= ~cons_i_delayed[15];
        bits[1] <= ~cons_q_delayed[15];
        bits[5:2] <= 0;

        // Inphase soft decoded bits
        raw_llr_i[0] <= -QPSK_VALUE4*cons_i_delayed;
        raw_llr_i[1] <= 0;
        raw_llr_i[2] <= 0;

        // Quadrature soft decoded bits
        raw_llr_q[0] <= -QPSK_VALUE4*cons_q_delayed;
        raw_llr_q[1] <= 0;
        raw_llr_q[2] <= 0;
      end
      QAM_16: begin
        // Hard decoded bits
        bits[0] <= ~cons_i_delayed[15];
        bits[1] <= abs_cons_i < QAM_16_DIV? 1: 0;
        bits[2] <= ~cons_q_delayed[15];
        bits[3] <= abs_cons_q < QAM_16_DIV? 1: 0;
        bits[5:4] <= 0;

        // Inphase soft decoded bits
        if (cons_i_delayed < -QAM16_VALUE2)
          raw_llr_i[0] <= -QAM16_VALUE8_mult_i - QAM16_VALUE8_1;
        else if (cons_i_delayed < QAM16_VALUE2)
          raw_llr_i[0] <= -QAM16_VALUE4_mult_i;
        else
          raw_llr_i[0] <= -QAM16_VALUE8_mult_i + QAM16_VALUE8_1;
        
        if (cons_i_delayed < 0)
          raw_llr_i[1] <= -QAM16_VALUE4_mult_i - QAM16_VALUE4_2;
        else
          raw_llr_i[1] <=  QAM16_VALUE4_mult_i - QAM16_VALUE4_2;
        
        // Quadrature soft decoded bits
        if (cons_q_delayed < -QAM16_VALUE2)
          raw_llr_q[0] <= -QAM16_VALUE8_mult_q - QAM16_VALUE8_1;
        else if (cons_q_delayed < QAM16_VALUE2)
          raw_llr_q[0] <= -QAM16_VALUE4_mult_q;
        else
          raw_llr_q[0] <= -QAM16_VALUE8_mult_q + QAM16_VALUE8_1;
        
        if (cons_q_delayed < 0)
          raw_llr_q[1] <= -QAM16_VALUE4_mult_q - QAM16_VALUE4_2;
        else
          raw_llr_q[1] <=  QAM16_VALUE4_mult_q - QAM16_VALUE4_2;
      end
      QAM_64: begin
        // Hard decoded bits
        bits[0] <= ~cons_i_delayed[15];
        bits[1] <= abs_cons_i < QAM_64_DIV_1? 1: 0;
        bits[2] <= abs_cons_i > QAM_64_DIV_0 &&
        abs_cons_i < QAM_64_DIV_2? 1: 0;
        bits[3] <= ~cons_q_delayed[15];
        bits[4] <= abs_cons_q < QAM_64_DIV_1? 1: 0;
        bits[5] <= abs_cons_q > QAM_64_DIV_0 &&
        abs_cons_q < QAM_64_DIV_2? 1: 0;

        // Inphase soft decoded bits
        if      (cons_i_delayed < -QAM64_VALUE6)
          raw_llr_i[0] <= -QAM64_VALUE16_mult_i - QAM64_VALUE16_3;
        else if (cons_i_delayed < -QAM64_VALUE4)
          raw_llr_i[0] <= -QAM64_VALUE12_mult_i - QAM64_VALUE12_2;
        else if (cons_i_delayed < -QAM64_VALUE2)
          raw_llr_i[0] <=  -QAM64_VALUE8_mult_i - QAM64_VALUE8_1;
        else if (cons_i_delayed <  QAM64_VALUE2)
          raw_llr_i[0] <= -QAM64_VALUE4_mult_i;
        else if (cons_i_delayed <  QAM64_VALUE4)
          raw_llr_i[0] <=  -QAM64_VALUE8_mult_i + QAM64_VALUE8_1;
        else if (cons_i_delayed <  QAM64_VALUE6)
          raw_llr_i[0] <= -QAM64_VALUE12_mult_i + QAM64_VALUE12_2;
        else
          raw_llr_i[0] <= -QAM64_VALUE16_mult_i + QAM64_VALUE16_3;

        if      (cons_i_delayed < -QAM64_VALUE6)
          raw_llr_i[1] <= -QAM64_VALUE8_mult_i - QAM64_VALUE8_5;
        else if (cons_i_delayed < -QAM64_VALUE2)
          raw_llr_i[1] <= -QAM64_VALUE4_mult_i - QAM64_VALUE4_4;
        else if (cons_i_delayed <  0)
          raw_llr_i[1] <= -QAM64_VALUE8_mult_i - QAM64_VALUE8_3;
        else if (cons_i_delayed <  QAM64_VALUE2)
          raw_llr_i[1] <=  QAM64_VALUE8_mult_i - QAM64_VALUE8_3;
        else if (cons_i_delayed <  QAM64_VALUE6)
          raw_llr_i[1] <=  QAM64_VALUE4_mult_i - QAM64_VALUE4_4;
        else
          raw_llr_i[1] <=  QAM64_VALUE8_mult_i - QAM64_VALUE8_5;

        if      (cons_i_delayed < -QAM64_VALUE4)
          raw_llr_i[2] <= -QAM64_VALUE4_mult_i - QAM64_VALUE4_6;
        else if (cons_i_delayed <  0)
          raw_llr_i[2] <=  QAM64_VALUE4_mult_i + QAM64_VALUE4_2;
        else if (cons_i_delayed <  QAM64_VALUE4)
          raw_llr_i[2] <= -QAM64_VALUE4_mult_i + QAM64_VALUE4_2;
        else
          raw_llr_i[2] <=  QAM64_VALUE4_mult_i - QAM64_VALUE4_6;

        // Quadrature soft decoded bits
        if      (cons_q_delayed < -QAM64_VALUE6)
          raw_llr_q[0] <= -QAM64_VALUE16_mult_q - QAM64_VALUE16_3;
        else if (cons_q_delayed < -QAM64_VALUE4)
          raw_llr_q[0] <= -QAM64_VALUE12_mult_q - QAM64_VALUE12_2;
        else if (cons_q_delayed < -QAM64_VALUE2)
          raw_llr_q[0] <=  -QAM64_VALUE8_mult_q - QAM64_VALUE8_1;
        else if (cons_q_delayed <  QAM64_VALUE2)
          raw_llr_q[0] <= -QAM64_VALUE4_mult_q;
        else if (cons_q_delayed <  QAM64_VALUE4)
          raw_llr_q[0] <=  -QAM64_VALUE8_mult_q + QAM64_VALUE8_1;
        else if (cons_q_delayed <  QAM64_VALUE6)
          raw_llr_q[0] <= -QAM64_VALUE12_mult_q + QAM64_VALUE12_2;
        else
          raw_llr_q[0] <= -QAM64_VALUE16_mult_q + QAM64_VALUE16_3;

        if      (cons_q_delayed < -QAM64_VALUE6)
          raw_llr_q[1] <= -QAM64_VALUE8_mult_q - QAM64_VALUE8_5;
        else if (cons_q_delayed < -QAM64_VALUE2)
          raw_llr_q[1] <= -QAM64_VALUE4_mult_q - QAM64_VALUE4_4;
        else if (cons_q_delayed <  0)
          raw_llr_q[1] <= -QAM64_VALUE8_mult_q - QAM64_VALUE8_3;
        else if (cons_q_delayed <  QAM64_VALUE2)
          raw_llr_q[1] <=  QAM64_VALUE8_mult_q - QAM64_VALUE8_3;
        else if (cons_q_delayed <  QAM64_VALUE6)
          raw_llr_q[1] <=  QAM64_VALUE4_mult_q - QAM64_VALUE4_4;
        else
          raw_llr_q[1] <=  QAM64_VALUE8_mult_q - QAM64_VALUE8_5;

        if      (cons_q_delayed < -QAM64_VALUE4)
          raw_llr_q[2] <= -QAM64_VALUE4_mult_q - QAM64_VALUE4_6;
        else if (cons_q_delayed <  0)
          raw_llr_q[2] <=  QAM64_VALUE4_mult_q + QAM64_VALUE4_2;
        else if (cons_q_delayed <  QAM64_VALUE4)
          raw_llr_q[2] <= -QAM64_VALUE4_mult_q + QAM64_VALUE4_2;
        else
          raw_llr_q[2] <=  QAM64_VALUE4_mult_q - QAM64_VALUE4_6;
      end
    endcase

    // -------------- multiply raw_llr with csi_square_over_noise_var --------------
    // 1. generate the reading address to csi_square_over_noise_var meomry according to number fo subcarrier
    csi_square_over_noise_var_addr_top <= (rate[7]?51:47);
    if (input_strobe) begin
      csi_square_over_noise_var_read_addr <= (csi_square_over_noise_var_read_addr==csi_square_over_noise_var_addr_top?0:(csi_square_over_noise_var_read_addr+1));
    end
    // 2. multiplication
    raw_llr_i_mult_csi_square_over_noise_var[0] <= raw_llr_i[0] * csi_square_over_noise_var_for_llr_delay1;
    raw_llr_i_mult_csi_square_over_noise_var[1] <= raw_llr_i[1] * csi_square_over_noise_var_for_llr_delay1;
    raw_llr_i_mult_csi_square_over_noise_var[2] <= raw_llr_i[2] * csi_square_over_noise_var_for_llr_delay1;
    raw_llr_q_mult_csi_square_over_noise_var[0] <= raw_llr_q[0] * csi_square_over_noise_var_for_llr_delay1;
    raw_llr_q_mult_csi_square_over_noise_var[1] <= raw_llr_q[1] * csi_square_over_noise_var_for_llr_delay1;
    raw_llr_q_mult_csi_square_over_noise_var[2] <= raw_llr_q[2] * csi_square_over_noise_var_for_llr_delay1;

    // -------------------------- quantization to 3 bit -----------------------------
    threshold1 <= (rate[7]?THRESHOLD1_HT:THRESHOLD1_LEGACY);
    threshold2 <= (rate[7]?THRESHOLD2_HT:THRESHOLD2_LEGACY);
    threshold3 <= (rate[7]?THRESHOLD3_HT:THRESHOLD3_LEGACY);
    threshold4 <= (rate[7]?THRESHOLD4_HT:THRESHOLD4_LEGACY);
    threshold5 <= (rate[7]?THRESHOLD5_HT:THRESHOLD5_LEGACY);
    threshold6 <= (rate[7]?THRESHOLD6_HT:THRESHOLD6_LEGACY);
    threshold7 <= (rate[7]?THRESHOLD7_HT:THRESHOLD7_LEGACY);

    if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold1)
      soft_bits_i[0] <= 7;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold2)
      soft_bits_i[0] <= 6;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold3)
      soft_bits_i[0] <= 5;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold4)
      soft_bits_i[0] <= 4;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold5)
      soft_bits_i[0] <= 3;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold6)
      soft_bits_i[0] <= 2;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[0] < threshold7)
      soft_bits_i[0] <= 1;
    else
      soft_bits_i[0] <= 0;

    if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold1)
      soft_bits_q[0] <= 7;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold2)
      soft_bits_q[0] <= 6;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold3)
      soft_bits_q[0] <= 5;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold4)
      soft_bits_q[0] <= 4;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold5)
      soft_bits_q[0] <= 3;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold6)
      soft_bits_q[0] <= 2;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[0] < threshold7)
      soft_bits_q[0] <= 1;
    else
      soft_bits_q[0] <= 0;

    if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold1)
      soft_bits_i[1] <= 7;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold2)
      soft_bits_i[1] <= 6;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold3)
      soft_bits_i[1] <= 5;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold4)
      soft_bits_i[1] <= 4;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold5)
      soft_bits_i[1] <= 3;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold6)
      soft_bits_i[1] <= 2;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[1] < threshold7)
      soft_bits_i[1] <= 1;
    else
      soft_bits_i[1] <= 0;

    if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold1)
      soft_bits_q[1] <= 7;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold2)
      soft_bits_q[1] <= 6;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold3)
      soft_bits_q[1] <= 5;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold4)
      soft_bits_q[1] <= 4;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold5)
      soft_bits_q[1] <= 3;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold6)
      soft_bits_q[1] <= 2;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[1] < threshold7)
      soft_bits_q[1] <= 1;
    else
      soft_bits_q[1] <= 0;

    if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold1)
      soft_bits_i[2] <= 7;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold2)
      soft_bits_i[2] <= 6;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold3)
      soft_bits_i[2] <= 5;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold4)
      soft_bits_i[2] <= 4;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold5)
      soft_bits_i[2] <= 3;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold6)
      soft_bits_i[2] <= 2;
    else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[2] < threshold7)
      soft_bits_i[2] <= 1;
    else
      soft_bits_i[2] <= 0;

    if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold1)
      soft_bits_q[2] <= 7;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold2)
      soft_bits_q[2] <= 6;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold3)
      soft_bits_q[2] <= 5;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold4)
      soft_bits_q[2] <= 4;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold5)
      soft_bits_q[2] <= 3;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold6)
      soft_bits_q[2] <= 2;
    else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[2] < threshold7)
      soft_bits_q[2] <= 1;
    else
      soft_bits_q[2] <= 0;

    // for (i = 0; i<3; i = i + 1) begin
    //   if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold1)
    //     soft_bits_i[i] <= 7;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold2)
    //     soft_bits_i[i] <= 6;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold3)
    //     soft_bits_i[i] <= 5;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold4)
    //     soft_bits_i[i] <= 4;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold5)
    //     soft_bits_i[i] <= 3;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold6)
    //     soft_bits_i[i] <= 2;
    //   else if (raw_llr_i_mult_csi_square_over_noise_var_reduce[i] < threshold7)
    //     soft_bits_i[i] <= 1;
    //   else
    //     soft_bits_i[i] <= 0;

    //   if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold1)
    //     soft_bits_q[i] <= 7;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold2)
    //     soft_bits_q[i] <= 6;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold3)
    //     soft_bits_q[i] <= 5;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold4)
    //     soft_bits_q[i] <= 4;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold5)
    //     soft_bits_q[i] <= 3;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold6)
    //     soft_bits_q[i] <= 2;
    //   else if (raw_llr_q_mult_csi_square_over_noise_var_reduce[i] < threshold7)
    //     soft_bits_q[i] <= 1;
    //   else
    //     soft_bits_q[i] <= 0;
    // end
  end
end

// Following part is old method (hard partition) to generate soft bits
// for performance comparison between LLR and old soft bits method
// Comment out the HAS_OLD_SOFT_BITS_METHOD definition to disable this part for resource saving
// Now it is controled by openofdm_rx_pre_def.v, generated by openofdm_rx.tcl according to whether it is small FPGA (depends on BOARD_NAME)
// `define HAS_OLD_SOFT_BITS_METHOD 1

`ifdef HAS_OLD_SOFT_BITS_METHOD

// localparam SOFT_VALUE_0 = 0;
// localparam SOFT_VALUE_1 = 1;
// localparam SOFT_VALUE_2 = 2;
// localparam SOFT_VALUE_3 = 3;
// localparam SOFT_VALUE_4 = 4;
// localparam SOFT_VALUE_5 = 5;
// localparam SOFT_VALUE_6 = 6;
// localparam SOFT_VALUE_7 = 7;
localparam SOFT_VALUE_0 = 7;
localparam SOFT_VALUE_1 = 6;
localparam SOFT_VALUE_2 = 5;
localparam SOFT_VALUE_3 = 4;
localparam SOFT_VALUE_4 = 3;
localparam SOFT_VALUE_5 = 2;
localparam SOFT_VALUE_6 = 1;
localparam SOFT_VALUE_7 = 0;

reg [2:0] soft_bits_i_old [2:0];
reg [2:0] soft_bits_q_old [2:0];

reg [2:0] soft_bits_i_old_delay1 [2:0];
reg [2:0] soft_bits_q_old_delay1 [2:0];

always @(posedge clock) begin
  if (reset) begin
    soft_bits_i_old[0] <= 0;
    soft_bits_i_old[1] <= 4;
    soft_bits_i_old[2] <= 7;
    soft_bits_q_old[0] <= 7;
    soft_bits_q_old[1] <= 0;
    soft_bits_q_old[2] <= 4;

    soft_bits_i_old_delay1[0] <= 0;
    soft_bits_i_old_delay1[1] <= 4;
    soft_bits_i_old_delay1[2] <= 7;
    soft_bits_q_old_delay1[0] <= 7;
    soft_bits_q_old_delay1[1] <= 0;
    soft_bits_q_old_delay1[2] <= 4;

    soft_bits_i_old_delay2[0] <= 0;
    soft_bits_i_old_delay2[1] <= 4;
    soft_bits_i_old_delay2[2] <= 7;
    soft_bits_q_old_delay2[0] <= 7;
    soft_bits_q_old_delay2[1] <= 0;
    soft_bits_q_old_delay2[2] <= 4;
  end else if (enable) begin
    soft_bits_i_old_delay1[0] <= soft_bits_i_old[0];
    soft_bits_i_old_delay1[1] <= soft_bits_i_old[1];
    soft_bits_i_old_delay1[2] <= soft_bits_i_old[2];
    soft_bits_q_old_delay1[0] <= soft_bits_q_old[0];
    soft_bits_q_old_delay1[1] <= soft_bits_q_old[1];
    soft_bits_q_old_delay1[2] <= soft_bits_q_old[2];

    soft_bits_i_old_delay2[0] <= soft_bits_i_old_delay1[0];
    soft_bits_i_old_delay2[1] <= soft_bits_i_old_delay1[1];
    soft_bits_i_old_delay2[2] <= soft_bits_i_old_delay1[2];
    soft_bits_q_old_delay2[0] <= soft_bits_q_old_delay1[0];
    soft_bits_q_old_delay2[1] <= soft_bits_q_old_delay1[1];
    soft_bits_q_old_delay2[2] <= soft_bits_q_old_delay1[2];
    case(mod)
      BPSK: begin
        // Inphase soft decoded bits
        if(cons_i_delayed[15] == 0 && abs_cons_i >= BPSK_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_3 && abs_cons_i >= BPSK_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_1;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_2 && abs_cons_i >= BPSK_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_2;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < BPSK_SOFT_1 && abs_cons_i >= BPSK_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_3;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_1 && abs_cons_i >= BPSK_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_4;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_2 && abs_cons_i >= BPSK_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_5;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_3 && abs_cons_i >= BPSK_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_6;
        // end else if(cons_i_delayed[15] == 1 && abs_cons_i < BPSK_SOFT_4 && abs_cons_i >= BPSK_SOFT_3)
        end else if(cons_i_delayed[15] == 1 && abs_cons_i >= BPSK_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_7;
        end
        // else
        //   soft_bits[2:0] <= 3'b011;
        soft_bits_i_old[1] <= SOFT_VALUE_4;
        soft_bits_i_old[2] <= SOFT_VALUE_4;

        // Quadrature soft decoded bits
        soft_bits_q_old[0] <= SOFT_VALUE_4;
        soft_bits_q_old[1] <= SOFT_VALUE_4;
        soft_bits_q_old[2] <= SOFT_VALUE_4;

        // // Inphase soft decoded bit positions
        // if(abs_cons_i < BPSK_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b00;
        // else
        //   soft_bits_pos[1:0] <= 2'b11;

        // // Quadrature soft decoded bit positions
        // soft_bits_pos[3:2] <= 2'b11;
      end
      QPSK: begin
        // Inphase soft decoded bits
        if(cons_i_delayed[15] == 0 && abs_cons_i >= QPSK_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_3 && abs_cons_i >= QPSK_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_1;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_2 && abs_cons_i >= QPSK_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_2;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QPSK_SOFT_1 && abs_cons_i >= QPSK_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_3;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_1 && abs_cons_i >= QPSK_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_4;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_2 && abs_cons_i >= QPSK_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_5;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_3 && abs_cons_i >= QPSK_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_6;
        // end else if(cons_i_delayed[15] == 1 && abs_cons_i < QPSK_SOFT_4 && abs_cons_i >= QPSK_SOFT_3) begin
        end else if(cons_i_delayed[15] == 1 && abs_cons_i >= QPSK_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_7;
        end
        // else
        //   soft_bits[2:0] <= 3'b011;
        soft_bits_i_old[1] <= SOFT_VALUE_4;
        soft_bits_i_old[2] <= SOFT_VALUE_4;

        // Quadrature soft decoded bits
        if(cons_q_delayed[15] == 0 && abs_cons_q >= QPSK_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_3 && abs_cons_q >= QPSK_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_1;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_2 && abs_cons_q >= QPSK_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_2;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QPSK_SOFT_1 && abs_cons_q >= QPSK_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_3;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_1 && abs_cons_q >= QPSK_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_4;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_2 && abs_cons_q >= QPSK_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_5;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_3 && abs_cons_q >= QPSK_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_6;
        // end else if(cons_q_delayed[15] == 1 && abs_cons_q < QPSK_SOFT_4 && abs_cons_q >= QPSK_SOFT_3) begin
        end else if(cons_q_delayed[15] == 1 && abs_cons_q >= QPSK_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_7;
        end 
        // else
        //   soft_bits[5:3] <= 3'b011;
        soft_bits_q_old[1] <= SOFT_VALUE_4;
        soft_bits_q_old[2] <= SOFT_VALUE_4;

        // // Inphase soft decoded bit positions
        // if(abs_cons_i < QPSK_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b00;
        // else
        //   soft_bits_pos[1:0] <= 2'b11;

        // // Quadrature soft decoded bit positions
        // if(abs_cons_q < QPSK_SOFT_4)
        //   soft_bits_pos[3:2] <= 2'b00;
        // else
        //   soft_bits_pos[3:2] <= 2'b11;
      end
      QAM_16: begin
        // Inphase soft decoded bits
        // if(abs_cons_i < QAM_16_SOFT_12 && abs_cons_i >= QAM_16_SOFT_11) begin
        if(abs_cons_i >= QAM_16_SOFT_11) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
        end else if(abs_cons_i < QAM_16_SOFT_11 && abs_cons_i >= QAM_16_SOFT_10) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_6;
        end else if(abs_cons_i < QAM_16_SOFT_10 && abs_cons_i >= QAM_16_SOFT_9) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_5;
        end else if(abs_cons_i < QAM_16_SOFT_9  && abs_cons_i >= QAM_16_SOFT_8) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_4;
        end else if(abs_cons_i < QAM_16_SOFT_8  && abs_cons_i >= QAM_16_SOFT_7) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_3;
        end else if(abs_cons_i < QAM_16_SOFT_7  && abs_cons_i >= QAM_16_SOFT_6) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_2;
        end else if(abs_cons_i < QAM_16_SOFT_6  && abs_cons_i >= QAM_16_SOFT_5) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_1;
        end else if(abs_cons_i < QAM_16_SOFT_5  && abs_cons_i >= QAM_16_SOFT_4) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        //
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_4 && abs_cons_i >= QAM_16_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_0;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_3 && abs_cons_i >= QAM_16_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_1;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_2 && abs_cons_i >= QAM_16_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_2;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_16_SOFT_1 && abs_cons_i >= QAM_16_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_3;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_1 && abs_cons_i >= QAM_16_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_4;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_2 && abs_cons_i >= QAM_16_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_5;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_3 && abs_cons_i >= QAM_16_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_6;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_16_SOFT_4 && abs_cons_i >= QAM_16_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_7;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
        end 
        // else
        //   soft_bits[2:0] <= 3'b011;
        soft_bits_i_old[2] <= SOFT_VALUE_4;

        // Quadrature soft decoded bits
        // if(abs_cons_q < QAM_16_SOFT_12 && abs_cons_q >= QAM_16_SOFT_11) begin
        if(abs_cons_q >= QAM_16_SOFT_11) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
        end else if(abs_cons_q < QAM_16_SOFT_11 && abs_cons_q >= QAM_16_SOFT_10) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_6;
        end else if(abs_cons_q < QAM_16_SOFT_10 && abs_cons_q >= QAM_16_SOFT_9) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_5;
        end else if(abs_cons_q < QAM_16_SOFT_9  && abs_cons_q >= QAM_16_SOFT_8) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_4;
        end else if(abs_cons_q < QAM_16_SOFT_8  && abs_cons_q >= QAM_16_SOFT_7) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_3;
        end else if(abs_cons_q < QAM_16_SOFT_7  && abs_cons_q >= QAM_16_SOFT_6) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_2;
        end else if(abs_cons_q < QAM_16_SOFT_6  && abs_cons_q >= QAM_16_SOFT_5) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_1;
        end else if(abs_cons_q < QAM_16_SOFT_5  && abs_cons_q >= QAM_16_SOFT_4) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        //
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_4 && abs_cons_q >= QAM_16_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_0;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_3 && abs_cons_q >= QAM_16_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_1;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_2 && abs_cons_q >= QAM_16_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_2;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_16_SOFT_1 && abs_cons_q >= QAM_16_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_3;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_1 && abs_cons_q >= QAM_16_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_4;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_2 && abs_cons_q >= QAM_16_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_5;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_3 && abs_cons_q >= QAM_16_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_6;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_16_SOFT_4 && abs_cons_q >= QAM_16_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_7;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
        end 
        // else
        //   soft_bits[5:3] <= 3'b011;
        soft_bits_q_old[2] <= SOFT_VALUE_4;

        // // Inphase soft decoded bit positions
        // if(abs_cons_i < QAM_16_SOFT_12 && abs_cons_i >= QAM_16_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b01;
        // else if(abs_cons_i < QAM_16_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b00;
        // else
        //   soft_bits_pos[1:0] <= 2'b11;

        // // Quadrature soft decoded bit positions
        // if(abs_cons_q < QAM_16_SOFT_12 && abs_cons_q >= QAM_16_SOFT_4)
        //   soft_bits_pos[3:2] <= 2'b01;
        // else if(abs_cons_q < QAM_16_SOFT_4)
        //   soft_bits_pos[3:2] <= 2'b00;
        // else
        //   soft_bits_pos[3:2] <= 2'b11;
      end
      QAM_64: begin
        // Inphase soft decoded bits
        // if(abs_cons_i < QAM_64_SOFT_28 && abs_cons_i >= QAM_64_SOFT_27) begin
        if(abs_cons_i >= QAM_64_SOFT_27) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(abs_cons_i < QAM_64_SOFT_27 && abs_cons_i >= QAM_64_SOFT_26) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_6;
        end else if(abs_cons_i < QAM_64_SOFT_26 && abs_cons_i >= QAM_64_SOFT_25) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_5;
        end else if(abs_cons_i < QAM_64_SOFT_25 && abs_cons_i >= QAM_64_SOFT_24) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_4;
        end else if(abs_cons_i < QAM_64_SOFT_24 && abs_cons_i >= QAM_64_SOFT_23) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_3;
        end else if(abs_cons_i < QAM_64_SOFT_23 && abs_cons_i >= QAM_64_SOFT_22) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_2;
        end else if(abs_cons_i < QAM_64_SOFT_22 && abs_cons_i >= QAM_64_SOFT_21) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_1;
        end else if(abs_cons_i < QAM_64_SOFT_21 && abs_cons_i >= QAM_64_SOFT_20) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        // 
        end else if(abs_cons_i < QAM_64_SOFT_20 && abs_cons_i >= QAM_64_SOFT_19) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_7;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_19 && abs_cons_i >= QAM_64_SOFT_18) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_6;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_18 && abs_cons_i >= QAM_64_SOFT_17) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_5;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_17 && abs_cons_i >= QAM_64_SOFT_16) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_4;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_16 && abs_cons_i >= QAM_64_SOFT_15) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_3;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_15 && abs_cons_i >= QAM_64_SOFT_14) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_2;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_14 && abs_cons_i >= QAM_64_SOFT_13) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_1;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_13 && abs_cons_i >= QAM_64_SOFT_12) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        //
        end else if(abs_cons_i < QAM_64_SOFT_12 && abs_cons_i >= QAM_64_SOFT_11) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_i < QAM_64_SOFT_11 && abs_cons_i >= QAM_64_SOFT_10) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_1;
        end else if(abs_cons_i < QAM_64_SOFT_10 && abs_cons_i >= QAM_64_SOFT_9) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_2;
        end else if(abs_cons_i < QAM_64_SOFT_9  && abs_cons_i >= QAM_64_SOFT_8) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_3;
        end else if(abs_cons_i < QAM_64_SOFT_8  && abs_cons_i >= QAM_64_SOFT_7) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_4;
        end else if(abs_cons_i < QAM_64_SOFT_7  && abs_cons_i >= QAM_64_SOFT_6) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_5;
        end else if(abs_cons_i < QAM_64_SOFT_6  && abs_cons_i >= QAM_64_SOFT_5) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_6;
        end else if(abs_cons_i < QAM_64_SOFT_5  && abs_cons_i >= QAM_64_SOFT_4) begin
          soft_bits_i_old[0] <= ( cons_i_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        //
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_4 && abs_cons_i >= QAM_64_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_0;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_3 && abs_cons_i >= QAM_64_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_1;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_2 && abs_cons_i >= QAM_64_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_2;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 0 && abs_cons_i < QAM_64_SOFT_1 && abs_cons_i >= QAM_64_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_3;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_1 && abs_cons_i >= QAM_64_SOFT_0) begin
          soft_bits_i_old[0] <= SOFT_VALUE_4;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_2 && abs_cons_i >= QAM_64_SOFT_1) begin
          soft_bits_i_old[0] <= SOFT_VALUE_5;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_3 && abs_cons_i >= QAM_64_SOFT_2) begin
          soft_bits_i_old[0] <= SOFT_VALUE_6;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end else if(cons_i_delayed[15] == 1 && abs_cons_i < QAM_64_SOFT_4 && abs_cons_i >= QAM_64_SOFT_3) begin
          soft_bits_i_old[0] <= SOFT_VALUE_7;
          soft_bits_i_old[1] <= SOFT_VALUE_0;
          soft_bits_i_old[2] <= SOFT_VALUE_7;
        end 
        // else
        //   soft_bits[2:0] <= 3'b011;

        // Quadrature soft decoded bits
        // if(abs_cons_q < QAM_64_SOFT_28 && abs_cons_q >= QAM_64_SOFT_27) begin
        if(abs_cons_q >= QAM_64_SOFT_27) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(abs_cons_q < QAM_64_SOFT_27 && abs_cons_q >= QAM_64_SOFT_26) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_6;
        end else if(abs_cons_q < QAM_64_SOFT_26 && abs_cons_q >= QAM_64_SOFT_25) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_5;
        end else if(abs_cons_q < QAM_64_SOFT_25 && abs_cons_q >= QAM_64_SOFT_24) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_4;
        end else if(abs_cons_q < QAM_64_SOFT_24 && abs_cons_q >= QAM_64_SOFT_23) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_3;
        end else if(abs_cons_q < QAM_64_SOFT_23 && abs_cons_q >= QAM_64_SOFT_22) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_2;
        end else if(abs_cons_q < QAM_64_SOFT_22 && abs_cons_q >= QAM_64_SOFT_21) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_1;
        end else if(abs_cons_q < QAM_64_SOFT_21 && abs_cons_q >= QAM_64_SOFT_20) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        //
        end else if(abs_cons_q < QAM_64_SOFT_20 && abs_cons_q >= QAM_64_SOFT_19) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_7;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_19 && abs_cons_q >= QAM_64_SOFT_18) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_6;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_18 && abs_cons_q >= QAM_64_SOFT_17) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_5;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_17 && abs_cons_q >= QAM_64_SOFT_16) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_4;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_16 && abs_cons_q >= QAM_64_SOFT_15) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_3;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_15 && abs_cons_q >= QAM_64_SOFT_14) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_2;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_14 && abs_cons_q >= QAM_64_SOFT_13) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_1;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_13 && abs_cons_q >= QAM_64_SOFT_12) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        //
        end else if(abs_cons_q < QAM_64_SOFT_12 && abs_cons_q >= QAM_64_SOFT_11) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_0;
        end else if(abs_cons_q < QAM_64_SOFT_11 && abs_cons_q >= QAM_64_SOFT_10) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_1;
        end else if(abs_cons_q < QAM_64_SOFT_10 && abs_cons_q >= QAM_64_SOFT_9) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_2;
        end else if(abs_cons_q < QAM_64_SOFT_9  && abs_cons_q >= QAM_64_SOFT_8) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_3;
        end else if(abs_cons_q < QAM_64_SOFT_8  && abs_cons_q >= QAM_64_SOFT_7) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_4;
        end else if(abs_cons_q < QAM_64_SOFT_7  && abs_cons_q >= QAM_64_SOFT_6) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_5;
        end else if(abs_cons_q < QAM_64_SOFT_6  && abs_cons_q >= QAM_64_SOFT_5) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_6;
        end else if(abs_cons_q < QAM_64_SOFT_5  && abs_cons_q >= QAM_64_SOFT_4) begin
          soft_bits_q_old[0] <= ( cons_q_delayed[15]? SOFT_VALUE_7 : SOFT_VALUE_0 );
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        //
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_4 && abs_cons_q >= QAM_64_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_0;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_3 && abs_cons_q >= QAM_64_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_1;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_2 && abs_cons_q >= QAM_64_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_2;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 0 && abs_cons_q < QAM_64_SOFT_1 && abs_cons_q >= QAM_64_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_3;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_1 && abs_cons_q >= QAM_64_SOFT_0) begin
          soft_bits_q_old[0] <= SOFT_VALUE_4;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_2 && abs_cons_q >= QAM_64_SOFT_1) begin
          soft_bits_q_old[0] <= SOFT_VALUE_5;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_3 && abs_cons_q >= QAM_64_SOFT_2) begin
          soft_bits_q_old[0] <= SOFT_VALUE_6;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end else if(cons_q_delayed[15] == 1 && abs_cons_q < QAM_64_SOFT_4 && abs_cons_q >= QAM_64_SOFT_3) begin
          soft_bits_q_old[0] <= SOFT_VALUE_7;
          soft_bits_q_old[1] <= SOFT_VALUE_0;
          soft_bits_q_old[2] <= SOFT_VALUE_7;
        end 
        // else
        //   soft_bits[5:3] <= 3'b011;

        // // Inphase soft decoded bit positions
        // if(abs_cons_i < QAM_64_SOFT_28 && abs_cons_i >= QAM_64_SOFT_20)
        //   soft_bits_pos[1:0] <= 2'b10;
        // else if(abs_cons_i < QAM_64_SOFT_20 && abs_cons_i >= QAM_64_SOFT_12)
        //   soft_bits_pos[1:0] <= 2'b01;
        // else if(abs_cons_i < QAM_64_SOFT_12 && abs_cons_i >= QAM_64_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b10;
        // else if(abs_cons_i < QAM_64_SOFT_4)
        //   soft_bits_pos[1:0] <= 2'b00;
        // else
        //   soft_bits_pos[1:0] <= 2'b11;

        // // Quadrature soft decoded bit positions
        // if(abs_cons_q < QAM_64_SOFT_28 && abs_cons_q >= QAM_64_SOFT_20)
        //   soft_bits_pos[3:2] <= 2'b10;
        // else if(abs_cons_q < QAM_64_SOFT_20 && abs_cons_q >= QAM_64_SOFT_12)
        //   soft_bits_pos[3:2] <= 2'b01;
        // else if(abs_cons_q < QAM_64_SOFT_12 && abs_cons_q >= QAM_64_SOFT_4)
        //   soft_bits_pos[3:2] <= 2'b10;
        // else if(abs_cons_q < QAM_64_SOFT_4)
        //   soft_bits_pos[3:2] <= 2'b00;
        // else
        //   soft_bits_pos[3:2] <= 2'b11;
      end
    endcase
  end
end

`else

always @(posedge clock) begin
  soft_bits_i_old_delay2[0] <= 0;
  soft_bits_i_old_delay2[1] <= 0;
  soft_bits_i_old_delay2[2] <= 0;
  soft_bits_q_old_delay2[0] <= 0;
  soft_bits_q_old_delay2[1] <= 0;
  soft_bits_q_old_delay2[2] <= 0;
end

`endif

endmodule
