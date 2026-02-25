`define ATAN_LUT_LEN_SHIFT          9
// changing this requires changing PI definition in common_params.v accordingly
`define ATAN_LUT_SCALE_SHIFT        9

`define ROTATE_LUT_LEN_SHIFT        `ATAN_LUT_SCALE_SHIFT
//`define ROTATE_LUT_SCALE_SHIFT      11 // OpenWifi implemented a right shift of 1, in sync_long.v
`define ROTATE_LUT_SCALE_SHIFT      10    // Just doing it in the rotate.v with this define.  Maintains signal mag

//`define CONS_SCALE_SHIFT            10 // Short for Constellation Scale Shift?
`define CONS_SCALE_SHIFT            5  // Lowered to prevent overflow of prod_i/q , the dividends to the normalization dividers, AO
