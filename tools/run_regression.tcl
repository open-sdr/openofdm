# ---------------------------------------------------------------------------
# run_regression.tcl - simulate the dot11 receiver against a list of reference
# vectors in ONE Vivado session and report the FCS verdict per vector.
#
#   vivado -mode batch -source tools/run_regression.tcl -tclargs [-out <dir>] \
#          [-openofdm <dir>] <group>|<vector> ...
#
#   groups: 11a  the 802.11a rate ladder (7 conducted) + 2 simulated a/g frames
#           11n  HT MCS0..7 conducted + the radiated MCS2 capture
#           sim  every vector under testing_inputs/simulated
#           all  11a + 11n + sim            (default when nothing is given: 11a)
#   <vector> is a path relative to testing_inputs/ or an absolute path.
#
# One throwaway project (fresh every run, so nothing stale is reused; an IP, if
# a tree still has one, is IMPORTED into it so that several sessions can run in
# parallel without racing on ip_repo/ - the receiver has none since openFFT),
# then one launch_simulation per vector with SAMPLE_FILE passed as a -d define (a
# command-line -d beats the `define in openofdm_rx_pre_def.v). Each run is
# cross-checked against the vector name the bench actually compiled in
# (sample_file_name.txt) - never trust a decode without that.
#
# Results: <out>/results.txt (appended), one line per vector:
#   <name> <verdict> frames=<n> ok=<n> bytes=<n> | <first SIGNAL line>
# plus <out>/dumps/<vector>/{fcs_out,byte_out,signal_out,equalizer_out,...}.txt for diffing
# two runs against each other (an A/B of an RTL change: same verdicts, same
# frame counts, and byte-identical payloads on every FCS-OK frame).
#
# Project: RA-Sentinel (NLnet) - fork of openofdm,
#          https://github.com/Tobias-DG3YEV/openofdm
# Engineer: Tobias Weber
# ---------------------------------------------------------------------------
# Copyright 2026 Tobias Weber
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ---------------------------------------------------------------------------
set argv_ [expr {[info exists argv] ? $argv : {}}]
set out ""
set ofdmdir ""
set items {}
for {set i 0} {$i < [llength $argv_]} {incr i} {
    set a [lindex $argv_ $i]
    if {$a eq "-out"} { incr i; set out [lindex $argv_ $i]; continue }
    if {$a eq "-openofdm"} { incr i; set ofdmdir [lindex $argv_ $i]; continue }
    lappend items $a
}
if {$ofdmdir eq ""} { set ofdmdir [file normalize [file join [file dirname [info script]] ..]] }
source $ofdmdir/tools/openofdm_sources.tcl
if {$out eq ""} { set out $ofdmdir/build/regression }
file mkdir $out
set ti [openofdm::vectors]

proc glob1 {pat} { set g [lsort [glob -nocomplain $pat]]; return [expr {[llength $g] ? [lindex $g 0] : ""}] }
set vectors {}
if {![llength $items]} { set items {11a} }
# expand "all" first: foreach iterates over a snapshot of the list, so
# appending to $items inside the loop would never be visited
set expanded {}
foreach it $items {
    if {$it eq "all"} { lappend expanded 11a 11n sim } else { lappend expanded $it }
}
set items $expanded
foreach it $items {
    switch -- $it {
        11a {
            foreach r {6 9 12 18 24 36 48} {
                set v [glob1 "$ti/conducted/dot11a_${r}mbps_*_openwifi.txt"]; if {$v ne ""} { lappend vectors $v }
            }
            foreach v {ag_6M_len14_pre100_post200_openwifi.txt ag_54M_len1537_pre100_post200_openwifi.txt} {
                if {[file exists $ti/simulated/$v]} { lappend vectors $ti/simulated/$v }
            }
        }
        11n {
            foreach r {6.5 7.2 13 26 39 52 58.5 65} {
                set v [glob1 "$ti/conducted/dot11n_${r}mbps_*_openwifi.txt"]; if {$v ne ""} { lappend vectors $v }
            }
            set v [glob1 "$ti/radiated/dot11n_19.5mbps_openwifi.txt"]; if {$v ne ""} { lappend vectors $v }
        }
        sim { foreach v [lsort [glob -nocomplain "$ti/simulated/*.txt"]] { lappend vectors $v } }
        default {
            set v $it
            if {[file pathtype $v] ne "absolute"} { set v [file join $ti $v] }
            if {![file exists $v]} { error "vector does not exist: $v" }
            lappend vectors $v
        }
    }
}
# dedupe, keep order
set seen {}; set vlist {}
foreach v $vectors { if {[lsearch -exact $seen $v] < 0} { lappend seen $v; lappend vlist $v } }
set vectors $vlist
puts "### [openofdm::banner]"
puts "### REGRESSION [llength $vectors] vectors -> $out"

# --- one fresh project ----------------------------------------------------
set pdir $out/proj
file delete -force $pdir
create_project -force regr $pdir -part xc7a100tcsg324-2
add_files -norecurse -fileset sources_1 [openofdm::rtl]
add_files -norecurse -fileset sources_1 [openofdm::viterbi]
# import (copy) the IP into the project so parallel sessions never generate
# products into the shared ip_repo/ at the same time
if {[llength [openofdm::ip]]} { import_files -norecurse -fileset sources_1 [openofdm::ip] }
add_files -norecurse -fileset sim_1     [openofdm::testbench]
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
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
set simdir $pdir/regr.sim/sim_1/behav/xsim

set fh [open $out/results.txt a]
puts $fh "==== regression run [clock format [clock seconds]] ===="
foreach vec $vectors {
    set name [file tail $vec]
    # CLK_SPEED_120M + BETTER_SENSITIVITY as in openofdm_rx_pre_def.v; LUT_DIR/VECTOR_DIR mandatory.
    set_property verilog_define [concat [openofdm::sim_defines] \
        [list CLK_SPEED_120M BETTER_SENSITIVITY VITERBI_TRACE "SAMPLE_FILE=\"$vec\""]] \
        [get_filesets sim_1]
    catch {close_sim -quiet}
    foreach t {fcs_out.txt byte_out.txt signal_out.txt sample_file_name.txt} {
        catch {file delete -force $simdir/$t}
    }
    set t0 [clock seconds]
    if {[catch {launch_simulation} msg]} {
        puts "### FAIL(sim)   $name : $msg"
        puts $fh [format "%-60s FAIL(sim)" $name]; flush $fh
        continue
    }
    set opened "?"
    if {[file exists $simdir/sample_file_name.txt]} {
        set f [open $simdir/sample_file_name.txt r]; set opened [string trim [read $f]]; close $f
    }
    set matched [expr {$opened eq $vec}]
    set fcs_pass 0; set fcs_total 0
    if {[file exists $simdir/fcs_out.txt]} {
        set f [open $simdir/fcs_out.txt r]
        foreach line [split [string trim [read $f]] "\n"] {
            if {[string trim $line] eq ""} continue
            incr fcs_total
            if {[lindex $line 1] == 1} { incr fcs_pass }
        }
        close $f
    }
    set nbytes 0
    if {[file exists $simdir/byte_out.txt]} {
        set f [open $simdir/byte_out.txt r]
        set c [string trim [read $f]]; close $f
        set nbytes [expr {$c eq "" ? 0 : [llength [split $c "\n"]]}]
    }
    set sig "-"
    if {[file exists $simdir/signal_out.txt]} {
        set f [open $simdir/signal_out.txt r]; set sig [string trim [lindex [split [read $f] "\n"] 0]]; close $f
    }
    set verdict [expr {!$matched ? "WRONG-VECTOR" : ($fcs_pass > 0 ? "FCS-OK" : "FCS-FAIL")}]
    set dt [expr {[clock seconds] - $t0}]
    puts [format "### %-12s %-60s frames=%d ok=%d bytes=%d | %s (%ds)" $verdict $name $fcs_total $fcs_pass $nbytes $sig $dt]
    puts $fh [format "%-60s %-12s frames=%d ok=%d bytes=%d | %s" $name $verdict $fcs_total $fcs_pass $nbytes $sig]
    flush $fh
    set keep $out/dumps/[file rootname $name]
    file mkdir $keep
    foreach t {fcs_out.txt byte_out.txt signal_out.txt phy_len.txt status_code.txt sample_file_name.txt equalizer_out.txt} {
        if {[file exists $simdir/$t]} { file copy -force $simdir/$t $keep/$t }
    }
    catch {close_sim -quiet}
}
close $fh
puts "### REGRESSION_DONE -> $out/results.txt"
