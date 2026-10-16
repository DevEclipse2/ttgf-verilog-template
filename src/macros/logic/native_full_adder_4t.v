(* blackbox *)
module native_full_adder_4t (
    // Power & Mid-Rail
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,
    
    // Ternary Inputs (4 trits each)
    inout [3:0] trit_in_a,
    inout [3:0] trit_in_b,
    
    // Ternary Carry
    inout trit_carry_in,
    inout trit_carry_out,
    
    // Ternary Output
    inout [3:0] trit_out
);
    // EMPTY: No logic here. 
    // OpenLane will route wires to these pins based on the bounding box in your LEF.
endmodule