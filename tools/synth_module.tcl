# ---------------------------------------------------------------------------
# synth_module.tcl - out-of-context synthesis of ONE module with a clock
# constraint: resource and timing numbers for before/after comparisons
# (e.g. the legacy div_gen phase vs. the cordic_arctan phase).
#
#   vivado -mode batch -source tools/synth_module.tcl -tclargs <top> <period_ns> \
#       [-generic NAME=VALUE ...] [-tag <name>] [-ip] [-files-only] [file ...]
#
#   <top>        module to synthesize (defined in verilog/*.v or in [file ...])
#   <period_ns>  create_clock period on the top's i_clk or i_clock port
#   -generic     override a top-level parameter (repeatable; synth_design -generic)
#   -tag         output directory suffix: build/synth/<top>_<tag>/
#                (default build/synth/<top>/), for several parameter sets of one top
#   -ip          force reading the Xilinx IP ([openofdm::ip]). The list is
#                empty since openFFT replaced xfft_v9 (the FFT, the dividers
#                and the multipliers are RTL now), so this only matters for a
#                downstream project that adds an IP to the list.
#   -files-only  read only the files listed, not verilog/*.v (useful while an
#                unrelated file in verilog/ does not parse)
#   file ...     extra sources, e.g. tb/phase_divlut_ref.v
#
# Examples:
#   tools/synth_module.tcl phase_divlut_ref 8.333 tb/phase_divlut_ref.v
#   tools/synth_module.tcl phase 8.333
#   tools/synth_module.tcl phase 8.333 -generic LATENCY=0 -tag lat0
#   tools/synth_module.tcl cordic_arctan 5 -generic INPUT_WIDTH=32 \
#       -generic OUTPUT_WIDTH=16 -generic PHASE_FRAC_BITS=9 -generic ROUND_MODE=1 \
#       -generic ITERATIONS=14 -tag c0_200M
#
# Output: build/synth/<top>[_<tag>]/utilization.rpt (-hierarchical),
#         utilization_summary.rpt, timing.rpt, post_synth.dcp, post_opt.dcp,
#         and on stdout
#   ### UTIL_SYNTH / FMAX_SYNTH   right after synth_design
#   ### FMAX_EST <MHz>            = 1000 / (period - WNS) after opt_design
#   ### UTIL <top> LUT=<n> FF=<n> BRAM=<n> DSP=<n>   after opt_design
# The reports and the UTIL/FMAX_EST lines are taken after opt_design, which
# removes the logic an OOC-synthesized IP keeps for outputs the wrapper does
# not use; that is what makes the numbers comparable to a routed board report.
# BRAM counts RAMB18 + RAMB36 primitives. Part xc7a100tcsg324-2 like
# synth_check.tcl; no placement or routing, so Fmax is an estimate.
#
# NOTE: reading an IP regenerates its products next to the .xci
# (reset_target all + synth_ip, like synth_check.tcl). Do not run this
# concurrently with a simulation that reads those products.
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
set root [file normalize [file join [file dirname [info script]] ..]]
source $root/tools/openofdm_sources.tcl

set part xc7a100tcsg324-2

# --- arguments -------------------------------------------------------------
if {$argc < 2} {
    error "usage: -tclargs <top> <period_ns> \[-generic NAME=VALUE ...\] \[-tag t\]\
           \[-ip\] \[-files-only\] \[file ...\]"
}
set top       [lindex $argv 0]
set period    [lindex $argv 1]
set generics  {}
set tag       ""
set forceIp   0
set filesOnly 0
set extra     {}
for {set i 2} {$i < $argc} {incr i} {
    set a [lindex $argv $i]
    switch -- $a {
        -generic    { incr i; lappend generics [lindex $argv $i] }
        -tag        { incr i; set tag [lindex $argv $i] }
        -ip         { set forceIp 1 }
        -files-only { set filesOnly 1 }
        default     { lappend extra [file normalize $a] }
    }
}
if {![string is double -strict $period] || $period <= 0} {
    error "period must be a positive number of ns, got '$period'"
}

set outName $top
if {$tag ne ""} { append outName "_$tag" }
set out $root/build/synth/$outName
file mkdir $out

puts "### SYNTH_MODULE top=$top period=${period}ns generics={$generics} out=$out"

# --- sources ---------------------------------------------------------------
set sources {}
if {!$filesOnly} { set sources [openofdm::rtl] }
foreach f $extra {
    if {![file exists $f]} { error "extra source does not exist: $f" }
    lappend sources $f
}

# The file that defines the top: used for the IP auto-detection.
set topText ""
foreach f $sources {
    set fh [open $f r]
    set txt [read $fh]
    close $fh
    if {[regexp -line "^\\s*module\\s+${top}\\y" $txt]} {
        set topText $txt
        puts "### TOP_FILE $f"
        break
    }
}
if {$topText eq ""} {
    error "no source defines module '$top' (searched [llength $sources] files)"
}
# Instantiation of xfft_v9 in the top's file (comments stripped, so a
# header line that merely mentions it does not count) - kept for trees that
# still have the IP in [openofdm::ip].
regsub -all {/\*.*?\*/} $topText "" topCode
regsub -all -line {//.*$} $topCode "" topCode
set needsIp [expr {$forceIp || [regexp -line {^\s*xfft_v9\s+(#|[A-Za-z_])} $topCode]}]

set_part $part
foreach f $sources { read_verilog $f }

# --- Xilinx IP (none since openFFT), same recipe as synth_check.tcl ----------
if {$needsIp && [llength [openofdm::ip]]} {
    foreach x [openofdm::ip] {
        puts "### IP $x"
        read_ip $x
    }
    # upgrade_ip retargets the .xci to this part. Not -quiet: a silent failure
    # leaves the IP locked and synthesis dies later on a missing module.
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

# --- synthesis -------------------------------------------------------------
set cmd [list synth_design -top $top -mode out_of_context -part $part \
             -include_dirs [openofdm::includes] \
             -verilog_define [openofdm::defines]]
foreach g $generics { lappend cmd -generic $g }
{*}$cmd

# --- clock constraint ---------------------------------------------------------
set clkPort ""
foreach c {i_clk i_clock} {
    if {[llength [get_ports -quiet $c]] > 0} { set clkPort $c; break }
}
if {$clkPort ne ""} {
    create_clock -period $period -name clk [get_ports $clkPort]
} else {
    puts "### WARN no i_clk/i_clock port on $top: no clock constraint, no Fmax"
}

# --- numbers ------------------------------------------------------------------
# Rows of the utilization summary table (7-series names); "?" if a row is missing.
proc utilRow {rpt pattern} {
    if {[regexp -line "^\\|\\s*${pattern}\\s*\\|\\s*(\[0-9.\]+)" $rpt -> v]} { return $v }
    return "?"
}
proc utilLine {top} {
    set rpt    [report_utilization -return_string]
    set lut    [utilRow $rpt {Slice LUTs\*?}]
    set ff     [utilRow $rpt {Slice Registers}]
    set ramb36 [utilRow $rpt {RAMB36/FIFO\*?}]
    set ramb18 [utilRow $rpt {RAMB18}]
    set dsp    [utilRow $rpt {DSPs}]
    if {[string is integer -strict $ramb36] && [string is integer -strict $ramb18]} {
        set bram [expr {$ramb36 + $ramb18}]
    } else {
        set bram [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == BMEM}]]
    }
    if {![string is integer -strict $dsp]} {
        set dsp [llength [get_cells -quiet -hier -filter {PRIMITIVE_GROUP == DSP}]]
    }
    return "$top LUT=$lut FF=$ff BRAM=$bram DSP=$dsp"
}
proc fmaxLine {clkPort period} {
    set wns  "n/a"
    set fmax "n/a"
    if {$clkPort ne ""} {
        set paths [get_timing_paths -quiet -max_paths 1 -setup]
        if {[llength $paths] > 0} {
            set wns  [get_property SLACK [lindex $paths 0]]
            set fmax [format %.1f [expr {1000.0 / ($period - $wns)}]]
        }
    }
    return "$fmax  (MHz; period ${period} ns, WNS $wns ns)"
}

# Post-synthesis numbers first. An OOC-synthesized IP still carries logic
# the wrapper never uses (the retired div_gen kept 24 fractional quotient
# bits its slice dropped); opt_design propagates constants across the IP
# boundary and removes it, which is what the routed board reports show.
write_checkpoint -force $out/post_synth.dcp
puts "### UTIL_SYNTH [utilLine $top]"
puts "### FMAX_SYNTH [fmaxLine $clkPort $period]"

opt_design
write_checkpoint -force $out/post_opt.dcp
report_utilization -hierarchical -file $out/utilization.rpt
report_utilization -file $out/utilization_summary.rpt
report_timing_summary -file $out/timing.rpt

puts "### FMAX_EST [fmaxLine $clkPort $period]"
puts "### UTIL [utilLine $top]"
puts "### SYNTH_MODULE_OK $out"
