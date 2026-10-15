(* blackbox *)
module native_3o_5t_demux (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    inout mux_line, //flex that 3 level logic while you still can
    inout deactivate,

    inout [3:0] trit_in,
    inout trit_in_cout,
    // Ternary outputs (4 trits each)
    inout [3:0] trit_out_0,
    inout       trit_out_cout_0,
    inout [3:0] trit_out_1,
    inout       trit_out_cout_1,
    inout [3:0] trit_out_2,
    inout       trit_out_cout_2

);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule