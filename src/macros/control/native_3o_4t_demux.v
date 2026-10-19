(* blackbox *)
module native_3o_4t_demux (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    inout mux_line0, //flex that 3 level logic while you still can
    inout mux_line1,

    inout [3:0] trit_in,
    // Ternary outputs (4 trits each)
    inout [3:0] trit_out_0,
    inout [3:0] trit_out_1,
    inout [3:0] trit_out_2
);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule