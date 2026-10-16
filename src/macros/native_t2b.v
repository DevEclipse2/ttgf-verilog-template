(* blackbox *)
module native_b2t_secure (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,

    inout [1:0] binary_result,
    inout ternary_input,    
);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule