(* blackbox *)
module native_8t_flags_4t_pc (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    input reg r_enable,
    input reg w_enable,
    input reg [3:0] position,
    // 0000 for 12T
    // 0001 for 4t at position 0
    // 0010 for 4t at position 1
    // 0011 for 4t at position 2
    // 1xxx for 8 trit flags

    inout [11:0] data_in_12T,
    inout [3:0]  data_in_4T,
    inout data_in_1T,

    inout [11:0] data_out_12T,
    inout [3:0]  data_out_4T,
    inout data_out_1T,

    // // Ternary Inputs (4 trits each)
    // inout [3:0] trit_in_a,
    // inout [3:0] trit_in_b,
    
    // // Ternary Carry
    // inout trit_carry_in,
    // inout trit_carry_out,
    
    // // Ternary Output
    // inout [3:0] trit_out
);

//the blackbox macro for the 8 trit flags and the micro op action count
//
// what is it gotta do?
/*
it has to be able to take in 1 4 or 12 trits of data and cover it (assuming masked already)
it should also be able to be read in batches of 1 or 4 or 12

*/
endmodule