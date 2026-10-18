(* blackbox *)
module native_tritwise_3 (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    // Ternary Inputs (1 trit each)
    inout trit_in_a,
    inout trit_in_b,
    inout [2:0] control_sig,
    // Ternary Output
    inout trit_out
);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule