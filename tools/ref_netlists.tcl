# ---------------------------------------------------------------------------
# ref_netlists.tcl - write the funcsim netlists of the retired Xilinx cores
# that serve as reference models for the open replacements' benches:
#
#   ip_repo/complex_multiplier/complex_multiplier_sim_netlist.v
#       cmpy 6.0      -> openCMUL tb_complex_multiplier, openCDIV tb_complex_divider
#   ip_repo/div_gen/div_gen_div_gen_0_0_sim_netlist.v
#       div_gen 5.1   -> openCDIV tb_signed_divider, tb_complex_divider
#   ip_repo/xfft_v9/xfft_v9_sim_netlist.v
#       xfft 9.1      -> openFFT tb_fft_axis
#
#   vivado -mode batch -source tools/ref_netlists.tcl [-tclargs -force]
#
# None of the cores is part of any build any more (see proc ip in
# openofdm_sources.tcl); only their .xci are versioned. A netlist that already
# exists is left alone unless -force is given. Generating one regenerates all
# products next to its .xci (reset_target + synth_ip), so do not run this
# while a bench is simulating from those files.
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
set force [expr {[info exists argv] && [lsearch -exact $argv -force] >= 0}]
set root  [file normalize [file join [file dirname [info script]] ..]]
set part  xc7a100tcsg324-2

set todo {}
foreach {xci netlist} [list \
        $root/ip_repo/complex_multiplier/complex_multiplier.xci \
        $root/ip_repo/complex_multiplier/complex_multiplier_sim_netlist.v \
        $root/ip_repo/div_gen/div_gen_div_gen_0_0.xci \
        $root/ip_repo/div_gen/div_gen_div_gen_0_0_sim_netlist.v \
        $root/ip_repo/xfft_v9/xfft_v9.xci \
        $root/ip_repo/xfft_v9/xfft_v9_sim_netlist.v] {
    if {!$force && [file exists $netlist]} {
        puts "### REF_NETLIST present: $netlist"
    } else {
        lappend todo $xci $netlist
    }
}
if {[llength $todo] == 0} { puts "### REF_NETLISTS_OK"; return }

create_project -in_memory -part $part
foreach {xci netlist} $todo { read_ip $xci }
# upgrade_ip retargets each .xci to this part. Not -quiet: a silent failure
# leaves the IP locked and synth_ip fails later.
upgrade_ip [get_ips]
foreach ip [get_ips] {
    if {[get_property IS_LOCKED $ip]} {
        error "IP still locked after upgrade: $ip - [get_property LOCK_DETAILS $ip]"
    }
    reset_target all $ip
    generate_target all $ip
    synth_ip $ip
}
foreach {xci netlist} $todo {
    if {![file exists $netlist]} { error "synth_ip did not write $netlist" }
    puts "### REF_NETLIST written: $netlist"
}
puts "### REF_NETLISTS_OK"
