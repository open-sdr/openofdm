OpenOFDM - Fork for RA-Sentinel
===============================

This project contains a Verilog implementation of an 802.11 OFDM PHY decoder,
based on the original openOFDM by Jinghao Shi
(https://github.com/open-sdr/openofdm). The modifications in this fork have the
following intentions:

 - Increase code readability (ports carry ``i_``/``o_`` prefixes; the upstream
   originals are in this repository's history before commit ``019cba8`` and at
   https://github.com/open-sdr/openofdm)
 - Add phase deviation output (deviation between our master clock and the
   signal received over the air)
 - Replace the proprietary, and most importantly the licence-limited
   evaluation IP, with open-source alternatives

Features:

 - Fully synthesizable, with **no IP licence required** - a stock Vivado
   install is enough
 - Full support for legacy 802.11a/g
 - 802.11n MCS 0 - 7 @ 20 MHz bandwidth
 - Cross validation with the included Python decoder
 - Modular design for easy modification and extension

See the full documentation of the original openOFDM at
http://openofdm.readthedocs.io.


What was replaced
-----------------

Five Xilinx cores are gone from this fork - the receiver is plain Verilog:

**The Viterbi decoder.** ``viterbi_v7_0`` is a licence-locked evaluation core:
it stops working after a time limit and cannot be shipped. ``ofdm_decoder.v``
now instantiates ``Viterbi_decoder`` from **openViterbi**, a soft-decision,
erasure-aware decoder in plain Verilog-2001 that lives in its own repository:

    https://github.com/Tobias-DG3YEV/openViterbi

**The three ROM look-up tables** (``rot_lut``, ``atan_lut``, ``deinter_lut``)
were ISE-era coregen ``.xco``/``.ngc`` relics whose ``.xci`` conversions no
longer synthesize under Vivado 2025.x. ``verilog/lut_roms.v`` replaces them
with inferred block ROMs initialised by ``$readmemb`` from the *original*
coregen ``.mif`` files - bit-identical contents, same one-cycle output-register
latency the instantiating code counts on.

**The complex multiplier.** ``complex_mult.v`` and ``stage_mult.v`` used the
Xilinx Complex Multiplier 6.0 (``cmpy``, 16x16 -> 32 bit, latency 3). They now
instantiate ``complex_multiplier`` from **openCMUL**, a plain-Verilog pipelined
complex multiplier in its own repository, bit- and cycle-exact to the IP in
that configuration (verified against the IP's own simulation netlist over
212 501 cycles by openCMUL's bench):

    https://github.com/Tobias-DG3YEV/openCMUL

The IP's ``.xci`` is kept under ``ip_repo/`` purely as the reference model of
that bench; it is not read by any build.

Measured against the IP (xc7a100t-2, 16x16 -> 32 bit, OOC synthesis, Fmax
estimated from the post-synthesis slack):

========================  ==========================  =======  ===  ===  ===  =========
core                      mode                        latency  DSP  LUT  FF   Fmax est.
========================  ==========================  =======  ===  ===  ===  =========
Xilinx cmpy 6.0           Performance (4 mult.)       3        4    2    2    ~300 MHz
openCMUL                  OPTIMIZE_GOAL=1 (4 mult.)   3        4    2    3    ~400 MHz
Xilinx cmpy 6.0           Resources (3 mult.)         6        3    2    114  ~610 MHz
openCMUL                  OPTIMIZE_GOAL=0 (Gauss)     4        3    50   68   ~310 MHz
========================  ==========================  =======  ===  ===  ===  =========

The receiver uses the four-multiplier mode: same DSP count, same latency,
bit- and cycle-exact outputs.

**The divider.** ``divider.v`` (LVPE and arctangent divisions) and the
equalizer used the Xilinx Divider Generator 5.1 (``div_gen``, Radix2, 32 / 24
bit signed, latency 36) followed by ``div_gen_xlslice``, which kept the
integer quotient. ``divider.v`` now instantiates ``signed_divider`` from
**openCDIV**, bit- and cycle-exact to that pair (including its result on a
division by zero, which ``phase.v`` relies on). The equalizer's division of
a subcarrier x by the channel estimate h::

    x / h = x * conj(h) / (h * conj(h))

took two complex multipliers and two dividers, spelled out in
``equalizer.v``. It is now one ``complex_divider`` from the same repository,
same arithmetic bit for bit:

    https://github.com/Tobias-DG3YEV/openCDIV

The IP's ``.xci`` (and the slice's) are kept under ``ip_repo/`` purely as
the reference model of openCDIV's benches; no build reads them.

Measured against the IP (xc7a100t-2, 32 / 24 bit signed, latency 36, OOC
synthesis + opt_design, Fmax estimated from the slack against 3 ns):

========================  ===========================  =======  ====  ====  =========
core                      datapath                     latency  LUT   FF    Fmax est.
========================  ===========================  =======  ====  ====  =========
Xilinx div_gen 5.1        one real division            36       952   2166  ~229 MHz
openCDIV signed_divider   one real division            36       968   1827  ~312 MHz
2x cmpy + 2x div_gen      x * conj(h) / (h * conj(h))  39       1963  4333  ~229 MHz
openCDIV complex_divider  x * conj(h) / (h * conj(h))  39       1976  3598  ~308 MHz
========================  ===========================  =======  ====  ====  =========

(The last two rows include the six DSP48E1 of the two complex multipliers;
the multipliers are openCMUL in both, so the difference is the dividers.)

**The FFT.** ``sync_long.v`` used the Xilinx Fast Fourier Transform 9.1
(``xfft_v9``: 64 points, 16-bit samples, unscaled 23-bit result, pipelined
streaming I/O, natural order). It now instantiates ``fft_axis`` from
**openFFT**, an open FFT with the IP's AXI4-Stream ports and data layout -
only the module name and the parameters changed in ``sync_long.v``. openFFT
has two engines (pipelined streaming radix-2^2, one sample per clock, as
used here; and a one-butterfly burst engine for a tenth of the logic), both
built on openCMUL's multiplier, with the IP's unscaled / scaled arithmetic,
inverse transform, configuration word and event flags:

    https://github.com/Tobias-DG3YEV/openFFT

The IP's ``.xci`` is kept under ``ip_repo/`` purely as the reference model of
openFFT's bench; no build reads it. ``[openofdm::ip]`` is an empty list now.

Measured against the IP (xc7a100t-2, 64 points, 16-bit data, unscaled,
natural order, OOC synthesis + opt_design, Fmax from the worst slack against
a 5 ns clock; see openFFT's README for the full table)::

    core                      configuration                    LUT    FF    BRAM  DSP  Fmax est.
    Xilinx xfft 9.1           pipelined streaming, latency 212 1403   2609  2     6    ~348 MHz
    openFFT fft_axis          streaming, LATENCY=212 (here)    1344   800   1     8    ~225 MHz
    openFFT fft_axis          streaming, natural latency 141   1173   635   1     8    ~225 MHz
    openFFT fft_axis          streaming, 3-mult (OPTIMIZE_GOAL=0) 1268 943  1     6    ~225 MHz
    openFFT fft_axis          burst (ARCH=0), latency 295      850    446   0     4    ~201 MHz

On the same 14 400 result samples of openFFT's bench (random, tones, rails,
impulses, with and without gaps and back pressure), 91 % of the 23-bit
results are bit-identical to the IP's, 99.92 % are identical in bits 22:7 -
the 16 bits ``sync_long.v`` keeps - and no sample differs by more than 2 LSB
(RMS 0.25 LSB). Both cores show the same error against the double precision
transform (max 21.8 LSB, RMS 2.33 LSB). ``sync_long.v`` instantiates the
core with ``LATENCY = 212``, the IP's latency: ``dot11.v`` decides in its
HT-SIG handling by ``num_ofdm_symbol`` whether to skip the HT-STS symbol, a
timing "quick fix" that depends on when the FFT results arrive; with the
natural 141 clocks the 65 Mbps conducted capture lost its three decodable
frames, with 212 the receiver regression (``make regression``) decodes all
31 reference vectors with the same verdicts, frame counts and payloads as
with the IP.

No Xilinx core is left in the receiver.


Environment setup
-----------------

Requires AMD Vivado (developed against 2025.2; 2024.1 also elaborates) and a
checkout of openViterbi, openCMUL, openCDIV and openFFT. Clone them side by
side::

    cd ~
    git clone https://github.com/Tobias-DG3YEV/openViterbi.git
    git clone https://github.com/Tobias-DG3YEV/openCMUL.git
    git clone https://github.com/Tobias-DG3YEV/openCDIV.git
    git clone https://github.com/Tobias-DG3YEV/openFFT.git
    git clone https://github.com/Tobias-DG3YEV/openofdm.git

That layout needs no configuration - openofdm looks for ``openViterbi``,
``openCMUL``, ``openCDIV`` and ``openFFT`` next to itself. Elsewhere, set
``$OPENVITERBI`` / ``$OPENCMUL`` / ``$OPENCDIV`` / ``$OPENFFT`` to your
checkouts. Then::

    source /tools/2025.2/Vivado/settings64.sh
    cd ~/openofdm
    make check      # out-of-context synthesis of dot11 - the setup smoke test
    make sim        # simulate dot11_tb against the default reference vector
    make tb         # openCMUL's, openCDIV's and openFFT's benches vs the
                    # netlists of the cmpy / div_gen / xfft cores they replace
                    # (XSim); writes the netlists first if missing (make refnetlists)
    make regression # dot11 against every reference vector, FCS verdict per rate
    make project    # generate a Vivado GUI project under build/

``make sim`` accepts a vector relative to ``verilog/testing_inputs``::

    make sim VECTOR=simulated/ag_6M_len14_pre100_post200_openwifi.txt


Building it into a design
-------------------------

Do not enumerate the file list by hand. ``tools/openofdm_sources.tcl`` is the
authoritative description of what makes up the receiver; source it and ask::

    source $ofdm/tools/openofdm_sources.tcl
    foreach f [openofdm::rtl]     { read_verilog $f }   ;# the receiver
    foreach f [openofdm::viterbi] { read_verilog $f }   ;# openViterbi
    foreach f [openofdm::ip]      { read_ip      $f }   ;# empty since openFFT
    synth_design -top dot11 \
        -include_dirs   [openofdm::includes] \
        -verilog_define [openofdm::defines]

``[openofdm::rtl]`` already drops the testbench, the ``\`include``-only files
and the AXI wrapper family (ask for the latter with ``[openofdm::rtl -axi]``),
and it appends openCMUL's ``complex_multiplier.v``, openCDIV's
``signed_divider.v`` and ``complex_divider.v`` and openFFT's ``rtl/*.v``.

``[openofdm::defines]`` is **not optional**. It carries ``LUT_DIR``, which
tells ``lut_roms.v`` where its three ``.mif`` files are. Both synthesis and
XSim resolve a relative ``$readmem`` path against the *tool's working
directory*, not the source file's, so it cannot be left to a default. Omit it
and the ROMs load as X: synthesis succeeds with only a warning, and the
receiver silently decodes nothing.

RA-Sentinel's OWIFI_RX is a worked example of a board integration built this
way.


Input and output
----------------

In a nutshell, the top level ``dot11`` Verilog module takes 2x 12-bit I/Q
samples as input and outputs the decoded bytes of the 802.11 packet. The
sampling rate is 20 MSPS and the clock rate is 100 MHz, so the module expects
one pair of I/Q samples every 5 clock ticks.


Repository layout
-----------------

::

    verilog/            the receiver RTL; dot11.v is the top level
      frame_stats.v     per-frame CPE / EVM statistics of the receiver's own
                        estimates, exported with sync_short's CFO for the
                        RA-Sentinel IQ snapshot descriptor (fingerprinting)
      lut_roms.v        inferred-BRAM replacements for the coregen ROMs
      *.mif             their contents
      dot11_tb.v        the receiver testbench
      testing_inputs/   reference IQ captures (conducted/radiated/simulated)
    ip_repo/            the retired Xilinx cores (cmpy, div_gen, xfft_v9) as
                        .xci only: reference models of the openCMUL / openCDIV /
                        openFFT benches, no build reads them
    tools/              openofdm_sources.tcl + the Vivado flows:
      run_regression.tcl  every reference vector through dot11_tb, one session
      ref_netlists.tcl  funcsim netlists of the retired cmpy / div_gen / xfft cores
      synth_module.tcl  OOC synthesis + Fmax estimate of one module
    wip/cordic_arctan/  parked: open arctangent for phase.v (next milestone)
    scripts/            python: LUT generators, reference decoder, conv_iq_hex
    docs/               the upstream sphinx documentation


License
-------

`Apache License 2.0 <https://www.apache.org/licenses/LICENSE-2.0>`_


FAQs
----

**Q: Why fork from the original openOFDM?**

A: Because openOFDM is used here for other means than really transporting data
over the air, I need to make modifications and comments to the code which are
focussed on forensic aspects and are not needed or wanted in the original
openOFDM project.

**Q: The build fails with "openViterbi not found".**

A: Clone https://github.com/Tobias-DG3YEV/openViterbi next to this repository,
or point ``$OPENVITERBI`` at your checkout. The scripts fail loudly here on
purpose - the alternative is synthesising a receiver with no decoder in it.

**Q: The build fails with "openCMUL not found".**

A: Same as for openViterbi: clone https://github.com/Tobias-DG3YEV/openCMUL
next to this repository, or point ``$OPENCMUL`` at your checkout.

**Q: The build fails with "openCDIV not found".**

A: Same again: clone https://github.com/Tobias-DG3YEV/openCDIV next to this
repository, or point ``$OPENCDIV`` at your checkout.

**Q: Everything synthesises but nothing decodes.**

A: Check ``LUT_DIR`` - see "Building it into a design" above.
