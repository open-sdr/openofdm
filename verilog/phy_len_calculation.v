//////////////////////////////////////////////////////////////////////////////////
// 
// Project Name: RA-Sentinel
// 
// Module Name: phy_len_calculation
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

// Xianjun jiao. putaoshu@msn.com; xianjun.jiao@imec.be;

// Calculate PHY related info:
// o_n_ofdm_sym, o_n_bit_in_last_sym (for decoding latency prediction)

module phy_len_calculation
(
    input i_clock,
    input i_reset,
    input i_enable,

    input [4:0]   i_state,
    input [4:0]   i_old_state,
    input [19:0]  i_num_bits_to_decode,
    input [7:0]   i_pkt_rate,//bit [7] 1 means ht; 0 means non-ht
    
    output reg [14:0] o_n_ofdm_sym,//max 20166 = (22+65535*8)/26
    output reg [19:0] o_n_bit_in_last_sym,//max ht ndbps 260
    output reg        o_phy_len_valid
);

reg start_calculation;
reg   end_calculation;

reg [8:0] n_dbps;

// lookup table for N_DBPS (Number of data bits per OFDM symbol)
always @( i_pkt_rate[7],i_pkt_rate[3:0] )
begin
    case ({i_pkt_rate[7],i_pkt_rate[3:0]})
        5'b01011 : begin //non-ht 6Mbps
            n_dbps = 24;
            end
        5'b01111 : begin //non-ht 9Mbps
            n_dbps = 36;
            end
        5'b01010 : begin //non-ht 12Mbps
            n_dbps = 48;
            end
        5'b01110 : begin //non-ht 18Mbps
            n_dbps = 72;
            end
        5'b01001 :  begin //non-ht 24Mbps
            n_dbps = 96;
            end
        5'b01101 : begin //non-ht 36Mbps
            n_dbps = 144;
            end
        5'b01000  : begin //non-ht 48Mbps
            n_dbps = 192;
            end
        5'b01100 : begin //non-ht 54Mbps
            n_dbps = 216;
            end
        5'b10000 : begin //ht mcs 0
            n_dbps = 26;
            end
        5'b10001 : begin //ht mcs 1
            n_dbps = 52;
            end
        5'b10010 : begin //ht mcs 2
            n_dbps = 78;
            end
        5'b10011 : begin //ht mcs 3
            n_dbps = 104;
            end
        5'b10100 :  begin //ht mcs 4
            n_dbps = 156;
            end
        5'b10101 : begin //ht mcs 5
            n_dbps = 208;
            end
        5'b10110  : begin //ht mcs 6
            n_dbps = 234;
            end
        5'b10111 : begin //ht mcs 7
            n_dbps = 260;
            end
        default: begin
            n_dbps = 0;
            end
    endcase
end

`include "common_params.v"
always @(posedge i_clock) begin
if (i_reset) begin
    o_n_ofdm_sym <= 1;
    o_n_bit_in_last_sym <= 130; // half of max num bits to have a rough mid-point estimation in case no calculation happen
    o_phy_len_valid <= 0;
    start_calculation <= 0;
    end_calculation <= 0;
end else begin
    if ( (i_state != S_HT_SIG_ERROR && i_old_state == S_CHECK_HT_SIG) || ((i_state == S_DECODE_DATA && (i_old_state == S_CHECK_SIGNAL || i_old_state == S_DETECT_HT))) ) begin
        o_n_bit_in_last_sym <= i_num_bits_to_decode;
        if (i_num_bits_to_decode <= n_dbps) begin
            o_phy_len_valid <= 1;
            end_calculation <= 1;
        end else begin
            start_calculation <= 1;
        end
    end

    if (start_calculation == 1 && end_calculation != 1) begin
        if (o_n_bit_in_last_sym <= n_dbps) begin
            o_phy_len_valid <= 1;
            end_calculation <= 1;
        end else begin
            o_n_bit_in_last_sym <= o_n_bit_in_last_sym - n_dbps;
            o_n_ofdm_sym = o_n_ofdm_sym + 1;
        end
    end
end
end

endmodule

