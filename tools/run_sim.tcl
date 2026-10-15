# ---------------------------------------------------------------------------
# run_sim.tcl - simulate the openofdm dot11 receiver against a reference
# vector, standalone (no downstream board project needed).
#
#   vivado -mode batch -source tools/run_sim.tcl
#   vivado -mode batch -source tools/run_sim.tcl -tclargs <vector.txt>
#
# <vector.txt> is either an absolute path or a name relative to
# verilog/testing_inputs, e.g.
#
#   vivado -mode batch -source tools/run_sim.tcl \
#          -tclargs simulated/ag_6M_len14_pre100_post200_openwifi.txt
#
# With no argument the vector selected by verilog/openofdm_rx_pre_def.v is used.
#
# This runs through a throwaway Vivado project rather than bare xvlog/xelab:
# it was needed while the Xilinx FFT IP (a VHDL wrapper over Xilinx
# libraries) was part of the receiver, and it still keeps the ROM/vector
# defines and the include path in one place now that everything is RTL.
#
# Output lands in <build>/sim/openofdm_sim.sim/sim_1/behav/xsim/ as ~50 .txt
# dumps plus the console trace (state transitions, receiver_rst, FCS verdict).
# ---------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
source $root/tools/openofdm_sources.tcl

set out $root/build/sim
file mkdir $out

# --- pick the vector -------------------------------------------------------
set vector ""
if {$argc > 0} {
    set vector [lindex $argv 0]
    if {[file pathtype $vector] ne "absolute"} {
        set vector [file join [openofdm::vectors] $vector]
    }
    if {![file exists $vector]} { error "vector does not exist: $vector" }
}

puts "### [openofdm::banner]"

# A fresh project every time. The bench `include-s openofdm_rx_pre_def.v, which
# is a member of no fileset, so Vivado tracks no dependency on it: reusing a
# project after editing that file silently re-runs the PREVIOUS configuration
# and the result looks entirely plausible.
if {[file exists $out/openofdm_sim.xpr]} { file delete -force $out/openofdm_sim }
create_project -force openofdm_sim $out/openofdm_sim -part xc7a100tcsg324-2

add_files -norecurse -fileset sources_1 [openofdm::rtl]
add_files -norecurse -fileset sources_1 [openofdm::viterbi]
if {[llength [openofdm::ip]]} { add_files -norecurse -fileset sources_1 [openofdm::ip] }
add_files -norecurse -fileset sim_1     [openofdm::testbench]

# Retarget and rebuild an IP for this part (none since openFFT). Without
# -quiet: a silent failure leaves the IP locked and elaboration dies on a
# missing module.
if {[llength [get_ips]]} {
    upgrade_ip [get_ips]
    foreach ip [get_ips] {
        reset_target all $ip
        generate_target simulation $ip
    }
}

set_property top dot11_tb [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property include_dirs [openofdm::includes] [get_filesets sim_1]

# LUT_DIR + VECTOR_DIR, plus VITERBI_TRACE so ofdm_decoder.v dumps the soft
# symbols into and the bits out of the decoder.
#
# PRECEDENCE, MEASURED: a command-line -d BEATS a `define in an `include-d
# file. So SAMPLE_FILE is only forced here when a vector was named on the
# command line - otherwise it is left unset and openofdm_rx_pre_def.v decides.
set defs [concat [openofdm::sim_defines] VITERBI_TRACE]
if {$vector ne ""} { lappend defs SAMPLE_FILE=\"$vector\" }
set_property verilog_define $defs [get_filesets sim_1]
puts "### DEFINES $defs"

set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]

# the bench ends itself with $finish when the vector runs out
launch_simulation

set xsimdir $out/openofdm_sim/openofdm_sim.sim/sim_1/behav/xsim
puts "### SIM_DONE  results in $xsimdir"

# The bench writes the macro it actually compiled with to sample_file_name.txt.
# Check that, not the intent above - it is the only proof of which capture ran.
if {[file exists $xsimdir/sample_file_name.txt]} {
    set fh [open $xsimdir/sample_file_name.txt r]
    puts "### VECTOR_USED [string trim [read $fh]]"
    close $fh
}
if {[file exists $xsimdir/fcs_out.txt]} {
    set fh [open $xsimdir/fcs_out.txt r]
    set fcs [string trim [read $fh]]
    close $fh
    puts "### FCS $fcs"
} else {
    puts "### FCS (no fcs_out.txt - nothing decoded)"
}
