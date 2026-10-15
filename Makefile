# ---------------------------------------------------------------------------
# openofdm - convenience wrappers around the tcl scripts in tools/.
#
#   make check     out-of-context synthesis of dot11 (fast setup smoke test)
#   make sim       simulate dot11_tb against the default reference vector
#   make sim VECTOR=simulated/ag_6M_len14_pre100_post200_openwifi.txt
#   make project   generate a Vivado GUI project under build/
#   make tb        openCMUL's, openCDIV's and openFFT's benches against the
#                  netlists of the Xilinx cores they replace (cmpy 6.0,
#                  div_gen 5.1, xfft 9.1)
#   make refnetlists  write those netlists (tools/ref_netlists.tcl); make tb
#                  does it first when they are missing
#   make regression            dot11 against every reference vector (11a+11n+sim)
#   make regression GROUP=11a  one group (11a | 11n | sim | all) or a vector path
#   make clean     remove build/
#
# Requires Vivado on $PATH (source <install>/settings64.sh) and a checkout of
# openViterbi, openCMUL, openCDIV and openFFT next to this repository, or
# $OPENVITERBI / $OPENCMUL / $OPENCDIV / $OPENFFT pointing at them.
# ---------------------------------------------------------------------------
VIVADO ?= vivado
VFLAGS  = -mode batch -nojournal -nolog
VECTOR ?=

.PHONY: all check sim project clean

all: check

check:
	$(VIVADO) $(VFLAGS) -source tools/synth_check.tcl

sim:
	$(VIVADO) $(VFLAGS) -source tools/run_sim.tcl $(if $(VECTOR),-tclargs $(VECTOR),)

project:
	$(VIVADO) $(VFLAGS) -source tools/create_project.tcl

# --- unit testbenches of the multiplier, dividers and FFT (openCMUL, openCDIV, openFFT)
OPENCMUL ?= $(abspath ../openCMUL)
OPENCDIV ?= $(abspath ../openCDIV)
OPENFFT  ?= $(abspath ../openFFT)
CMPY_NETLIST   = $(abspath ip_repo/complex_multiplier/complex_multiplier_sim_netlist.v)
DIVGEN_NETLIST = $(abspath ip_repo/div_gen/div_gen_div_gen_0_0_sim_netlist.v)
XFFT_NETLIST   = $(abspath ip_repo/xfft_v9/xfft_v9_sim_netlist.v)

.PHONY: tb refnetlists
refnetlists:
	$(VIVADO) $(VFLAGS) -source tools/ref_netlists.tcl

tb: refnetlists
	$(MAKE) -C $(OPENCMUL) tb CMPY_NETLIST=$(CMPY_NETLIST)
	$(MAKE) -C $(OPENCDIV) tb CMPY_NETLIST=$(CMPY_NETLIST) DIVGEN_NETLIST=$(DIVGEN_NETLIST) OPENCMUL=$(OPENCMUL)
	$(MAKE) -C $(OPENFFT) tb XFFT_NETLIST=$(XFFT_NETLIST) OPENCMUL=$(OPENCMUL)

# --- receiver regression (tools/run_regression.tcl) -------------------------
# One Vivado session, one launch_simulation per vector; verdict per vector in
# build/regression/results.txt, per-vector dumps under build/regression/dumps/.
GROUP ?= all

.PHONY: regression
regression:
	$(VIVADO) $(VFLAGS) -source tools/run_regression.tcl -tclargs $(GROUP)

clean:
	rm -rf build .Xil
