# ---------------------------------------------------------------------------
# create_project.tcl - a Vivado GUI project for interactive work on the
# receiver: elaboration, schematic view, waveform debugging.
#
#   vivado -mode batch -source tools/create_project.tcl [-tclargs <dest_dir>]
#
# Default destination is build/openofdm_rx. The project REFERENCES the sources
# in this repository rather than copying them, so edits made in the GUI land in
# version control.
#
# The project is a build product: it is regenerated, not committed. The batch
# scripts (run_sim.tcl, synth_check.tcl) stay authoritative.
# ---------------------------------------------------------------------------
set root [file normalize [file join [file dirname [info script]] ..]]
source $root/tools/openofdm_sources.tcl

set dest [expr {$argc > 0 ? [lindex $argv 0] : "$root/build/openofdm_rx"}]
file mkdir $dest

puts "### [openofdm::banner]"

create_project -force openofdm_rx $dest -part xc7a100tcsg324-2

add_files -norecurse -fileset sources_1 [openofdm::rtl]
add_files -norecurse -fileset sources_1 [openofdm::viterbi]
add_files -norecurse -fileset sources_1 [openofdm::ip]
add_files -norecurse -fileset sim_1     [openofdm::testbench]

set_property top dot11    [get_filesets sources_1]
set_property top dot11_tb [get_filesets sim_1]

foreach fs {sources_1 sim_1} {
    set_property include_dirs [openofdm::includes] [get_filesets $fs]
}
set_property verilog_define [openofdm::defines]                        [get_filesets sources_1]
set_property verilog_define [concat [openofdm::sim_defines] VITERBI_TRACE] [get_filesets sim_1]

# The saved waveform layout for dot11_tb, from the upstream project.
if {[file exists $root/tools/dot11_tb_behav.wcfg]} {
    add_files -fileset sim_1 -norecurse $root/tools/dot11_tb_behav.wcfg
}

update_compile_order -fileset sources_1

puts "### PROJECT_CREATED [get_property DIRECTORY [current_project]]"
puts "### sources = [llength [get_files -of_objects [get_filesets sources_1]]]"
