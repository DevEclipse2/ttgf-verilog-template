(* blackbox *)
module native_8t_flags_4t_pc (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    input reg r_enable,
    input reg w_enable,
    input reg [1:0] position,
    // 00 for 12T
    // 01 for 4t at position 0
    // 10 for 4t at position 1
    // 11 for 4t at position 2

    inout [11:0] data_in_12T,
    inout [3:0]  data_in_4T,

    inout [11:0] data_out_12T,
    inout [3:0]  data_out_4T,


);

endmodule