# ---------------------------------------------------------------------------
# synth_check.tcl - out-of-context synthesis of the dot11 receiver.
#
#   vivado -mode batch -source tools/synth_check.tcl
#
# This is the fast "is my checkout complete and does the toolchain work" test:
# it proves every module resolves (Viterbi_decoder from openViterbi,
# complex_multiplier from openCMUL, the dividers from openCDIV, fft_axis from
# openFFT) and the three ROM .mif files are found. There is no Xilinx IP in
# the receiver any more; the IP block below stays for a downstream project
# that adds one to [openofdm::ip]. It does NOT place, route or produce a bitstream - dot11 has no pins,
# so there is nothing board-specific to constrain here. A board integration
# (see RA-Sentinel's OWIFI_RX) is what turns this into hardware.
#
# Output: build/synth_check/post_synth.dcp + utilization.rpt
# ---------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
source $root/tools/openofdm_sources.tcl

set out $root/build/synth_check
file mkdir $out

puts "### [openofdm::banner]"

set_part xc7a100tcsg324-2

foreach f [openofdm::rtl]     { read_verilog $f }
foreach f [openofdm::viterbi] { read_verilog $f }
foreach f [openofdm::ip]      { read_ip      $f }

# A shipped .xci would have been saved for whatever part it was last
# customized on; upgrade_ip retargets it. Do NOT run it -quiet - a silent
# failure leaves the IP locked and synthesis dies later on a missing module.
if {[llength [get_ips]]} {
    upgrade_ip [get_ips]
    foreach ip [get_ips] {
        if {[get_property IS_LOCKED $ip]} {
            error "IP still locked after upgrade: $ip - [get_property LOCK_DETAILS $ip]"
        }
        reset_target all $ip
        generate_target synthesis $ip
        if {[catch {synth_ip $ip} msg]} { puts "### IP_GLOBAL (no OOC synth): $ip" }
    }
}

synth_design -top dot11 -mode out_of_context \
             -include_dirs [openofdm::includes] \
             -verilog_define [openofdm::defines]

write_checkpoint -force $out/post_synth.dcp
report_utilization -file $out/utilization.rpt
puts "### SYNTH_CHECK_OK  $out/post_synth.dcp"
