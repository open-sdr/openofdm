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

-- IP VLNV: xilinx.com:ip:cmpy:6.0
-- IP Revision: 24

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY cmpy_v6_0_24;
USE cmpy_v6_0_24.cmpy_v6_0_24;

ENTITY complex_multiplier IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END complex_multiplier;

ARCHITECTURE complex_multiplier_arch OF complex_multiplier IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF complex_multiplier_arch: ARCHITECTURE IS "yes";
  COMPONENT cmpy_v6_0_24 IS
    GENERIC (
      C_VERBOSITY : INTEGER;
      C_XDEVICEFAMILY : STRING;
      C_XDEVICE : STRING;
      C_A_WIDTH : INTEGER;
      C_B_WIDTH : INTEGER;
      C_OUT_WIDTH : INTEGER;
      C_LATENCY : INTEGER;
      C_MULT_TYPE : INTEGER;
      C_OPTIMIZE_GOAL : INTEGER;
      HAS_NEGATE : INTEGER;
      SINGLE_OUTPUT : INTEGER;
      ROUND : INTEGER;
      USE_DSP_CASCADES : INTEGER;
      C_THROTTLE_SCHEME : INTEGER;
      C_HAS_ACLKEN : INTEGER;
      C_HAS_ARESETN : INTEGER;
      C_HAS_S_AXIS_A_TUSER : INTEGER;
      C_HAS_S_AXIS_A_TLAST : INTEGER;
      C_HAS_S_AXIS_B_TUSER : INTEGER;
      C_HAS_S_AXIS_B_TLAST : INTEGER;
      C_HAS_S_AXIS_CTRL_TUSER : INTEGER;
      C_HAS_S_AXIS_CTRL_TLAST : INTEGER;
      C_TLAST_RESOLUTION : INTEGER;
      C_S_AXIS_A_TDATA_WIDTH : INTEGER;
      C_S_AXIS_A_TUSER_WIDTH : INTEGER;
      C_S_AXIS_B_TDATA_WIDTH : INTEGER;
      C_S_AXIS_B_TUSER_WIDTH : INTEGER;
      C_S_AXIS_CTRL_TDATA_WIDTH : INTEGER;
      C_S_AXIS_CTRL_TUSER_WIDTH : INTEGER;
      C_M_AXIS_DOUT_TDATA_WIDTH : INTEGER;
      C_M_AXIS_DOUT_TUSER_WIDTH : INTEGER
    );
    PORT (
      aclk : IN STD_LOGIC;
      aclken : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tready : OUT STD_LOGIC;
      s_axis_a_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_a_tlast : IN STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tready : OUT STD_LOGIC;
      s_axis_b_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_b_tlast : IN STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_ctrl_tvalid : IN STD_LOGIC;
      s_axis_ctrl_tready : OUT STD_LOGIC;
      s_axis_ctrl_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      s_axis_ctrl_tlast : IN STD_LOGIC;
      s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      m_axis_dout_tvalid : OUT STD_LOGIC;
      m_axis_dout_tready : IN STD_LOGIC;
      m_axis_dout_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
      m_axis_dout_tlast : OUT STD_LOGIC;
      m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
  END COMPONENT cmpy_v6_0_24;
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
  ATTRIBUTE X_INTERFACE_PARAMETER OF aclk: SIGNAL IS "XIL_INTERFACENAME aclk_intf, ASSOCIATED_BUSIF S_AXIS_CTRL:S_AXIS_B:S_AXIS_A:M_AXIS_DOUT, ASSOCIATED_RESET aresetn, ASSOCIATED_CLKEN aclken, FREQ_HZ 10000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF aclk: SIGNAL IS "xilinx.com:signal:clock:1.0 aclk_intf CLK";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TDATA";
  ATTRIBUTE X_INTERFACE_PARAMETER OF m_axis_dout_tvalid: SIGNAL IS "XIL_INTERFACENAME M_AXIS_DOUT, TDATA_NUM_BYTES 8, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF m_axis_dout_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 M_AXIS_DOUT TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_a_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_A TDATA";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_a_tvalid: SIGNAL IS "XIL_INTERFACENAME S_AXIS_A, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_a_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_A TVALID";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_b_tdata: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_B TDATA";
  ATTRIBUTE X_INTERFACE_PARAMETER OF s_axis_b_tvalid: SIGNAL IS "XIL_INTERFACENAME S_AXIS_B, TDATA_NUM_BYTES 4, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0, HAS_TREADY 0, HAS_TSTRB 0, HAS_TKEEP 0, HAS_TLAST 0, FREQ_HZ 100000000, PHASE 0.0, LAYERED_METADATA undef, INSERT_VIP 0";
  ATTRIBUTE X_INTERFACE_INFO OF s_axis_b_tvalid: SIGNAL IS "xilinx.com:interface:axis:1.0 S_AXIS_B TVALID";
BEGIN
  U0 : cmpy_v6_0_24
    GENERIC MAP (
      C_VERBOSITY => 0,
      C_XDEVICEFAMILY => "artix7",
      C_XDEVICE => "xc7a100t",
      C_A_WIDTH => 16,
      C_B_WIDTH => 16,
      C_OUT_WIDTH => 32,
      C_LATENCY => 3,
      C_MULT_TYPE => 1,
      C_OPTIMIZE_GOAL => 1,
      HAS_NEGATE => 0,
      SINGLE_OUTPUT => 0,
      ROUND => 0,
      USE_DSP_CASCADES => 1,
      C_THROTTLE_SCHEME => 3,
      C_HAS_ACLKEN => 0,
      C_HAS_ARESETN => 0,
      C_HAS_S_AXIS_A_TUSER => 0,
      C_HAS_S_AXIS_A_TLAST => 0,
      C_HAS_S_AXIS_B_TUSER => 0,
      C_HAS_S_AXIS_B_TLAST => 0,
      C_HAS_S_AXIS_CTRL_TUSER => 0,
      C_HAS_S_AXIS_CTRL_TLAST => 0,
      C_TLAST_RESOLUTION => 0,
      C_S_AXIS_A_TDATA_WIDTH => 32,
      C_S_AXIS_A_TUSER_WIDTH => 1,
      C_S_AXIS_B_TDATA_WIDTH => 32,
      C_S_AXIS_B_TUSER_WIDTH => 1,
      C_S_AXIS_CTRL_TDATA_WIDTH => 8,
      C_S_AXIS_CTRL_TUSER_WIDTH => 1,
      C_M_AXIS_DOUT_TDATA_WIDTH => 64,
      C_M_AXIS_DOUT_TUSER_WIDTH => 1
    )
    PORT MAP (
      aclk => aclk,
      aclken => '1',
      aresetn => '1',
      s_axis_a_tvalid => s_axis_a_tvalid,
      s_axis_a_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_a_tlast => '0',
      s_axis_a_tdata => s_axis_a_tdata,
      s_axis_b_tvalid => s_axis_b_tvalid,
      s_axis_b_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_b_tlast => '0',
      s_axis_b_tdata => s_axis_b_tdata,
      s_axis_ctrl_tvalid => '0',
      s_axis_ctrl_tuser => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
      s_axis_ctrl_tlast => '0',
      s_axis_ctrl_tdata => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8)),
      m_axis_dout_tvalid => m_axis_dout_tvalid,
      m_axis_dout_tready => '0',
      m_axis_dout_tdata => m_axis_dout_tdata
    );
END complex_multiplier_arch;
