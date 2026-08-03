-- (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- (c) Copyright 2022-2024 Advanced Micro Devices, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of AMD and is protected under U.S. and international copyright
-- and other intellectual property laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- AMD, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) AMD shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or AMD had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- AMD products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of AMD products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:viterbi:9.1
-- IP Revision: 17

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY viterbi_v9_1_17;
USE viterbi_v9_1_17.viterbi_v9_1_17;

ENTITY viterbi_v7_0 IS
  PORT (
    aclk : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    aclken : IN STD_LOGIC;
    s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    s_axis_data_tuser : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axis_data_tvalid : IN STD_LOGIC;
    s_axis_data_tready : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC
  );
END viterbi_v7_0;

ARCHITECTURE viterbi_v7_0_arch OF viterbi_v7_0 IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF viterbi_v7_0_arch: ARCHITECTURE IS "yes";
  COMPONENT viterbi_v9_1_17 IS
    GENERIC (
      C_HAS_S_AXIS_DATA_TUSER : INTEGER;
      C_HAS_M_AXIS_DATA_TUSER : INTEGER;
      C_HAS_M_AXIS_DATA_TREADY : INTEGER;
      C_HAS_M_AXIS_DSTAT_TREADY : INTEGER;
      C_HAS_DSTAT : INTEGER;
      C_S_AXIS_DATA_TDATA_WIDTH : INTEGER;
      C_S_AXIS_DATA_TUSER_WIDTH : INTEGER;
      C_M_AXIS_DATA_TDATA_WIDTH : INTEGER;
      C_M_AXIS_DATA_TUSER_WIDTH : INTEGER;
      C_S_AXIS_DSTAT_TDATA_WIDTH : INTEGER;
      C_M_AXIS_DSTAT_TDATA_WIDTH : INTEGER;
      C_HAS_ACLKEN : INTEGER;
      C_SERIAL : INTEGER;
      C_CHANNEL_COUNT : INTEGER;
      C_DUAL_DECODER : INTEGER;
      C_TRELLIS_MODE : INTEGER;
      C_CONSTRAINT_LENGTH : INTEGER;
      C_TRACEBACK_LENGTH : INTEGER;
      C_RED_LATENCY : INTEGER;
      C_HAS_BEST_STATE : INTEGER;
      C_BEST_STATE_WIDTH : INTEGER;
      C_OUTPUT_RATE0 : INTEGER;
      C_CONVOLUTION0_CODE0 : INTEGER;
      C_CONVOLUTION0_CODE1 : INTEGER;
      C_CONVOLUTION0_CODE2 : INTEGER;
      C_CONVOLUTION0_CODE3 : INTEGER;
      C_CONVOLUTION0_CODE4 : INTEGER;
      C_CONVOLUTION0_CODE5 : INTEGER;
      C_CONVOLUTION0_CODE6 : INTEGER;
      C_OUTPUT_RATE1 : INTEGER;
      C_CONVOLUTION1_CODE0 : INTEGER;
      C_CONVOLUTION1_CODE1 : INTEGER;
      C_CONVOLUTION1_CODE2 : INTEGER;
      C_CONVOLUTION1_CODE3 : INTEGER;
      C_CONVOLUTION1_CODE4 : INTEGER;
      C_CONVOLUTION1_CODE5 : INTEGER;
      C_CONVOLUTION1_CODE6 : INTEGER;
      C_SOFT_CODING : INTEGER;
      C_SOFT_CODE : INTEGER;
      C_SOFT_WIDTH : INTEGER;
      C_HAS_ERASED : INTEGER;
      C_HAS_BLOCK_VALID : INTEGER;
      C_HAS_BER : INTEGER;
      C_HAS_NORM : INTEGER;
      C_COMPONENT_NAME : STRING;
      C_XDEVICEFAMILY : STRING;
      C_ELABORATION_DIR : STRING
    );
    PORT (
      aclk : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      aclken : IN STD_LOGIC;
      s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      s_axis_data_tuser : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      s_axis_data_tvalid : IN STD_LOGIC;
      s_axis_data_tready : OUT STD_LOGIC;
      m_axis_data_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axis_data_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axis_data_tvalid : OUT STD_LOGIC;
      m_axis_data_tready : IN STD_LOGIC;
      s_axis_dstat_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      s_axis_dstat_tvalid : IN STD_LOGIC;
      s_axis_dstat_tready : OUT STD_LOGIC;
      m_axis_dstat_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      m_axis_dstat_tvalid : OUT STD_LOGIC;
      m_axis_dstat_tready : IN STD_LOGIC
    );
  END COMPONENT viterbi_v9_1_17;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF viterbi_v7_0_arch: ARCHITECTURE IS "viterbi_v9_1_17,Vivado 2024.1";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF viterbi_v7_0_arch : ARCHITECTURE IS "viterbi_v7_0,viterbi_v9_1_17,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF viterbi_v7_0_arch: ARCHITECTURE IS "viterbi_v7_0,viterbi_v9_1_17,{x_ipProduct=Vivado 2024.1,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=viterbi,x_ipVersion=9.1,x_ipCoreRevision=17,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_HAS_S_AXIS_DATA_TUSER=1,C_HAS_M_AXIS_DATA_TUSER=0,C_HAS_M_AXIS_DATA_TREADY=0,C_HAS_M_AXIS_DSTAT_TREADY=0,C_HAS_DSTAT=0,C_S_AXIS_DATA_TDATA_WIDTH=16,C_S_AXIS_DATA_TUSER_WIDTH=8,C_M_AXIS_DATA_TDATA_WIDTH=8,C_M_AXIS_DATA_TUSER_WIDTH=1,C_S_AXIS_DSTAT_TDATA_WIDTH=16,C_M_AXIS_DSTAT_TDATA_WIDTH=16,C_HAS_ACLKEN=1,C_" & 
"SERIAL=0,C_CHANNEL_COUNT=1,C_DUAL_DECODER=0,C_TRELLIS_MODE=0,C_CONSTRAINT_LENGTH=7,C_TRACEBACK_LENGTH=84,C_RED_LATENCY=1,C_HAS_BEST_STATE=1,C_BEST_STATE_WIDTH=3,C_OUTPUT_RATE0=2,C_CONVOLUTION0_CODE0=91,C_CONVOLUTION0_CODE1=121,C_CONVOLUTION0_CODE2=0,C_CONVOLUTION0_CODE3=0,C_CONVOLUTION0_CODE4=0,C_CONVOLUTION0_CODE5=0,C_CONVOLUTION0_CODE6=0,C_OUTPUT_RATE1=2,C_CONVOLUTION1_CODE0=121,C_CONVOLUTION1_CODE1=91,C_CONVOLUTION1_CODE2=0,C_CONVOLUTION1_CODE3=0,C_CONVOLUTION1_CODE4=0,C_CONVOLUTION1_CODE5=0," & 
"C_CONVOLUTION1_CODE6=0,C_SOFT_CODING=1,C_SOFT_CODE=0,C_SOFT_WIDTH=3,C_HAS_ERASED=1,C_HAS_BLOCK_VALID=0,C_HAS_BER=0,C_HAS_NORM=0,C_COMPONENT_NAME=viterbi_v7_0,C_XDEVICEFAMILY=zynq,C_ELABORATION_DIR=./,x_ipLicense=viterbi@2014.10(hardware_evaluation)}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER OF aclk: SIGNAL IS "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF M_AXIS_DSTAT:S_AXIS_DSTAT:M_AXIS_DATA:S_AXIS_DATA, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 aclk_intf CLK";
  ATTRIBUTE X_INTERFACE_PARAMETER OF aclken: SIGNAL IS "XIL_INTERFACENAME aclken_intf, POLARITY ACTIVE_HIGH";
  ATTRIBUTE X_INTERFACE_INFO OF aclken: SIGNAL IS "xilinx.com:signal:clockenable:1.0 aclken_intf CE";
  ATTRIBUTE X_INTERFACE_PARAMETER OF aresetn: SIGNAL IS "XIL_INTERFACENAME aresetn_intf, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF aresetn: SIGNAL IS "xilinx.com:signal:reset:1.0 aresetn_intf RST";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_data_tdata: SIGNAL IS "XIL_INTERFACENAME M_AXIS_DATA, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_data_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DATA TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_data_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DATA TVALID";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_data_tdata: SIGNAL IS "XIL_INTERFACENAME S_AXIS_DATA, TDATA_NUM_BYTES 2, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 8, HAS_TREADY 1, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TDATA";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tready: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TREADY";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tuser: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TUSER";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_data_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_DATA TVALID";
BEGIN
  U0 : viterbi_v9_1_17
    GENERIC MAP (
      C_HAS_S_AXIS_DATA_TUSER => 1,
      C_HAS_M_AXIS_DATA_TUSER => 0,
      C_HAS_M_AXIS_DATA_TREADY => 0,
      C_HAS_M_AXIS_DSTAT_TREADY => 0,
      C_HAS_DSTAT => 0,
      C_S_AXIS_DATA_TDATA_WIDTH => 16,
      C_S_AXIS_DATA_TUSER_WIDTH => 8,
      C_M_AXIS_DATA_TDATA_WIDTH => 8,
      C_M_AXIS_DATA_TUSER_WIDTH => 1,
      C_S_AXIS_DSTAT_TDATA_WIDTH => 16,
      C_M_AXIS_DSTAT_TDATA_WIDTH => 16,
      C_HAS_ACLKEN => 1,
      C_SERIAL => 0,
      C_CHANNEL_COUNT => 1,
      C_DUAL_DECODER => 0,
      C_TRELLIS_MODE => 0,
      C_CONSTRAINT_LENGTH => 7,
      C_TRACEBACK_LENGTH => 84,
      C_RED_LATENCY => 1,
      C_HAS_BEST_STATE => 1,
      C_BEST_STATE_WIDTH => 3,
      C_OUTPUT_RATE0 => 2,
      C_CONVOLUTION0_CODE0 => 91,
      C_CONVOLUTION0_CODE1 => 121,
      C_CONVOLUTION0_CODE2 => 0,
      C_CONVOLUTION0_CODE3 => 0,
      C_CONVOLUTION0_CODE4 => 0,
      C_CONVOLUTION0_CODE5 => 0,
      C_CONVOLUTION0_CODE6 => 0,
      C_OUTPUT_RATE1 => 2,
      C_CONVOLUTION1_CODE0 => 121,
      C_CONVOLUTION1_CODE1 => 91,
      C_CONVOLUTION1_CODE2 => 0,
      C_CONVOLUTION1_CODE3 => 0,
      C_CONVOLUTION1_CODE4 => 0,
      C_CONVOLUTION1_CODE5 => 0,
      C_CONVOLUTION1_CODE6 => 0,
      C_SOFT_CODING => 1,
      C_SOFT_CODE => 0,
      C_SOFT_WIDTH => 3,
      C_HAS_ERASED => 1,
      C_HAS_BLOCK_VALID => 0,
      C_HAS_BER => 0,
      C_HAS_NORM => 0,
      C_COMPONENT_NAME => "viterbi_v7_0",
      C_XDEVICEFAMILY => "zynq",
      C_ELABORATION_DIR => "./"
    )
    PORT MAP (
      aclk => aclk,
      aresetn => aresetn,
      aclken => aclken,
      s_axis_data_tdata => s_axis_data_tdata,
      s_axis_data_tuser => s_axis_data_tuser,
      s_axis_data_tvalid => s_axis_data_tvalid,
      s_axis_data_tready => s_axis_data_tready,
      m_axis_data_tdata => m_axis_data_tdata,
      m_axis_data_tvalid => m_axis_data_tvalid,
      m_axis_data_tready => '1',
      s_axis_dstat_tdata => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 16)),
      s_axis_dstat_tvalid => '0',
      m_axis_dstat_tready => '1'
    );
END viterbi_v7_0_arch;
