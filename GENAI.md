# Use of generative AI in this repository

## General usage background

The tool claude.ai was used as a coding assistant  in this repository inside interactive sessions driven by me, the author.

I have used claude.ai helping me replacing the proprietary code from Xilinx IP complex multiplier with my openCMUL implementation in the existing openofdm project (fork). Because the original openofdm code is "foreign code" from the Github project https://github.com/open-sdr/openofm, The use of AI saved me lots of time getting the proprietary code exchanged and finally running.

I always specified what AI has to do (the IP configuration to be replaced, bit- and cycle-exactness against the IP's simulation netlist, latency, interfaces), decided the approach, reviewed the generated code, ran the benches and regressions, synthesizes and tested it by myself on the RA-Sentinel hardware.

Claude drafted test benches, Tcl/shell tooling, commited messages and documentation under that direction, and the drafts were edited and re-prompted until they passed the benches.

Nothing in this repository is "purely generated". Every change was specified, reviewed, edited, simulated and tested on hardware by myself and I can explain every design decision. All commits before September 2026 (and all upstream openOFDM code) were completely written without generative AI.

## Commits with generative AI involvement

| commit  | date       | model                          | how it was used                                                                                                                                                                                                                                                                       |
| ------- | ---------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ccfc083 | 2026-09-13 | Claude Fable 5.1 (Claude Code) | complex_mult.v / stage_mult.v switched to openCMUL; tools/ (openofdm_sources.tcl, synth_check, run_sim, create_project, run_regression.tcl, synth_module.tcl), Makefile, lut_roms.v, wip/cordic_arctan/ drafted by Claude from the author's specification; reorganisation of ip_repo/ |
| 6cdf4fb | 2026-09-14 | Claude Fable 5.1 (Claude Code) | registered watchdog reset, mag_sq_avg debug tap, 512-entry atan ROM, dot11_tb.v port adaption                                                                                                                                                                                         |
| 8173a37 | 2026-09-14 | Claude Fable 5.1 (Claude Code) | Readme: openCMUL vs cmpy 6.0 comparison table (text drafted from the author's measurements)                                                                                                                                                                                           |
| 3bbe91a | 2026-09-29 | Claude Fable 5.1 (Claude Code) | Divider Generator replaced by openCDIV                                                                                                                                                                                                                                                |
| 31b653e | 2026-10-02 | Claude Fable 5.1 (Claude Code) | xfft_v9 replaced by openFFT; frame statistics for the IQ snapshot descriptor                                                                                                                                                                                                          |

### Files added or modified by the three commits with Claude trailers

ccfc083 (2026-09-13), besides deleting 974 files of the Xilinx IP output
products under `verilog/xfft_v9/`, `verilog/div_gen/` and `ip_repo/div_gen_new/`
and moving the remaining `.xci` files into `ip_repo/`:

    Makefile                              new
    tools/openofdm_sources.tcl            new
    tools/create_project.tcl              new
    tools/run_sim.tcl                     new
    tools/run_regression.tcl              new
    tools/synth_check.tcl                 new
    tools/synth_module.tcl                new
    tools/dot11_tb_behav.wcfg             moved from openofdm_rx/
    scripts/conv_iq_hex.py                new
    verilog/lut_roms.v                    new
    verilog/complex_mult.v                modified (instantiates openCMUL)
    verilog/stage_mult.v                  modified (instantiates openCMUL)
    wip/cordic_arctan/README.md           new
    wip/cordic_arctan/verilog/cordic_arctan.v    new
    wip/cordic_arctan/verilog/cordic_arctan.vh   new
    wip/cordic_arctan/verilog/phase.v            new
    wip/cordic_arctan/tb/tb_cordic_arctan.v      new
    wip/cordic_arctan/tb/tb_phase.v              new
    wip/cordic_arctan/tb/phase_divlut_ref.v      new
    wip/cordic_arctan/tools/run_tb.sh            new
    Readme.rst, .gitignore                modified
    ip_repo/complex_multiplier/complex_multiplier.xci   modified

6cdf4fb (2026-09-14):

    verilog/signal_watchdog.v             modified (registered reset)
    verilog/sync_short.v                  modified (o_mag_sq_avg tap)
    verilog/dot11.v                       modified
    verilog/ofdm_decoder.v                modified
    verilog/openofdm_rx_pre_def.v         modified
    verilog/dot11_tb.v                    modified (i_/o_ port interface)
    verilog/atan_lut.mif                  regenerated, 512 entries
    verilog/deinter_lut_from_coe.mif      new

8173a37 (2026-09-14):

    Readme.rst                            comparison table added

## From now on

Every commit that contains generated code or text records it in the commit
message in the form the policy suggests:

    Author: Tobias Weber with Claude Fable 5.1 (Claude Code)
    Prompt: <the prompt, or a summary of the session's prompts>
    Output: (this commit, reviewed and tested by the author)

Commits without such a block were written without generative AI.
