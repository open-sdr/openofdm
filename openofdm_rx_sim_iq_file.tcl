# // Author: Xianjun Jiao, xianjun.jiao@imec.be, putaoshu@msn.com
# // SPDX-FileCopyrightText: 2022 UGent
# // SPDX-License-Identifier: AGPL-3.0-or-later

# This .tcl func needs to be called in openofdm_rx!
# This .tcl func needs to be called after the 1st sim is ready!
# Before calling this .tcl func:
# set argv [list absolute_path_to_iq_file.txt]
set iq_filename [lindex $argv 0]

# Check how many lines in it to decide run for how many us
puts "iq_filename $iq_filename"
set num_iq [exec wc -l < $iq_filename]
puts "num_iq $num_iq"
set sim_time_us [expr $num_iq / 20]
set sim_time_us [expr $sim_time_us + 1]
puts "sim_time_us $sim_time_us"
set result_dir [string range $iq_filename 0 end-4]
puts "result_dir $result_dir"

# Append the simulation iq file to ./src/openofdm_rx_pre_def.v
set  fd  [open  "./src/openofdm_rx_pre_def.v"  a]
puts $fd "`define SAMPLE_FILE \"$iq_filename\""
close $fd

# Sim
relaunch_sim
puts "result_dir $result_dir"
run $sim_time_us us

# Save the result files
exec rm -rf $result_dir
exec mkdir $result_dir
# exec cp ./openofdm_rx/openofdm_rx.sim/sim_1/behav/xsim/*.txt $result_dir -f
file copy {*}[glob ./openofdm_rx/openofdm_rx.sim/sim_1/behav/xsim/*.txt] $result_dir
