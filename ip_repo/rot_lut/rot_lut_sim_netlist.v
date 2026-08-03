// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Sun Jul 28 12:17:18 2024
// Host        : PC1008 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               d:/Data/RASentinel/owifi/openwifi-hw/ip/openofdm_rx/ip_repo/rot_lut/rot_lut_sim_netlist.v
// Design      : rot_lut
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z020clg484-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "rot_lut,blk_mem_gen_v8_4_8,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "blk_mem_gen_v8_4_8,Vivado 2024.1" *) 
(* NotValidForBitStream *)
module rot_lut
   (clka,
    addra,
    douta,
    clkb,
    enb,
    addrb,
    doutb);
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTA, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clka;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *) input [8:0]addra;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *) output [31:0]douta;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *) (* x_interface_parameter = "XIL_INTERFACENAME BRAM_PORTB, MEM_ADDRESS_MODE BYTE_ADDRESS, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, MASTER_TYPE OTHER, READ_LATENCY 1" *) input clkb;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *) input enb;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *) input [8:0]addrb;
  (* x_interface_info = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *) output [31:0]doutb;

  wire [8:0]addra;
  wire [8:0]addrb;
  wire clka;
  wire [31:0]douta;
  wire [31:0]doutb;
  wire enb;
  wire NLW_U0_dbiterr_UNCONNECTED;
  wire NLW_U0_rsta_busy_UNCONNECTED;
  wire NLW_U0_rstb_busy_UNCONNECTED;
  wire NLW_U0_s_axi_arready_UNCONNECTED;
  wire NLW_U0_s_axi_awready_UNCONNECTED;
  wire NLW_U0_s_axi_bvalid_UNCONNECTED;
  wire NLW_U0_s_axi_dbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_rlast_UNCONNECTED;
  wire NLW_U0_s_axi_rvalid_UNCONNECTED;
  wire NLW_U0_s_axi_sbiterr_UNCONNECTED;
  wire NLW_U0_s_axi_wready_UNCONNECTED;
  wire NLW_U0_sbiterr_UNCONNECTED;
  wire [8:0]NLW_U0_rdaddrecc_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_bid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_bresp_UNCONNECTED;
  wire [8:0]NLW_U0_s_axi_rdaddrecc_UNCONNECTED;
  wire [31:0]NLW_U0_s_axi_rdata_UNCONNECTED;
  wire [3:0]NLW_U0_s_axi_rid_UNCONNECTED;
  wire [1:0]NLW_U0_s_axi_rresp_UNCONNECTED;

  (* C_ADDRA_WIDTH = "9" *) 
  (* C_ADDRB_WIDTH = "9" *) 
  (* C_ALGORITHM = "1" *) 
  (* C_AXI_ID_WIDTH = "4" *) 
  (* C_AXI_SLAVE_TYPE = "0" *) 
  (* C_AXI_TYPE = "1" *) 
  (* C_BYTE_SIZE = "9" *) 
  (* C_COMMON_CLK = "1" *) 
  (* C_COUNT_18K_BRAM = "0" *) 
  (* C_COUNT_36K_BRAM = "1" *) 
  (* C_CTRL_ECC_ALGO = "NONE" *) 
  (* C_DEFAULT_DATA = "0" *) 
  (* C_DISABLE_WARN_BHV_COLL = "0" *) 
  (* C_DISABLE_WARN_BHV_RANGE = "0" *) 
  (* C_ELABORATION_DIR = "./" *) 
  (* C_ENABLE_32BIT_ADDRESS = "0" *) 
  (* C_EN_DEEPSLEEP_PIN = "0" *) 
  (* C_EN_ECC_PIPE = "0" *) 
  (* C_EN_RDADDRA_CHG = "0" *) 
  (* C_EN_RDADDRB_CHG = "0" *) 
  (* C_EN_SAFETY_CKT = "0" *) 
  (* C_EN_SHUTDOWN_PIN = "0" *) 
  (* C_EN_SLEEP_PIN = "0" *) 
  (* C_EST_POWER_SUMMARY = "Estimated Power for IP     :     5.244 mW" *) 
  (* C_FAMILY = "zynq" *) 
  (* C_HAS_AXI_ID = "0" *) 
  (* C_HAS_ENA = "0" *) 
  (* C_HAS_ENB = "1" *) 
  (* C_HAS_INJECTERR = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MEM_OUTPUT_REGS_B = "1" *) 
  (* C_HAS_MUX_OUTPUT_REGS_A = "0" *) 
  (* C_HAS_MUX_OUTPUT_REGS_B = "0" *) 
  (* C_HAS_REGCEA = "0" *) 
  (* C_HAS_REGCEB = "0" *) 
  (* C_HAS_RSTA = "0" *) 
  (* C_HAS_RSTB = "0" *) 
  (* C_HAS_SOFTECC_INPUT_REGS_A = "0" *) 
  (* C_HAS_SOFTECC_OUTPUT_REGS_B = "0" *) 
  (* C_INITA_VAL = "0" *) 
  (* C_INITB_VAL = "0" *) 
  (* C_INIT_FILE = "rot_lut.mem" *) 
  (* C_INIT_FILE_NAME = "rot_lut.mif" *) 
  (* C_INTERFACE_TYPE = "0" *) 
  (* C_LOAD_INIT_FILE = "1" *) 
  (* C_MEM_TYPE = "4" *) 
  (* C_MUX_PIPELINE_STAGES = "0" *) 
  (* C_PRIM_TYPE = "1" *) 
  (* C_READ_DEPTH_A = "512" *) 
  (* C_READ_DEPTH_B = "512" *) 
  (* C_READ_LATENCY_A = "1" *) 
  (* C_READ_LATENCY_B = "1" *) 
  (* C_READ_WIDTH_A = "32" *) 
  (* C_READ_WIDTH_B = "32" *) 
  (* C_RSTRAM_A = "0" *) 
  (* C_RSTRAM_B = "0" *) 
  (* C_RST_PRIORITY_A = "CE" *) 
  (* C_RST_PRIORITY_B = "CE" *) 
  (* C_SIM_COLLISION_CHECK = "ALL" *) 
  (* C_USE_BRAM_BLOCK = "0" *) 
  (* C_USE_BYTE_WEA = "0" *) 
  (* C_USE_BYTE_WEB = "0" *) 
  (* C_USE_DEFAULT_DATA = "0" *) 
  (* C_USE_ECC = "0" *) 
  (* C_USE_SOFTECC = "0" *) 
  (* C_USE_URAM = "0" *) 
  (* C_WEA_WIDTH = "1" *) 
  (* C_WEB_WIDTH = "1" *) 
  (* C_WRITE_DEPTH_A = "512" *) 
  (* C_WRITE_DEPTH_B = "512" *) 
  (* C_WRITE_MODE_A = "WRITE_FIRST" *) 
  (* C_WRITE_MODE_B = "WRITE_FIRST" *) 
  (* C_WRITE_WIDTH_A = "32" *) 
  (* C_WRITE_WIDTH_B = "32" *) 
  (* C_XDEVICEFAMILY = "zynq" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  (* is_du_within_envelope = "true" *) 
  rot_lut_blk_mem_gen_v8_4_8 U0
       (.addra(addra),
        .addrb(addrb),
        .clka(clka),
        .clkb(1'b0),
        .dbiterr(NLW_U0_dbiterr_UNCONNECTED),
        .deepsleep(1'b0),
        .dina({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .douta(douta),
        .doutb(doutb),
        .eccpipece(1'b0),
        .ena(1'b0),
        .enb(enb),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .rdaddrecc(NLW_U0_rdaddrecc_UNCONNECTED[8:0]),
        .regcea(1'b1),
        .regceb(1'b1),
        .rsta(1'b0),
        .rsta_busy(NLW_U0_rsta_busy_UNCONNECTED),
        .rstb(1'b0),
        .rstb_busy(NLW_U0_rstb_busy_UNCONNECTED),
        .s_aclk(1'b0),
        .s_aresetn(1'b0),
        .s_axi_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arburst({1'b0,1'b0}),
        .s_axi_arid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arready(NLW_U0_s_axi_arready_UNCONNECTED),
        .s_axi_arsize({1'b0,1'b0,1'b0}),
        .s_axi_arvalid(1'b0),
        .s_axi_awaddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awburst({1'b0,1'b0}),
        .s_axi_awid({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awready(NLW_U0_s_axi_awready_UNCONNECTED),
        .s_axi_awsize({1'b0,1'b0,1'b0}),
        .s_axi_awvalid(1'b0),
        .s_axi_bid(NLW_U0_s_axi_bid_UNCONNECTED[3:0]),
        .s_axi_bready(1'b0),
        .s_axi_bresp(NLW_U0_s_axi_bresp_UNCONNECTED[1:0]),
        .s_axi_bvalid(NLW_U0_s_axi_bvalid_UNCONNECTED),
        .s_axi_dbiterr(NLW_U0_s_axi_dbiterr_UNCONNECTED),
        .s_axi_injectdbiterr(1'b0),
        .s_axi_injectsbiterr(1'b0),
        .s_axi_rdaddrecc(NLW_U0_s_axi_rdaddrecc_UNCONNECTED[8:0]),
        .s_axi_rdata(NLW_U0_s_axi_rdata_UNCONNECTED[31:0]),
        .s_axi_rid(NLW_U0_s_axi_rid_UNCONNECTED[3:0]),
        .s_axi_rlast(NLW_U0_s_axi_rlast_UNCONNECTED),
        .s_axi_rready(1'b0),
        .s_axi_rresp(NLW_U0_s_axi_rresp_UNCONNECTED[1:0]),
        .s_axi_rvalid(NLW_U0_s_axi_rvalid_UNCONNECTED),
        .s_axi_sbiterr(NLW_U0_s_axi_sbiterr_UNCONNECTED),
        .s_axi_wdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axi_wlast(1'b0),
        .s_axi_wready(NLW_U0_s_axi_wready_UNCONNECTED),
        .s_axi_wstrb(1'b0),
        .s_axi_wvalid(1'b0),
        .sbiterr(NLW_U0_sbiterr_UNCONNECTED),
        .shutdown(1'b0),
        .sleep(1'b0),
        .wea(1'b0),
        .web(1'b0));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2024.1"
`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
RSqbsRZSIb+QlYJMfFv1T7uHQ7PiCEXQkl687MHGm2LgPB15GIYcPmqKUSXgtkLsIFes91PTAyyB
9H9cyY4ZUxedcRg/9ZOB5pm3zPqAbcvGPmg1ivMhr/MlS19t5lYKM2tQo+0Yd+arJXlVZu2BMnvn
+I3G9t9tJuWUIWKjI+I=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
VRSQ05ZaB6bIhFIQ823mTvlJaG9+5iW5C3+KxGjq0sq9ziCshKOLpOGPDMmOWDqA4uBaxC5IKISr
w8+A8mqbYjXo5m1g8sGjNaETS0HKJsK+l5Y++tN4IEUs+DwxgrPR/+LWtChuOzVkfC7BG3LVUEMj
zM3GAyGcXGJ3sdBItZAfsevyiy7kr4Fw+nk2hWytGteu1NZk3VzPE7KQHLkOlHBPXf6P0j8LpKcr
2oNDgQ/WaEmg6OOvFeJuaWDaee8Sn6wKP/caMyoGdSeczsPtRrJeoSRlbNHlxhCv7zg+Cn2AgwrR
PTqGsMrkhv9U0sq+waS0CmwChsk4WB7RspGYUg==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VELOCE-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
tNziOjCznlvIl4dadmB9r23Duf+HQHWOuHmupEU3PJxrazHVtZdNKspG9sRXhF9mjbpnSiKYCdFK
Jr9W/dxUid36faFIPKQazVTuOiE0hkzVQAGpYxXjT/ITB/9EFBvgvP5L3EAhHv32x6MA1vkFSI7x
HrZ09YNFEF6T7DPTZE4=

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-2", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
QCYfxgkUHlX1cre1q9aS3sVDIOX36YBK4ZwJXAVUwA6f1OQ77XibjpWJHt5FK9F0PcYp/j21pqzO
BRdkDcFLVAjxER4J5t5iMVhoeMk+3fpiKfYrm4WFl1ygsJsfFJP0jqO1OkjC8iFBtm3n6b7CTl1o
cjBbcBp8UgW6E8rf5inXA0dRqybnyxKJSnMFYLinvpVU6QEc4OKO7mi/i/s9p/efiP+CdQf0yDRU
Fw7o7x0D7tjBv943g5L+4wGZ2JYU+ISqn4Ajxy/bWTTJDe6T/15evhngS61MC8Xjamzc4YLZBP8o
ShfSLoeZeO+Hk5n3xzJRghM0DQ6Sj7NqXFY68w==

`pragma protect key_keyowner="Real Intent", key_keyname="RI-RSA-KEY-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Uy8FDDy3dZQGAnMQV0HBesEs+/oZdaq35Kj1PGhy9J/+EBZm0nhhQgYtku8tWABW2jKAC1GtNTvo
uReQyr1hteMxTbD5OIuqv86eb1hXZVENlZ7ichG8auUjkeHAkaSYNbHOuDLIhSqHEL67XbcZ9zPG
1JOY3+VONSww0KYPcQbGSo/2DaC5C0Y+mZODRfJ4+b0WXjce6UaJetilBc3VtqqmodIM2d3HDawF
R0xVJfHj86rXmUkY+SNUw60zsV6raCY6G3k/rXpei1d6zn8tCThkKG5fwiWY8zA7kRdTFIlVKP9h
fb6kfzRBRT/BgVQ8d4RgEcEVV8m3u/Mf4KIlTw==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinxt_2023_11", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
Pk1GeRlkUK9lt6DVXYVdtOABlzDEWQDcBsP/p+Wo5HaglDLG5b8gk08xTP3IcJ1RKcfuARPMGO2s
/VqFbnVADV90T1rhjIuWMcBnzYQK/ALUvwv11Uju9Gn0fvPIz52l3QBnpjHI1nlsFB7WeqkzVfHZ
tg9gO9bPHjHLjVd9BzH6McrEWY5RkZ0UBy0Fmh/SownJX1b0YGE7LdwKydEMEpyvb28bwTOwfEv/
4RtsfYtEvTjo6e1ZBm66D9IQmKUu32wzTfn5bFZHdyjZg6+HcTzvHMtQX2+AggXfP6FsO2/83qkb
0bfj226fnLhr32dJxtsaJS5OR63GYtzDJ05ITA==

`pragma protect key_keyowner="Metrics Technologies Inc.", key_keyname="DSim", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
LCfWqKmUoUSVOTKNAl5p8n1hfz7SMU2kDOUMBjsDncgSFqiu2zUy1I6GSDrVnF/2umJG5/mWcpvi
rQaFJOlrJ8DNctSuavdlopRAwTMsVi6dAlNGrAawSiDIxtI3tN3MDVdMiH5H+pJMqMt59yXneyCf
2RRSRz2sUQK/aj0lXlqKjVJzVbk8HaBQ8akBJF4iWSMK4foIzJ6iO1EupYovuW6uEiO7jQRWezlW
pbbDenOHHWbfinuX5cbkjpTKHGsEKct65q+ZXJp60m3sconSK3Y2eLQxusuJ1FHDJ4GGKO8mEzCv
3cfGdXX3pVL81OfGO/JD1aMs9H98CO5ssbHqlw==

`pragma protect key_keyowner="Atrenta", key_keyname="ATR-SG-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=384)
`pragma protect key_block
A4S1e3DHcTeWzaDVuWDRb3Yf1BjiEsR1RtAeL0BJ7J/oPWMNj96MeGsUiHtZoiYqteTZxqax2cyZ
PV0cMLoBK4Ya8CyM+BTnkFA2ablsGt5Es4TgG/nFS9VEhmeKxu8boAsqW5697aiqOATJf/LucQh5
GOnPXHAuPrDj0A/fu8N2QduqGyysWUSc1KsoJ0/0noJYvLJ2yOhFi4uIUYQfG5LOuOrca5P43pqA
iwUKW/RrFXal2acJdFeXIKffZpKanSV97urdzKyBvf9EPV/M8g9uPFJJ1z6aS+FbknhVPs0pt6eD
+J/qib4gVp/HGnRo4YlxauUMv6Yv9wxiaObY6ttDfYf5p3uzWZMlf3i7YOzZwcd4aS/6+vkD28LG
L9piBIpLx2dvQy74RdvCVdvaP1LC6RMju9RfuXJhuX4ZAmDxRi0zQyRda838ikzwYeOCSKLIvRPb
nuJ8Zx2ot8EFqSeGaaRFaEMU6Zf5SptCUuVMHvSkinBewcwrLB5uiJTJ

`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="CDS_RSA_KEY_VER_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
gj+uMxV+tK4Di7pgSOE82FOBeWmUB1A7OKFOSMUW3qrmQ4/YhryfHMlWPxfAq8avQL7tnBTnRFEg
czbErdIcNzYjrM7Qq00QC/mTqmeQX4/apbqGvN+rwK4RR5oj22wfTib/UQNEQX6fbpi6PtmAeUR9
eShsfq+YWcf7z2Zw4Q+o4+E6m4/3CzU68vglNpzNsJ8S9/8XpdIrvAA/WRAX6OEOC4wlNIKDZsq/
+zMbFgSzN1rP844I/CDmxYM0NIzBWWhYBkPfJyQyigmUoXb84lDip0/Dmnq4EHvu7D/tZNnDl5st
JpftRfEpT6S8e/5MBeKUuhbfg6etHo/oFZvPKQ==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
aWTy3xv6SqKsldtLS2gY4KrTS8U+KtFNRHS314f6EYZy1MHE9t7oICJ8eNB8up8A+odoE23N3fJb
1alhaadeRWU2GjlIiK1LjZ5PQw+jb1u1GWtRiY+TcTlD75XUlqwykVBrCDfm565DmgZjZle9T3/t
WEfLo+m/8GfBe8trVnoftsk/XI00BMFXRzw8doPGDhNECS1NUrLebryb9iO5Hf4A/40dtslTARsR
nicN0KoIIyiQ+QzliqyXU/8VjS45inON8R0Kv9Qx46EXUp7bds5uQ7QycRhpLG0IPnMIweudU67w
eQmpHJzvZKBCZks/R0OafZx44H6Jib2+QazBCw==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
UGdPiChIPj1lSozqzCQx17Bi+8FWSuMUMzXUkDLH5zcP1t8tZLzh4CU4WAR8lmJxn8gH763fLp5c
RYU6zA0yxHzl2ksc5YRU1XEfQQT9ha8fQnz+18wVKcsa5UIOfMbGDwnS9yfX59ntG8CB0uF8bJKE
y1CS6U/1Stfs1w2mF94iDxI2n2GJlb1UPtWpmxMBI88hY0GktTPXP2Y7JKl8zRl/Lq0wIF8pHwXk
B4nOgKm6hfzPj0xZ6E/TuER/JE3fy8RSm24IlL/CUgpReEslEOYjQ4EKKZRG9/fxg26utQWW9p+G
fWVU53qrFGzBhKQ96Paj1ROkv6hDHyUb6n7uSw==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 27248)
`pragma protect data_block
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
Bq4=
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
