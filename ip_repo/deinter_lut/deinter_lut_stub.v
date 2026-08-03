// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Sun Jul 28 12:17:19 2024
// Host        : PC1008 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/Data/RASentinel/owifi/openwifi-hw/ip/openofdm_rx/ip_repo/deinter_lut/deinter_lut_stub.v
// Design      : deinter_lut
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg484-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_8,Vivado 2024.1" *)
module deinter_lut(clka, addra, douta)
/* synthesis syn_black_box black_box_pad_pin="addra[11:0],douta[21:0]" */
/* synthesis syn_force_seq_prim="clka" */;
  input clka /* synthesis syn_isclock = 1 */;
  input [11:0]addra;
  output [21:0]douta;
endmodule
