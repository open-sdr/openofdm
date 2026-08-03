// Slight modifications, signal renaming by T. Weber 2024
// for the Project RA-Sentinel https://nlnet.nl/project/RA-Sentinel/
//
// Copyright 2011 Ettus Research LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module ram_2port
#(
    parameter DWIDTH=32,
    parameter AWIDTH=9
)
(
    input i_clka,
    input i_ena,
    input i_wea,
    input [AWIDTH-1:0] i_addra,
    input [DWIDTH-1:0] i_dia,
    output reg [DWIDTH-1:0] o_doa,

    input i_clkb,
    input i_enb,
    input i_web,
    input [AWIDTH-1:0] i_addrb,
    input [DWIDTH-1:0] i_dib,
    output reg [DWIDTH-1:0] o_dob
);

reg [DWIDTH-1:0] ram [(1<<AWIDTH)-1:0];
integer 	    i;
initial begin
    for(i=0;i<(1<<AWIDTH);i=i+1)
        ram[i] <= {DWIDTH{1'b0}};
    o_doa <= 0;
    o_dob <= 0;
end

always @(posedge i_clka) begin
    if (i_ena) 
    begin
        if (i_wea)
            ram[i_addra] <= i_dia;
        o_doa <= ram[i_addra];
    end
end
always @(posedge i_clkb) begin
    if (i_enb)
    begin
        if (i_web)
            ram[i_addrb] <= i_dib;
        o_dob <= ram[i_addrb];
    end
end
endmodule // ram_2port

