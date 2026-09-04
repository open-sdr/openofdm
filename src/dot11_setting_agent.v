// Xianjun jiao. putaoshu@msn.com; xianjun.jiao@imec.be;
`include "openofdm_rx_pre_def.v"

`ifdef OPENOFDM_RX_ENABLE_DBG
`define DEBUG_PREFIX (*mark_debug="true",DONT_TOUCH="TRUE"*)
`else
`define DEBUG_PREFIX
`endif

module dot11_setting_agent
#(
  parameter integer RSSI_HALF_DB_WIDTH_UNSIGNED = 10
)
(
  input wire clk,
  input wire rstn,

  input wire para_valid,
  input wire [RSSI_HALF_DB_WIDTH_UNSIGNED-1:0] para_rx_sensitivity_th,

  `DEBUG_PREFIX output reg [RSSI_HALF_DB_WIDTH_UNSIGNED-1:0] rx_sensitivity_th_lock
);

always @(posedge clk) begin
  if (~rstn) begin
    rx_sensitivity_th_lock <= 0;
  end else begin
    rx_sensitivity_th_lock <= (para_valid?para_rx_sensitivity_th:rx_sensitivity_th_lock);
  end
end

endmodule
