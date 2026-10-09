// ---------------------------------------------------------------------------
// Compile-time configuration for the openofdm receiver and its testbench.
// `include-d by dot11_tb.v (and by anything else that needs CLK_SPEED_*).
//
// NOTE ON PRECEDENCE: a command-line -d BEATS the `define in this file, the
// opposite of what one might assume. So a stale verilog_define stored in a
// .xpr silently overrides everything below - the sim scripts clear it first.
// ---------------------------------------------------------------------------
`define CLK_SPEED_120M
//`define CLK_SPEED_100M
`define BETTER_SENSITIVITY
`ifdef SIMULATION
//`define USE_PARALLEL_SAMPLES // simulate with parallel IQ data, do not go through the LVDS block with serial data
`endif // SIMULATION

// --- test vector -----------------------------------------------------------
// VECTOR_DIR is supplied by the build/sim scripts (-d VECTOR_DIR="<abs path>")
// so this file holds no machine-specific paths. The default only resolves when
// the tool is launched from verilog/.
`ifndef VECTOR_DIR
`define VECTOR_DIR "testing_inputs"
`endif

// Real conducted capture, 12Mbps QoS data. Converted from the packed-hex
// format with scripts/conv_iq_hex.py - most of conducted/ is NOT in the two
// decimal column format the bench reads, and feeding it raw fails silently.
`ifndef SAMPLE_FILE
`define SAMPLE_FILE {`VECTOR_DIR, "/conducted/dot11a_12mbps_qos_data_e4_90_7e_15_2a_16_e8_de_27_90_6e_42_openwifi.txt"}
//`define SAMPLE_FILE {`VECTOR_DIR, "/simulated/ag_6M_len14_pre100_post200_openwifi.txt"}
`endif

`define DEBUG_PRINT
