//////////////////////////////////////////////////////////////////////////////////
// 
// Design Name: RASM2400
// Module Name: LVDS_RX
// Project Name: Radio Access Spectrum Monitor 2400MHz
// Engineer: Tobias Weber
// Target Devices: Artix 7, XC7A100T
// Create Date: 25.04.2024 10:29:54
// Tool Versions: Vivado 2024.1
// Description:  Receives and deserializes sample data coming from
//               the ADC via 2x2 LVDS data lines.
// 
// Dependencies: none
// 
// Revision 1.01
// Additional Comments: https://github.com/Tobias-DG3YEV/RA-Sentinel
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

/* this depicts the input data stream we get from the ADC322x
				  _________         ___
Frame FCLK		_|        |________|
                  ______      ___
Data			_|     |_____|  |______
				   ___   ___   ___   __
Data DCLK		__|  |__|  |__|  |__|  
Bit #			  0  1  2  3  4  5  0  
Value (LSB first) 1  1  0  0  1  0  0 => reversed to 10011 = 13 hex.
*/

module lvds_rx #(
	parameter WORDWIDTH = 12 //sample width in bits
)
(
    input wire i_lvds_dclk_P, // 120/60 MHz
    input wire i_lvds_dclk_N, // 120/60 MHz
    input wire i_lvds_fclk_P, // 40/20 MHz
    input wire i_lvds_fclk_N, // 40/20 MHz
    input wire i_lvds_dr0_P,  // data lane 0 real part, lower bits
    input wire i_lvds_dr0_N,  // data lane 0 real part, lower bits
    input wire i_lvds_di0_P,  // data lane 0 imaginary part, higher 6 bits
    input wire i_lvds_di0_N,  // data lane 0 imaginary part, higher 6 bits
    input wire i_lvds_dr1_P,  // data lane 1 real part, lower 6 bits
    input wire i_lvds_dr1_N,  // data lane 1 real part, lower 6 bits
    input wire i_lvds_di1_P,  // data lane 1 imaginary part, higher 6 bits
    input wire i_lvds_di1_N,  // data lane 1 imaginary part, higher 6 bits
	input wire i_rst,       // module reset, active high
	input wire i_delayClk,  // 195-200MHz Delay Clock
    output wire o_parFrameRdy, // paralell frame can be read when this goes high.
    output wire [11:0] o_dataOut_R,  // parallel data, real part
    output wire [11:0] o_dataOut_I,   // parallel data, imaginary part
    output wire o_lvds_dclk,
    output wire o_lvds_fclk
);

// sync states
localparam state_powerOn 	= 2'b00;
localparam state_syncing 	= 2'b01;
localparam state_init       = 2'b10;
localparam state_initdone   = 2'b11;
	
reg fclk_delayed;
reg [2:0] ctr;
reg trig;
initial trig = 0;

reg [1:0] initSM; // sync state machine counter
initial initSM = 0;
reg serdesNreset;
initial serdesNreset = 1'b0;
reg serdesCS;
initial serdesCS = 1'b0;

// unbalancers

localparam C_IODELAY_GROUP = "adc_if_delay_group";
`ifdef SIMULATION
localparam DATA_DELAY_VALUE_DR0 = 0; /* data line delay */
localparam DATA_DELAY_VALUE_DR1 = 0;
localparam DATA_DELAY_VALUE_DI0 = 0;
localparam DATA_DELAY_VALUE_DI1 = 0;
localparam DCLK_DELAY = 0; // Bit Clock Delay
localparam FS_DELAY = 0;  // Frame Sync delay
`else // !SIMULATION
localparam DATA_DELAY_VALUE_DR0 = 31; /* data line delay */
localparam DATA_DELAY_VALUE_DR1 = 28;
localparam DATA_DELAY_VALUE_DI0 = 28;
localparam DATA_DELAY_VALUE_DI1 = 28;
localparam DCLK_DELAY = 0; // Bit Clock Delay
localparam FS_DELAY = 0;  // Frame Sync delay
`endif // !SIMULATION
localparam DLYTYPE = "FIXED";

reg [5:0] lineDelayCS; /* the CS lines of the delaIDELAYE units. */
initial lineDelayCS = 6'b111111;
wire lineDelayInc;
assign lineDelayInc = 0;


// delays

/****************************************************************************/

//    #######  ######      #     #     #  #######
//    #        #     #    # #    ##   ##  #
//    #        #     #   #   #   # # # #  #
//    #####    ######   #     #  #  #  #  #####
//    #        #   #    #######  #     #  #
//    #        #    #   #     #  #     #  #
//    #        #     #  #     #  #     #  #######


wire lvds_fclk_BUFDS;
IBUFDS #(
	.CAPACITANCE("DONT_CARE"),
	.DIFF_TERM("TRUE"),
	.IOSTANDARD("DEFAULT")
)  IBUFDS_adc_frame0 (
	.O(lvds_fclk_BUFDS), // 40/20 MHz
	.I(i_lvds_fclk_P),
	.IB(i_lvds_fclk_N)
);

//wire lvds_fclk; // 40/20 MHz buffered and delayed
(* keep = "true" *) wire [4:0] fclk_cntval;

IDELAYE2 #(
 .CINVCTRL_SEL ("FALSE"),
 .DELAY_SRC ("IDATAIN"),
 .HIGH_PERFORMANCE_MODE ("TRUE"),
 .IDELAY_TYPE(DLYTYPE),
 .IDELAY_VALUE(FS_DELAY),
 .REFCLK_FREQUENCY (195.0),
 .PIPE_SEL ("FALSE"),
 .SIGNAL_PATTERN ("CLOCK")
)
IDELAYE2_fclk (
 .CE (lineDelayCS[4]),
 .INC(lineDelayInc),
 .DATAIN (1'b0),
 .CINVCTRL (1'b0),
 .REGRST (1'b0),
 .C (clk_195M),
 .IDATAIN (lvds_fclk_BUFDS),
 .DATAOUT (o_lvds_fclk),
 .LD (1'b0),
 .CNTVALUEIN (1'b0),
 .CNTVALUEOUT(fclk_cntval),
 .LDPIPEEN(1'b0) // added to keep Vivado quiet
);

//    ######    #####   #        #    #
//    #     #  #     #  #        #   #
//    #     #  #        #        #  #
//    #     #  #        #        ###
//    #     #  #        #        #  #
//    #     #  #     #  #        #   #
//    ######    #####   #######  #    #

wire lvds_dclk_BUFDS;

IBUFDS #(
	.CAPACITANCE("DONT_CARE"),
	.DIFF_TERM("TRUE"),
	.IOSTANDARD("DEFAULT")
)  IBUFDS_adc_dclk (
	.O(lvds_dclk_BUFDS), // 120/60MHz
	.I(i_lvds_dclk_P),
	.IB(i_lvds_dclk_N)
);

//wire lvds_dclk;
IDELAYE2 #(
 .CINVCTRL_SEL ("FALSE"),
 .DELAY_SRC ("IDATAIN"),
 .HIGH_PERFORMANCE_MODE ("TRUE"),
 .IDELAY_TYPE(DLYTYPE),
 .IDELAY_VALUE(DCLK_DELAY),
 .REFCLK_FREQUENCY (195.0),
 .PIPE_SEL ("FALSE"),
 .SIGNAL_PATTERN ("CLOCK")
)
IDELAYE2_dclk (
 .CE  (lineDelayCS[5]),
 .INC (lineDelayInc),
 .DATAIN (1'b0),
 .LDPIPEEN (1'b0),
 .CINVCTRL (1'b0),
 .C (clk_195M),
 .IDATAIN (lvds_dclk_BUFDS),
 .DATAOUT (o_lvds_dclk),
 .LD (1'b0),
 .CNTVALUEIN (1'b0),
 .CNTVALUEOUT(),
 .REGRST(1'b0) // added to keep Vivado quiet
);

//	######   ######   ######          ######      #     #######     #
//	#     #  #     #  #     #         #     #    # #       #       # #
//	#     #  #     #  #     #         #     #   #   #      #      #   #
//	#     #  #     #  ######          #     #  #     #     #     #     #
//	#     #  #     #  #   #           #     #  #######     #     #######
//	#     #  #     #  #    #          #     #  #     #     #     #     #
//	######   ######   #     #         ######   #     #     #     #     #


// Intermediate signals
wire [3:0] ibufds_out;
wire [3:0] lvds_ddly; /* delayed ADC data */
wire [3:0] din_p;
wire [3:0] din_n;

// dr0   dr1,  di0,  di1
assign din_p[0] = i_lvds_dr0_P;
assign din_p[1] = i_lvds_dr1_P;
assign din_p[2] = i_lvds_di0_P;
assign din_p[3] = i_lvds_di1_P;
assign din_n[0] = i_lvds_dr0_N;
assign din_n[1] = i_lvds_dr1_N;
assign din_n[2] = i_lvds_di0_N;
assign din_n[3] = i_lvds_di1_N;

genvar i;
generate
	for (i = 0; i < 4; i = i + 1) begin : gen_ibufds_idelaye2

		IBUFDS #(
			.CAPACITANCE("DONT_CARE"),
			.DIFF_TERM("TRUE"),
			.IOSTANDARD("DEFAULT")
		)  IBUFDS_adc_inst (
			.O(ibufds_out[i]), // Buffer output
            .I(din_p[i]),      // Diff_p buffer input (connect directly to top-level port)
            .IB(din_n[i])      // Diff_n buffer input (connect directly to top-level port)
        );

		IDELAYE2 #(
			.CINVCTRL_SEL ("FALSE"),
			.DELAY_SRC ("IDATAIN"),
			.HIGH_PERFORMANCE_MODE ("TRUE"),
			.IDELAY_TYPE(DLYTYPE),
			.IDELAY_VALUE((i == 0) ? DATA_DELAY_VALUE_DR0 :	
                              (i == 1) ? DATA_DELAY_VALUE_DR1 :
                              (i == 2) ? DATA_DELAY_VALUE_DI0 :
                                         DATA_DELAY_VALUE_DI0), // Specify the input delay tap setting			
			.REFCLK_FREQUENCY (195.0),
			.PIPE_SEL ("FALSE"),
			.SIGNAL_PATTERN ("DATA")
		)
		IDELAYE2_data_inst (
			.CE ((i == 0) ? lineDelayCS[0] :	
                 (i == 1) ? lineDelayCS[1] :
                 (i == 2) ? lineDelayCS[2] :
                 (i == 3) ? lineDelayCS[3] :
                 1'b0),
			.INC(lineDelayInc),
			.DATAIN (1'b0),
			.LDPIPEEN (1'b0),
			.CINVCTRL (1'b0),
			.REGRST (1'b0),
			.C (clk_195M),
			.IDATAIN (ibufds_out[i]),
			.DATAOUT (lvds_ddly[i]),
			.LD ("VARIABLE"),
			.CNTVALUEIN (1'b0),
			.CNTVALUEOUT()
		);
	end
endgenerate



/*********************************

 ISERDES instantiation

**********************************/

    // Parameters for the ISERDESE2 configuration
    localparam SERDES_MODE = "MASTER";
    localparam DATA_RATE = "DDR";
    localparam DATA_WIDTH = 6;
    localparam INTERFACE_TYPE = "NETWORKING";

        // Intermediate signals
    wire [3:0] din;
	assign din[0] = lvds_ddly[0];
	assign din[1] = lvds_ddly[1];
	assign din[2] = lvds_ddly[2];
	assign din[3] = lvds_ddly[3];

	wire [3:0] q1;
	wire [3:0] q2;
	wire [3:0] q3;
	wire [3:0] q4;
	wire [3:0] q5;
	wire [3:0] q6;

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : gen_idelaye2_iserdese2

            // Instantiate ISERDESE2
            ISERDESE2 #(
                .DATA_RATE(DATA_RATE),       // Data rate (SDR or DDR)
                .DATA_WIDTH(DATA_WIDTH),     // Parallel data width (2 to 8)
                .INTERFACE_TYPE(INTERFACE_TYPE), // Interface type (NETWORKING, RETIMED)
                .NUM_CE(1),                  // Number of clock enables
                .OFB_USED("FALSE"),          // OFB usage
                .SERDES_MODE(SERDES_MODE),   // Master or Slave mode
				.DYN_CLKDIV_INV_EN("FALSE"),
				.DYN_CLK_INV_EN("FALSE"),
				.IOBDELAY("BOTH")
            ) ISERDESE2_inst (
                .Q1(q1[j]),       // 1-bit output: First parallel data output
                .Q2(q2[j]),       // 1-bit output: Second parallel data output
                .Q3(q3[j]),       // 1-bit output: Third parallel data output
                .Q4(q4[j]),       // 1-bit output: Fourth parallel data output
				.Q5(q5[j]),
				.Q6(q6[j]),
                .SHIFTOUT1(),     // 1-bit output: Connects to SHIFTOUT1 of another ISERDESE2 for chaining
                .SHIFTOUT2(),     // 1-bit output: Connects to SHIFTOUT2 of another ISERDESE2 for chaining
                .BITSLIP(1'b0),   // 1-bit input: Bitslip pin for word alignment
				.DYNCLKSEL(1'b0), // Dynamically select CLK and CLKB inversion. 
				.DYNCLKDIVSEL(1'b0), // Dynamically select CLKDIV inversion. 
                .CE1( serdesCS ),   // 1-bit input: Clock enable input
                .CE2(1'b0),         // 1-bit input: Clock enable input
                .CLK( lvds_dclk ),     // 1-bit input: High-speed clock input
                .CLKB( ~lvds_dclk ),   // 1-bit input: Inverted high-speed clock input
                .CLKDIV( fclk_delayed ), // 1-bit input: Divided clock input
                .CLKDIVP(1'b0),          // 1-bit input: Phase-aligned divided clock input
                .D(1'b0),         // 1-bit input: Serial data input
                .DDLY(din[j]),    // 1-bit input: Delayed serial data input
                .OFB(1'b0),       // 1-bit input: Feedback path
                .RST( ~serdesNreset ), // 1-bit input: Reset input
                .SHIFTIN1(1'b0),  // 1-bit input: Connects to SHIFTIN1 of another ISERDESE2 for chaining
                .SHIFTIN2(1'b0)   // 1-bit input: Connects to SHIFTIN2 of another ISERDESE2 for chaining
            );
        end
    endgenerate

	assign o_dataOut_R = { q1[1], q2[1], q3[1], q4[1], q5[1], q6[1], q1[0], q2[0], q3[0], q4[0], q5[0], q6[0] };
	assign o_dataOut_I = { q1[3], q2[3], q3[3], q4[3], q5[3], q6[3], q1[2], q2[2], q3[2], q4[2], q5[2], q6[2] };
	
	assign o_parFrameRdy = ~fclk_delayed;


    
    // sync state machine. It syncs the ISERDESE2 modules to the ADC frame clock
    
    always @(posedge o_lvds_dclk or posedge i_rst) // 60MHz driven
    begin
        if(i_rst == 1'b1) begin
           ctr <= 0;
           fclk_delayed <= 0;
           trig <= 0;
        end
        // sync everything with frame start
        else begin
            // work signal generator
            if(o_lvds_fclk == 1 && trig == 0) begin
                trig <= 1;
                ctr <= 0;
                fclk_delayed <= 0;
            end
            else begin
                ctr <= ctr + 1;
                trig <= 0;
            end
              
           if(ctr >= 1 && ctr <= 2)
               fclk_delayed <= 0;
           else
               fclk_delayed <= 1;
        end
    end
    
    always @(negedge o_lvds_dclk or posedge i_rst) // 60MHz driven
    begin
        if(i_rst == 1'b1) begin
           initSM <= state_powerOn;
           serdesNreset <= 0;
           serdesCS <= 1'b0;
        end
        // sync everything with frame start
        else begin
            case (initSM)
                state_powerOn: begin
                    if (o_lvds_fclk == 0) begin
                        initSM <= state_syncing;
                        serdesCS <= 1'b0;
                    end
                end
    
                state_syncing: begin
                    if (o_lvds_fclk == 1) begin
                        initSM <= state_init;
                        serdesNreset <= 1'b1;
                    end
                end
    
                state_init: begin
                    initSM <= state_initdone;
                end
    
                state_initdone: begin
                    if(ctr == 0) begin
                        serdesCS <= 1'b1;
                    end
                end
                
            endcase
        end
    end 


endmodule
