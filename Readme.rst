OpenOFDM - Fork for RA-Sentinel
===============================

This project contains a Verilog implementation of 802.11 OFDM PHY decoder
based on the source code of the original openOFDM by Jinghao Shi.
https://github.com/open-sdr/openofdm. The modification in this fork
have the following intentions:

 - Increase code readability
 - Add phase deviation output (deviation between or mastertlock and the signal received over the air)
 - Replace the proprietary end most importantly the limited evaluation IPs with oprn source alternatives.

Features are:

 - Fully synthesizable (tested on Ettus Research USRP N210 platform)
 - Full support for legacy 802.11a/g
 - Support 802.11n for MCS 0 - 7 @ 20 MHz bandwidth
 - Cross validation with included Python decoder 
 - Modular design for easy modification and extension
 - Replacement of the proprietary Viterbi decoder by an open variant

See full documentation of the original openOFDM at http://openofdm.readthedocs.io.

Environment Setup
-----------------

The code of this fork is meant to be run and synthetisied in AMD Vivado 2024.1


Input and Output
----------------

In a nutshell, the top level ``dot11`` Verilog module takes 2x 12-bit I/Q samples
as input, and output decoded bytes in 802.11 packet. The sampling
rate is 20 MSPS and the clock rate is 100 MHz. This means this module expects
one pair of I/Q sample every 5 clock ticks.


License
-------

`Apache License 2.0 <https://www.apache.org/licenses/LICENSE-2.0>`_

FAQs
----

**Q: Why this form from original openOFD?**

A: Becuase openOFDM is used for other means than really transporting data over the air,
I need to make some modifications and comments to the code which are focussed on forensic
aspects and not needed|wanted in the original openOFDM project.
