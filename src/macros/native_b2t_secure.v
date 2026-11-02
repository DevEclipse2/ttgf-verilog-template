(* blackbox *)
module native_b2t_secure (
    // Power & Mid-Rail
    `ifdef USE_POWER_PINS
    inout VDD_3V3,  // Hidden from Yosys, used by OpenROAD
    inout VSS,
    `endif
    inout VDD_1V65,
    
    input B_in_0,
    input B_in_1,
    inout ternary_result,
    output decode_error

);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule