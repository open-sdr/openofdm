# Parked: open arctangent (cordic_arctan) for phase.v

Complete and verified, but NOT part of the receiver build yet: the current
milestone delivers only the complex multiplier (openCMUL); phase.v stays on
the Xilinx Divider Generator + atan ROM until the arctangent milestone.

Contents (exactly as reviewed on 2026-09-13):
  verilog/cordic_arctan.v, cordic_arctan.vh   the core (CORDIC 6.0-like options)
  verilog/phase.v                              phase.v rewired onto the core,
                                               40-clock drop-in, output clamped
  tb/tb_cordic_arctan.v                        14 configurations vs exact atan2
  tb/tb_phase.v, tb/phase_divlut_ref.v         new vs legacy vs exact atan2
  tools/run_tb.sh                              xvlog/xelab/xsim runner for the benches
Results: max error 0.610 LSB (legacy 1.707), 40-vector receiver regression
identical to the legacy path, full WBMC chip WNS +0.156 ns.

To re-activate: move verilog/* to ../../verilog (the glob picks them up),
tb/* to ../../tb, tools/run_tb.sh to ../../tools, and put the Readme section
"The cordic_arctan core" back (git history of Readme.rst has it).
