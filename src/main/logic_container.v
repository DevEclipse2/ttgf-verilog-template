module logic_container(

    
    inout VDD_3V3,
    inout VDD_1V65,
    inout VSS,


    input clk,
    input rst_n,

);




//for thread 0
    wire [2:0] cmd_t0_wire;
    wire [2:0] tritwise_cmd_t0_wire;
    wire [2:0] shift_wise_cmd_t0_wire;
    wire cmd_ready_t0_wire;  
    wire res_ready_t0_wire;  
    wire [3:0] t4_a_t0_wire;
    wire [3:0] t4_b_t0_wire;
    wire [3:0] t4_c_t0_wire;
    wire t1_a_t0_wire;
    wire t1_b_t0_wire;
    wire t1_c_t0_wire;
    wire [7:0] t8_t0_wire;
//for thread 1
    wire [2:0] cmd_t1_wire;
    wire [2:0] tritwise_cmd_t1_wire;
    wire [2:0] shift_wise_cmd_t1_wire;
    wire cmd_ready_t1_wire;  
    wire res_ready_t1_wire;  
    wire [3:0] t4_a_t1_wire;
    wire [3:0] t4_b_t1_wire;
    wire [3:0] t4_c_t1_wire;
    wire t1_a_t1_wire;
    wire t1_b_t1_wire;
    wire t1_c_t1_wire;
    wire [7:0] t8_t1_wire;
//for thread 2
    wire [2:0] cmd_t2_wire;
    wire [2:0] tritwise_cmd_t2_wire;
    wire [2:0] shift_wise_cmd_t2_wire;
    wire cmd_ready_t2_wire;  
    wire res_ready_t2_wire;  
    wire [3:0] t4_a_t2_wire;
    wire [3:0] t4_b_t2_wire;
    wire [3:0] t4_c_t2_wire;
    wire t1_a_t2_wire;
    wire t1_b_t2_wire;
    wire t1_c_t2_wire;
    wire [7:0] t8_t2_wire;

alu core_0 (
    /*
    the alu has a floating priority system and decides to operate upon the data
    it has been slimmed down to stateless
    */
    
    VDD_3V3(VDD_3V3),
    VDD_1V65(VDD_1V65),
    VSS(VSS),

    .clk(clk),
    .rst_n(rst_n),
    //command lines
    .cmd_t0(cmd_t0_wire),
    .tritwise_command_t0(tritwise_cmd_t0_wire),
    .tritshift_tritwise_t0(shift_wise_cmd_t0_wire), //trit shifts up to 3 front and back

    .cmd_ready_t0(cmd_ready_t0_wire),
    .res_ready_t0(res_ready_t0_wire),
    //4 trit
    .t4_a_i_t0  (t4_a_t0_wire),
    .t4_b_i_t0  (t4_b_t0_wire),
    .t4_o_t0    (t4_c_t0_wire),
    //1 trit
    .t1_a_i_t0  (t1_a_t0_wire),
    .t1_b_i_t0  (t1_b_t0_wire),
    .t1_o_t0    (t1_c_t0_wire),
    .multiply_o_t0(t8_t0_wire),

    //thread 1
    .cmd_t1(cmd_t1_wire),
    .tritwise_command_t1(tritwise_cmd_t1_wire),
    .tritshift_tritwise_t1(shift_wise_cmd_t1_wire),
    .cmd_ready_t1(cmd_ready_t1_wire),
    .res_ready_t1(res_ready_t1_wire),
    //4 trit
    .t4_a_i_t1  (t4_a_t1_wire),
    .t4_b_i_t1  (t4_b_t1_wire),
    .t4_o_t1    (t4_c_t1_wire),
    //1 trit
    .t1_a_i_t1  (t1_a_t1_wire),
    .t1_b_i_t1  (t1_b_t1_wire),
    .t1_o_t1    (t1_c_t1_wire),
    .multiply_o_t1(t8_t1_wire),


    //thread 2
    .cmd_t2(cmd_t2_wire),
    .tritwise_command_t2(tritwise_cmd_t2_wire),
    .tritshift_tritwise_t2(shift_wise_cmd_t2_wire),
    .cmd_ready_t2(cmd_ready_t2_wire),
    .res_ready_t2(res_ready_t2_wire),
    //4 trit
    .t4_a_i_t2  (t4_a_t2_wire),
    .t4_b_i_t2  (t4_b_t2_wire),
    .t4_o_t2    (t4_c_t2_wire),
    //1 trit
    .t1_a_i_t2  (t1_a_t2_wire),
    .t1_b_i_t2  (t1_b_t2_wire),
    .t1_o_t2    (t1_c_t2_wire),
    .multiply_o_t2(t8_t2_wire)
);

wire [23:0] register_from_reg_t0;
wire [23:0] register_to_reg_t0;
wire w_en_t0;
wire r_en_t0;
wire pc_increment_t0;
wire [3:0] trit_address_reg_t0;
wire select_cmd_t0;

wire [23:0] command_pipe_in_t0;
wire [3:0] commandpipe_address_t0;
wire write_enable;

//each thread
secondary_register thread0_2nd_reg (

    .clk(clk),
    .rst_n(rst_n),
    .trit_out(register_from_reg_t0),
    .trit_in(register_to_reg_t0),
    .r_enable(r_en_t0),
    .w_enable(w_en_t0),
    .pc_increment(pc_increment_t0),
    .t_addr_in(trit_address_reg_t0), //thread address
    .sel_cmd1(select_cmd_t0),

    //2 spots, one from the alu and the thread manager to read and write, and another for the commandpipe feed
    // 6 per command, 
    //dock at 0 to signify its done, dock at any other invalid address to signify problem

    .binary_trit_in(command_pipe_in_t0),
    .commandpipe_address(commandpipe_address_t0),
    .command_write_enable(write_enable)
);
thread_command thread0_command(
    
    .clk(clk),
    .rst_n(rst_n),

    //from the microcode parsers
        input wire [3:0] command,
        input wire [3:0] param_0,
        input wire [3:0] param_1,
        input wire [3:0] param_2,
        output reg  command_req_new,
        input  wire command_data_sent,
        // output wire ,
    
    //secondary register
        .trit_in_from_2nd_reg(register_from_reg_t0),
        .trit_out_to_reg(register_to_reg_t0),
        .r_enable(r_en_t0),
        .w_enable(w_en_t0),
        .pc_increment(pc_increment_t0),
        .t_addr(trit_address_reg_t0), //thread address
        .sel_cmd1(select_cmd_t0),

    //alu interface
        .alu_command(cmd_t0_wire),
        .tritwise_command(tritwise_cmd_t0_wire),
        tritshift_tritwise_command(shift_wise_cmd_t0_wire), //trit shifts up to 3 front and back
        .cmd_ready(cmd_ready_t0_wire),
        .res_ready_in(res_ready_t0_wire),
        //4 trit
        .t4_a_out(t4_a_t0_wire),
        .t4_b_out(t4_b_t0_wire),
        .t1_a_out(t1_a_t0_wire),
        .t1_b_out(t1_b_t0_wire),
        //results here
        .t4_in(t4_c_t0_wire),
        .t1_in(t1_c_t0_wire),
        .multiply_in(t8_t0_wire),

    //overlord interface
        input  wire stall,
        input  wire [7:0] bus_data_in,
        output wire request_set_pc,
        output wire pipe_empty,
);




endmodule