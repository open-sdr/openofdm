//////////////////////////////////////////////////////////////////////////////////
//
// Design Name: openofdm
// Module Name: rot_lut / atan_lut / deinter_lut
// Description:
//   Plain-RTL replacements for openofdm's three ISE-era coregen ROM "IPs"
//   (.xco/.ngc relics whose .xci conversions no longer synthesize under
//   Vivado 2025.x). Each is an inferred block ROM initialized with
//   $readmemb from the ORIGINAL coregen .mif - bit-identical contents,
//   same 1-cycle output-register latency the instantiating code counts on
//   (phase.v pipelines "1 cycle for atan_lut" explicitly).
//
//   PATHS: both synthesis and XSim resolve a relative $readmem path against
//   the tool's working directory, not against this file - so the directory
//   holding the .mif files is passed in as a macro instead. Every build
//   script that reads this file sets it:
//
//       synth_design ... -verilog_define LUT_DIR="$ofdm/verilog"
//       xvlog        ... -d LUT_DIR="$ofdm/verilog"
//
//   The default below only works when the tool happens to be launched from
//   this directory; it exists so a bare `xvlog lut_roms.v` still elaborates.
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

`ifndef LUT_DIR
`define LUT_DIR "."
`endif

/* 512 x 32 dual-port ROM: rotation phasors for sync_long + equalizer */
module rot_lut (
    input  wire        clka,
    input  wire [8:0]  addra,
    output reg  [31:0] douta,
    input  wire        enb,
    input  wire        clkb,
    input  wire [8:0]  addrb,
    output reg  [31:0] doutb
);
    (* rom_style = "block" *) reg [31:0] mem [0:511];
    initial $readmemb({`LUT_DIR, "/rot_lut.mif"}, mem);
    always @(posedge clka) douta <= mem[addra];
    always @(posedge clkb) if (enb) doutb <= mem[addrb];
endmodule

/* 512 x 9 ROM: arctan lookup for the phase estimator */
module atan_lut (
    input  wire       clka,
    input  wire [8:0] addra,
    output reg  [8:0] douta
);
    (* rom_style = "block" *) reg [8:0] mem [0:511];
    initial $readmemb({`LUT_DIR, "/atan_lut.mif"}, mem);
    always @(posedge clka) douta <= mem[addra];
endmodule

/* 4096 x 22 ROM: deinterleaver address map */
module deinter_lut (
    input  wire        clka,
    input  wire [11:0] addra,
    output reg  [21:0] douta
);
    (* rom_style = "block" *) reg [21:0] mem [0:4095];
    initial $readmemb({`LUT_DIR, "/deinter_lut_from_coe.mif"}, mem);
    always @(posedge clka) douta <= mem[addra];
endmodule
