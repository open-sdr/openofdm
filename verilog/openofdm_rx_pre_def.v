`define CLK_SPEED_120M
//`define CLK_SPEED_100M
`define BETTER_SENSITIVITY
`ifdef SIMULATION
//`define USE_PARALLEL_SAMPLES // simulate with parallel IQ data, do nto go through the  the LVDS block with serial data
`endif // SIMULATION
`define SAMPLE_FILE "D:/Data/RASentinel/owifi/owifi.srcs/sources_1/openwifi/testing_inputs/conducted/pluto_12Bit.txt"
//`define SAMPLE_FILE "D:/Data/RASentinel/owifi/owifi.srcs/sources_1/openwifi/testing_inputs/simulated/ag_6M_len14_pre100_post200_openwifi.txt"
`define DEBUG_PRINT
