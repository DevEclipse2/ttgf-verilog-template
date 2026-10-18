//this is the wrapper that handles signal routing between the 3 threads and funnels them into the base modules

//for example

module native_alu_wrapper (

    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,   
    
    input wire [1:0] adder_mux,
    input wire [1:0] multi_mux,
    input wire [1:0] tritwise_1_mux,
    input wire [1:0] tritwise_2_mux,
    input wire [1:0] tritwise_3_mux,
    input wire [1:0] tritwise_4_mux,


    inout [3:0] trit4_in_a_0,
    inout [3:0] trit4_in_b_0,
    inout [2:0] tritwise_control_0,
    inout [7:0] multiplier_out_0,
    
    inout       trit4_in_cin_0,
    inout       trit1_in_b_0,

    inout [3:0] trit4_out_0,
    inout       trit4_out_cout_0,

    inout [2:0] tritwise_control_1,
    inout [3:0] trit4_in_a_1,
    inout [3:0] trit4_in_b_1,
    inout       trit4_in_cin_1,
    inout       trit1_in_b_1,

    inout [3:0] trit4_out_1,
    inout       trit4_out_cout_1,
    inout [7:0] multiplier_out_1,


    inout [2:0] tritwise_control_2,
    inout [3:0] trit4_in_a_2,
    inout [3:0] trit4_in_b_2,
    inout       trit4_in_cin_2,
    inout       trit1_in_b_2,

    inout [3:0] trit4_out_2,
    inout       trit4_out_cout_2,

    inout [7:0] multiplier_out_2,
);

//remember to cut stuff with transmission gates if theres no data coming through, 
//and use a common transistor to pull down to ground

wire [3:0] adder_operand_a;
wire [3:0] adder_operand_b;
wire [3:0] adder_result;
wire [7:0] multiplier_result;
wire       carry_in;
wire       carry_out;

native_3i_9t_mux ternary_adder_mux(
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

    .trit_in_cin_0(trit4_in_cin_0),
    .trit_in_cin_1(trit4_in_cin_1),
    .trit_in_cin_2(trit4_in_cin_2),

    .trit_out_a(adder_operand_a),
    .trit_out_b(adder_operand_b),
    .trit_out_cin(carry_in)
);
native_3o_5t_mux ternary_adder_demux(

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
native_full_adder_4t ternary_adder(
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    .trit_in_a(operand_a),
    .trit_in_b(operand_b),
    
    .trit_carry_in(carry_in),
    .trit_carry_out(carry_out),
    
    .trit_out(adder_result)
);

native_3i_8t_mux ternary_multiplier_mux(
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (multi_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (multi_mux[1]),
    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_a_0),
    .trit_in_a_1(trit4_in_a_1),
    .trit_in_a_2(trit4_in_a_2),

    .trit_in_b_0(trit4_in_b_0),
    .trit_in_b_1(trit4_in_b_1),
    .trit_in_b_2(trit4_in_b_2),

    .trit_out_a(adder_operand_a),
    .trit_out_b(adder_operand_b),
);
native_full_adder_4t ternary_multiplier(
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    .trit_in_a(operand_a),
    .trit_in_b(operand_b),
    
    .trit_out(multiplier_result)
);
native_3o_8t_demux ternary_multiplier_demux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),

    .mux_line0 (multi_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (multi_mux[1]),

    trit_in(multiplier_result),
    //Ternary outputs (4 trits each)
    trit_out_0(multiplier_out_0),
    trit_out_1(multiplier_out_1),
    trit_out_2(multiplier_out_2 ),
);

wire        tritwise1_operand_a;
wire        tritwise1_operand_b;
wire        tritwise1_result;
wire [2:0]  tritwise1_controller;

native_3i_5t_mux ternary_tritwise_1_mux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_1_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_1_mux[1]),

    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_cin_0),
    .trit_in_b_0(trit4_in_b_0),
    .control_pass_in_0(tritwise_control_0), //make sure this is binary pass

    .trit_in_a_1(trit4_in_cin_1),
    .trit_in_b_1(trit4_in_b_1),
    .control_pass_in_1(tritwise_control_1), //make sure this is binary pass

    .trit_in_a_2(trit4_in_cin_2),
    .trit_in_b_2(trit4_in_b_2),
    .control_pass_in_2(tritwise_control_2), //make sure this is binary pass

    .trit_out_a(tritwise1_operand_a),
    .trit_out_b(tritwise1_operand_b),
    .control_pass_out(tritwise1_controller)
);

native_tritwise_1 ternary_tritwise_1(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    // Ternary Inputs (1 trit each)
    .trit_in_a(tritwise_operand_a),
    .trit_in_b(tritwise_operand_b),
    .control_sig(tritwise1_controller),
    // Ternary Output
    .trit_out(tritwise1_result)
);

native_3o_1t_demux ternary_tritwise_1_demux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_1_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_1_mux[1]),

    .trit_out_0(trit4_out_cout_0),
    .trit_out_1(trit4_out_cout_1),
    .trit_out_2(trit4_out_cout_2),
    .trit_in(tritwise1_result)
);

wire        tritwise2_operand_a;
wire        tritwise2_operand_b;
wire        tritwise2_result;
wire [2:0]  tritwise2_controller;

native_3i_5t_mux ternary_tritwise_2_mux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_2_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_2_mux[1]),

    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_cin_0),
    .trit_in_b_0(trit4_in_b_0),
    .control_pass_in_0(tritwise_control_0), //make sure this is binary pass

    .trit_in_a_1(trit4_in_cin_1),
    .trit_in_b_1(trit4_in_b_1),
    .control_pass_in_1(tritwise_control_1), //make sure this is binary pass

    .trit_in_a_2(trit4_in_cin_2),
    .trit_in_b_2(trit4_in_b_2),
    .control_pass_in_2(tritwise_control_2), //make sure this is binary pass

    .trit_out_a(tritwise2_operand_a),
    .trit_out_b(tritwise2_operand_b),
    .control_pass_out(tritwise2_controller)
);

native_tritwise_2 ternary_tritwise_2(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    // Ternary Inputs (1 trit each)
    .trit_in_a(tritwise_operand_a),
    .trit_in_b(tritwise_operand_b),
    .control_sig(tritwise2_controller),
    // Ternary Output
    .trit_out(tritwise2_result)
);

native_3o_1t_demux ternary_tritwise_2_demux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_2_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_2_mux[1]),

    .trit_out_0(trit4_out_cout_0),
    .trit_out_1(trit4_out_cout_1),
    .trit_out_2(trit4_out_cout_2),
    .trit_in(tritwise2_result)
);

wire        tritwise3_operand_a;
wire        tritwise3_operand_b;
wire        tritwise3_result;
wire [2:0]  tritwise3_controller;

native_3i_5t_mux ternary_tritwise_3_mux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_3_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_3_mux[1]),

    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_cin_0),
    .trit_in_b_0(trit4_in_b_0),
    .control_pass_in_0(tritwise_control_0), //make sure this is binary pass

    .trit_in_a_1(trit4_in_cin_1),
    .trit_in_b_1(trit4_in_b_1),
    .control_pass_in_1(tritwise_control_1), //make sure this is binary pass

    .trit_in_a_2(trit4_in_cin_2),
    .trit_in_b_2(trit4_in_b_2),
    .control_pass_in_2(tritwise_control_2), //make sure this is binary pass

    .trit_out_a(tritwise3_operand_a),
    .trit_out_b(tritwise3_operand_b),
    .control_pass_out(tritwise3_controller)
);
native_tritwise_3 ternary_tritwise_3(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    // Ternary Inputs (1 trit each)
    .trit_in_a(tritwise_operand_a),
    .trit_in_b(tritwise_operand_b),
    .control_sig(tritwise3_controller),
    // Ternary Output
    .trit_out(tritwise3_result)
);
native_3o_1t_demux ternary_tritwise_3_demux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_3_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_3_mux[1]),

    .trit_out_0(trit4_out_cout_0),
    .trit_out_1(trit4_out_cout_1),
    .trit_out_2(trit4_out_cout_2),
    .trit_in(tritwise3_result)
);

wire        tritwise4_operand_a;
wire        tritwise4_operand_b;
wire        tritwise4_result;
wire [2:0]  tritwise4_controller;

native_3i_5t_mux ternary_tritwise_4_mux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_4_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_4_mux[1]),

    // Ternary Inputs (4 trits each)
    .trit_in_a_0(trit4_in_cin_0),
    .trit_in_b_0(trit4_in_b_0),
    .control_pass_in_0(tritwise_control_0), //make sure this is binary pass

    .trit_in_a_1(trit4_in_cin_1),
    .trit_in_b_1(trit4_in_b_1),
    .control_pass_in_1(tritwise_control_1), //make sure this is binary pass

    .trit_in_a_2(trit4_in_cin_2),
    .trit_in_b_2(trit4_in_b_2),
    .control_pass_in_2(tritwise_control_2), //make sure this is binary pass

    .trit_out_a(tritwise4_operand_a),
    .trit_out_b(tritwise4_operand_b),
    .control_pass_out(tritwise4_controller)
);
native_tritwise_4 ternary_tritwise_4 (
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    
    // Ternary Inputs (1 trit each)
    .trit_in_a(tritwise_operand_a),
    .trit_in_b(tritwise_operand_b),
    .control_sig(tritwise4_controller),
    // Ternary Output
    .trit_out(tritwise4_result)
);
native_3o_1t_demux ternary_tritwise_4_demux(
    // Power & Mid-Rail
    .VDD_3V3(VDD_3V3),
    .VDD_1V65(VDD_1V65),
    .VSS(VSS),
    .mux_line0 (tritwise_4_mux[0]), //flex that 3 level logic while you still can
    .mux_line1 (tritwise_4_mux[1]),

    .trit_out_0(trit4_out_cout_0),
    .trit_out_1(trit4_out_cout_1),
    .trit_out_2(trit4_out_cout_2),
    .trit_in(tritwise4_result)
);

endmodule


