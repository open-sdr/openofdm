# ---------------------------------------------------------------------------
# openofdm_sources.tcl - the authoritative description of what makes up the
# openofdm receiver: RTL, IP, include paths, required `defines, and the
# openViterbi dependency.
#
# Consumers source this file and ask it for lists, rather than keeping their
# own copy of the file names. That is what keeps a downstream project (e.g.
# RA-Sentinel's OWIFI_RX) from drifting when a file is added here:
#
#     source $ofdm/tools/openofdm_sources.tcl
#     foreach f [openofdm::rtl]        { read_verilog $f }
#     foreach f [openofdm::viterbi]    { read_verilog $f }
#     foreach f [openofdm::ip]         { read_ip      $f }
#     synth_design ... -include_dirs [openofdm::includes] \
#                      -verilog_define [openofdm::defines]
#
# Nothing in here is specific to a board or a Vivado version.
# ---------------------------------------------------------------------------

namespace eval openofdm {

    # Repository root, derived from this script's own location - so the tree
    # can be cloned anywhere.
    variable root [file normalize [file join [file dirname [info script]] ..]]

    # Files in verilog/ that are NOT part of a plain dot11 receiver build:
    #
    #   dot11_tb.v                  the testbench; belongs to sim_1, not sources
    #   common_defs.v               `include-d, never compiled standalone
    #   common_params.v             ditto (it is a body of parameters, not a module)
    #   openofdm_rx_pre_def.v       ditto (compile-time configuration)
    #   openofdm_rx.v               \  openwifi's AXI-attached wrapper family.
    #   openofdm_rx_s_axi.v          > Only needed when the receiver is dropped
    #   openofdm_rx_git_rev.v       /   into openwifi's SoC; ask for it with
    #                                   [openofdm::rtl -axi].
    variable always_excluded {
        dot11_tb.v common_defs.v common_params.v openofdm_rx_pre_def.v
    }
    variable axi_wrapper {
        openofdm_rx.v openofdm_rx_s_axi.v openofdm_rx_git_rev.v
    }

    # --- RTL ---------------------------------------------------------------
    # openofdm::rtl ?-axi? ?extra_exclusions?
    #   -axi              also return the AXI wrapper family
    #   extra_exclusions  list of basenames the caller wants dropped, for when
    #                     a downstream design provides its own version of a
    #                     module (a module-name collision is a link error that
    #                     reads as a missing module, so it is worth being
    #                     explicit about).
    proc rtl {args} {
        variable root
        variable always_excluded
        variable axi_wrapper

        set axi 0
        set extra {}
        foreach a $args {
            if {$a eq "-axi"} { set axi 1 } else { set extra [concat $extra $a] }
        }

        set skip [concat $always_excluded $extra]
        if {!$axi} { set skip [concat $skip $axi_wrapper] }

        set out {}
        foreach f [lsort [glob -nocomplain $root/verilog/*.v]] {
            if {[lsearch -exact $skip [file tail $f]] < 0} { lappend out $f }
        }
        if {[llength $out] == 0} {
            error "openofdm: no RTL found under $root/verilog - wrong \$OPENOFDM?"
        }
        # complex_mult.v / stage_mult.v instantiate complex_multiplier from
        # openCMUL, divider.v / equalizer.v instantiate signed_divider and
        # complex_divider from openCDIV, sync_long.v instantiates fft_axis
        # from openFFT (see below); they are part of the receiver, so they
        # are returned here and no consumer has to know about the extra
        # repositories.
        return [concat $out [cmul] [cdiv] [fft]]
    }

    # --- openCMUL ----------------------------------------------------------
    # The open complex multiplier that replaced the Xilinx cmpy 6.0 IP. Like
    # openViterbi it lives in its own repository (useful on its own) and is
    # found via $OPENCMUL or as a clone next to this one.
    proc cmul_root {} {
        variable root
        if {[info exists ::env(OPENCMUL)]} {
            set c $::env(OPENCMUL)
        } else {
            set c [file join [file dirname $root] openCMUL]
        }
        if {![file isdirectory $c]} {
            error "openCMUL not found at '$c'.\
                   Clone https://github.com/Tobias-DG3YEV/openCMUL next to\
                   this repository, or point \$OPENCMUL at your checkout."
        }
        return $c
    }

    proc cmul {} {
        set f [file join [cmul_root] rtl complex_multiplier.v]
        if {![file exists $f]} { error "openCMUL checkout at '[cmul_root]' has no rtl/complex_multiplier.v" }
        return [list $f]
    }

    # --- openCDIV ----------------------------------------------------------
    # The open dividers that replaced the Xilinx div_gen 5.1 IP (+ its
    # div_gen_xlslice): signed_divider for the real divisions (divider.v)
    # and complex_divider, x / h = x * conj(h) / (h * conj(h)), for the
    # equalizer. Found via $OPENCDIV or as a clone next to this one.
    proc cdiv_root {} {
        variable root
        if {[info exists ::env(OPENCDIV)]} {
            set c $::env(OPENCDIV)
        } else {
            set c [file join [file dirname $root] openCDIV]
        }
        if {![file isdirectory $c]} {
            error "openCDIV not found at '$c'.\
                   Clone https://github.com/Tobias-DG3YEV/openCDIV next to\
                   this repository, or point \$OPENCDIV at your checkout."
        }
        return $c
    }

    proc cdiv {} {
        set out {}
        foreach m {signed_divider complex_divider} {
            set f [file join [cdiv_root] rtl $m.v]
            if {![file exists $f]} { error "openCDIV checkout at '[cdiv_root]' has no rtl/$m.v" }
            lappend out $f
        }
        return $out
    }

    # --- openFFT -----------------------------------------------------------
    # The open FFT that replaced the Xilinx xfft 9.1 IP: fft_axis has the
    # IP's AXI4-Stream ports and is instantiated by sync_long.v (64 points,
    # 16 bit, unscaled, pipelined streaming). Found via $OPENFFT or as a
    # clone next to this one. All of rtl/*.v are needed (the engine modules
    # behind fft_axis); fft_sdf_twiddle.v and fft_burst.v instantiate
    # openCMUL's complex_multiplier, which [cmul] already returns.
    proc fft_root {} {
        variable root
        if {[info exists ::env(OPENFFT)]} {
            set c $::env(OPENFFT)
        } else {
            set c [file join [file dirname $root] openFFT]
        }
        if {![file isdirectory $c]} {
            error "openFFT not found at '$c'.\
                   Clone https://github.com/Tobias-DG3YEV/openFFT next to\
                   this repository, or point \$OPENFFT at your checkout."
        }
        return $c
    }

    proc fft {} {
        set out [lsort [glob -nocomplain [file join [fft_root] rtl *.v]]]
        if {[lsearch -glob $out *fft_axis.v] < 0} {
            error "openFFT checkout at '[fft_root]' has no rtl/fft_axis.v"
        }
        return $out
    }

    # --- testbench ---------------------------------------------------------
    proc testbench {} {
        variable root
        return $root/verilog/dot11_tb.v
    }

    # --- Xilinx IP ---------------------------------------------------------
    # EMPTY since openFFT replaced the last core: the receiver is plain RTL
    # (openofdm + openViterbi + openCMUL + openCDIV + openFFT) and needs no
    # IP catalog, no licence and no vendor. The proc stays so that consumers
    # keep working unchanged (they iterate over an empty list).
    #
    # Not in this list any more: ip_repo/xfft_v9/xfft_v9.xci (Fast Fourier
    # Transform 9.1, 64 points, pipelined streaming, unscaled), replaced by
    # openFFT's fft_axis, see proc fft. The .xci is kept on disk as the
    # reference model of openFFT's tb/tb_fft_axis.v (tools/ref_netlists.tcl
    # writes the netlist).
    #
    # Not in this list any more: ip_repo/complex_multiplier/complex_multiplier.xci
    # (replaced by openCMUL, see proc cmul)
    # (Complex Multiplier 6.0). The receiver uses the open, vendor-neutral
    # verilog/complex_multiplier.v instead (complex_mult.v, stage_mult.v). The
    # .xci is kept on disk on purpose: tb/tb_complex_multiplier.v checks the
    # new module bit for bit against the funcsim netlist generated from it.
    #
    # Not in this list any more either: ip_repo/div_gen/div_gen_div_gen_0_0.xci
    # and ip_repo/div_gen_xlslice/div_gen_xlslice_0_0.xci (Divider Generator
    # 5.1 and the slice that kept its integer quotient), replaced by openCDIV,
    # see proc cdiv. Kept on disk as the reference model of openCDIV's
    # tb/tb_signed_divider.v (tools/ref_netlists.tcl writes the netlist).
    proc ip {} {
        return [list]
    }

    # --- include path ------------------------------------------------------
    proc includes {} {
        variable root
        return [list $root/verilog]
    }

    # --- required `defines -------------------------------------------------
    # LUT_DIR tells lut_roms.v where the three ROM .mif files are. Both
    # synthesis and XSim resolve a relative $readmem path against the tool's
    # working directory, not against the source file, so this cannot be left
    # to a relative default.
    proc defines {} {
        variable root
        return [list LUT_DIR=\"$root/verilog\"]
    }

    # --- test vectors ------------------------------------------------------
    proc vectors {} {
        variable root
        return $root/verilog/testing_inputs
    }

    # Defines a simulation needs on top of [defines]: which vector directory
    # openofdm_rx_pre_def.v should build `SAMPLE_FILE from.
    proc sim_defines {} {
        variable root
        return [concat [defines] [list VECTOR_DIR=\"[vectors]\"]]
    }

    # --- openViterbi -------------------------------------------------------
    # The open-source Viterbi decoder that replaced the license-locked Xilinx
    # viterbi_v7_0 evaluation IP. It is a separate repository because it is
    # useful on its own; ofdm_decoder.v instantiates Viterbi_decoder by module
    # name, so it only has to be on the source path.
    #
    # Resolution order: $OPENVITERBI, then a clone sitting next to this one.
    proc viterbi_root {} {
        variable root
        if {[info exists ::env(OPENVITERBI)]} {
            set v $::env(OPENVITERBI)
        } else {
            set v [file join [file dirname $root] openViterbi]
        }
        if {![file isdirectory $v]} {
            error "openViterbi not found at '$v'.\
                   Clone https://github.com/Tobias-DG3YEV/openViterbi next to\
                   this repository, or point \$OPENVITERBI at your checkout."
        }
        return $v
    }

    proc viterbi {} {
        set out [lsort [glob -nocomplain [viterbi_root]/*.v]]
        if {[llength $out] == 0} {
            error "openViterbi checkout at '[viterbi_root]' contains no .v files"
        }
        return $out
    }

    # --- one-line provenance for build logs --------------------------------
    proc banner {} {
        variable root
        return "openofdm $root + openViterbi [viterbi_root] + openCMUL [cmul_root] + openCDIV [cdiv_root] + openFFT [fft_root]"
    }
}
