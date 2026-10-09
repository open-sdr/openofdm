//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: running_sum_dual_ch
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

module running_sum_dual_ch
#(
    parameter DATA_WIDTH0 = 16,
    parameter DATA_WIDTH1 = 16,
    parameter LOG2_SUM_LEN = 6
)
(
    input i_clock,
    input i_nreset,

    input signed [DATA_WIDTH0-1:0] i_data_in0,
    input signed [DATA_WIDTH1-1:0] i_data_in1,
    input i_data_in_valid,

    output reg signed [(DATA_WIDTH0 + LOG2_SUM_LEN-1):0] o_running_sum_result0,
    output reg signed [(DATA_WIDTH1 + LOG2_SUM_LEN-1):0] o_running_sum_result1,
    output reg o_data_out_valid
);

localparam FIFO_SIZE = 1<<LOG2_SUM_LEN;
localparam TOTAL_WIDTH0 = DATA_WIDTH0 + LOG2_SUM_LEN;
localparam TOTAL_WIDTH1 = DATA_WIDTH1 + LOG2_SUM_LEN;

wire signed [DATA_WIDTH0-1:0] data_in_old0;
wire signed [DATA_WIDTH1-1:0] data_in_old1;

wire signed [TOTAL_WIDTH0-1:0] ext_data_in_old0 = {{LOG2_SUM_LEN{data_in_old0[DATA_WIDTH0-1]}}, data_in_old0};
wire signed [TOTAL_WIDTH0-1:0] ext_data_in0     = {{LOG2_SUM_LEN{i_data_in0[DATA_WIDTH0-1]}},     i_data_in0    };

wire signed [TOTAL_WIDTH1-1:0] ext_data_in_old1 = {{LOG2_SUM_LEN{data_in_old1[DATA_WIDTH1-1]}}, data_in_old1};
wire signed [TOTAL_WIDTH1-1:0] ext_data_in1     = {{LOG2_SUM_LEN{i_data_in1[DATA_WIDTH1-1]}},     i_data_in1    };

reg data_in_valid_reg;
reg rd_en, rd_en_start;
wire [LOG2_SUM_LEN:0] wr_data_count;
wire empty;

xpm_fifo_sync #(
    .DOUT_RESET_VALUE("0"),    // String
    .ECC_MODE("no_ecc"),       // String
    .FIFO_MEMORY_TYPE("auto"), // String
    .FIFO_READ_LATENCY(0),     // DECIMAL
    .FIFO_WRITE_DEPTH(FIFO_SIZE),   // DECIMAL
    .FULL_RESET_VALUE(0),      // DECIMAL
    .PROG_EMPTY_THRESH(10),    // DECIMAL
    .PROG_FULL_THRESH(10),     // DECIMAL
    .RD_DATA_COUNT_WIDTH(LOG2_SUM_LEN+1),   // DECIMAL
    .READ_DATA_WIDTH(DATA_WIDTH0+DATA_WIDTH1),      // DECIMAL
    .READ_MODE("fwft"),         // String
    .USE_ADV_FEATURES("0404"), // only enable rd_data_count and wr_data_count
    .WAKEUP_TIME(0),           // DECIMAL
    .WRITE_DATA_WIDTH(DATA_WIDTH0+DATA_WIDTH1),     // DECIMAL
    .WR_DATA_COUNT_WIDTH(LOG2_SUM_LEN+1)    // DECIMAL
) fifo_1o_clock_for_running_sum_dual_ch_i (
    .almost_empty(),
    .almost_full(),
    .data_valid(),
    .dbiterr(),
    .dout({data_in_old1, data_in_old0}),
    .empty(empty),
    .full(full),
    .overflow(),
    .prog_empty(),
    .prog_full(),
    .rd_data_count(),
    .rd_rst_busy(),
    .sbiterr(),
    .underflow(),
    .wr_ack(),
    .wr_data_count(wr_data_count),
    .wr_rst_busy(),
    .din({i_data_in1, i_data_in0}),
    .injectdbiterr(),
    .injectsbiterr(),
    .rd_en(rd_en),
    .rst(~i_nreset),
    .sleep(),
    .wr_clk(i_clock),
    .wr_en(i_data_in_valid)
  );

always @(posedge i_clock) begin
    if (~i_nreset) begin
        data_in_valid_reg <= 0;
        o_running_sum_result0 <= 0;
        o_running_sum_result1 <= 0;
        o_data_out_valid <= 0;
        rd_en <= 0;
        rd_en_start <= 0;
    end else begin
        data_in_valid_reg <= i_data_in_valid;
        o_data_out_valid <= data_in_valid_reg;
        rd_en_start <= ((wr_data_count == FIFO_SIZE)?1:rd_en_start);
        rd_en <= (rd_en_start?i_data_in_valid:rd_en);
        if (i_data_in_valid) begin
            o_running_sum_result0 <= o_running_sum_result0 + ext_data_in0 - (rd_en_start?ext_data_in_old0:0);
            o_running_sum_result1 <= o_running_sum_result1 + ext_data_in1 - (rd_en_start?ext_data_in_old1:0);
        end
    end
end

endmodule

