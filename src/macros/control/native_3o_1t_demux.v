(* blackbox *)
//this is smaller by a bit
module native_3o_1t_demux (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    inout mux_line0, //flex that 3 level logic while you still can
    inout mux_line1,
    inout trit_out_0,
    inout trit_out_1,
    inout trit_out_2,
    inout trit_in,
);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule