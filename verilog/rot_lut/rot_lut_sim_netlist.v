// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
// Date        : Mon Aug  5 03:54:01 2024
// Host        : PC1008 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim -rename_top rot_lut -prefix
//               rot_lut_ rot_lut_sim_netlist.v
// Design      : rot_lut
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a100tfgg676-1
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
  (* C_FAMILY = "artix7" *) 
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
  (* C_XDEVICEFAMILY = "artix7" *) 
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
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 26960)
`pragma protect data_block
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
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
