//this is the wrapper that handles signal routing between the 3 threads and funnels them into the base modules

//for example

module native_alu_wrapper (

    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,   
    
    //adder!
    input wire [1:0] adder_mux,
    input wire [1:0] multi_mux,



    inout [3:0] trit4_in_a_0,
    inout [3:0] trit4_in_b_0,
    inout       trit4_in_cin_0,

    inout [3:0] trit4_out_0,
    inout       trit4_out_cout_0,

    inout [3:0] trit4_in_a_1,
    inout [3:0] trit4_in_b_1,
    inout       trit4_in_cin_1,

    inout [3:0] trit4_out_1,
    inout       trit4_out_cout_1,

    inout [3:0] trit4_in_a_2,
    inout [3:0] trit4_in_b_2,
    inout       trit4_in_cin_2,

    inout [3:0] trit4_out_2,
    inout       trit4_out_cout_2,
);

//remember to cut stuff with transmission gates if theres no data coming through, 
//and use a common transistor to pull down to ground


/*
it should be noted that the ternary adder and multiplier have different muxes and circuits,

*/

    wire [3:0] adder_operand_a;
    wire [3:0] adder_operand_b;
    wire [3:0] adder_result;
    wire       carry_in;
    wire       carry_out;

native_3i_9t_mux     ternary_adder_mux(
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (adder_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (adder_mux[1]),
    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_a_0),
    .trit_in_a_1(trit4_in_a_1),
    .trit_in_a_2(trit4_in_a_2),

    .trit_in_b_0(trit4_in_b_0),
    .trit_in_b_1(trit4_in_b_1),
    .trit_in_b_2(trit4_in_b_2),

    .trit_in_cin_0(trit_in_cin_0),
    .trit_in_cin_1(trit_in_cin_1),
    .trit_in_cin_2(trit_in_cin_2),

    .trit_out_a(adder_operand_a),
    .trit_out_b(adder_operand_b),
    .trit_out_cin(carry_in)
);
native_3o_5t_mux ternary_adder_demux (

    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (adder_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (adder_mux[1]),
    .trit_in(adder_result),
    .trit_in_cout(carry_out),
    // Ternary outputs (4 trits each)
    .trit_out_0(trit4_out_0),
    .trit_out_1(trit4_out_1),
    .trit_out_2(trit4_out_2),
    .trit_out_cout_0(trit4_out_cout0),
    .trit_out_cout_1(trit4_out_cout1),
    .trit_out_cout_2(trit4_out_cout2)
);
native_full_adder_4t ternary_adder (
        .VDD_3V3(VDD_3V3),
        .VDD_1V65(VDD_1V65),
        .VSS(VSS),
        
        .trit_in_a(operand_a),
        .trit_in_b(operand_b),
        
        .trit_carry_in(carry_in),
        .trit_carry_out(carry_out),
        
        .trit_out(adder_result)
    );





endmodule


