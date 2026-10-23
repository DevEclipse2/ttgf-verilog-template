//the primary commander for the thread responsible for decoding operations 
module thread_command(
    input wire clk,
    input wire rst_n,
    inout wire VDD_1V65,

    //from the microcode parsers
        output wire [7:0] macro_op,
        output wire [7:0] action_counter,
        output wire [7:0] param_counter,
        output wire flush,
        input wire [3:0] command,
        input wire [3:0] param_0,
        input wire [3:0] param_1,
        input wire [3:0] param_2,
        output reg  command_req_new,
        input  wire command_data_sent,

        // input [6:0] microcode_action_offset_t0, //up to 128 but since its 4 trit to convert to this it's more like 81
        //input [6:0] microcode_param_offset_t0,
        //.flush(),//this forces the microcode handler to pause, flush cache and read from action position & param position, as well as macro op position
        // output wire ,
    //secondary register
        input  wire  [23:0] trit_in_from_2nd_reg,
        output wire [23:0] trit_out_to_reg,
        output r_enable,
        output w_enable,
        
        output pc_increment,
        output [3:0] t_addr, //thread address
        output sel_cmd1,


    //alu interface
        output  wire [2:0] alu_command,
        output  wire [2:0] tritwise_command,
        output  wire [2:0] tritshift_tritwise_command, //trit shifts up to 3 front and back
        output  wire cmd_ready,
        input   wire res_ready_in,
        //4 trit
        inout [3:0] t4_a_out,
        inout [3:0] t4_b_out,
        inout       t1_a_out,
        inout       t1_b_out,

        //results here
        inout [3:0] t4_in,
        inout       t1_in,
        inout [7:0] multiply_in,

    //overlord interface
        input  wire stall,
        input  wire [7:0] bus_data_in,
        output wire request_set_pc,
        output wire pipe_empty,
        output wire pipe_full_rej,

    //error
        output wire pc_overflow,
        output wire a_ctr_overflow,
        output wire p_ctr_overflow,
        output wire reg_overflow,
        output wire [3:0] offending_id
);

reg [15:0] macroop_register;
reg using_macroop_1;//remember to only flip after macro op 1 finishes!



wire [23:0] reg_data_from;
wire [23:0] reg_data_to;
wire reg_r_en;
wire reg_w_en;
wire pc_increment;
wire [3:0] reg_addr;

reg [23:0] cmd_param_reg;
reg [2:0] cmd_param_id;
wire cmd_we;
secondary_register secondary_register (

    .clk(clk),
    .rst_n(rst_n),
    .trit_out(reg_data_from),
    .trit_in(reg_data_to),
    .r_enable(reg_r_en),
    .w_enable(reg_w_en),
    
    .pc_increment(pc_increment),
    .t_addr_in(reg_addr), //thread address
    .sel_cmd1(using_macroop_1),

    //2 spots, one from the alu and the thread manager to read and write, and another for the commandpipe feed
    // 6 per command, 
    //dock at 0 to signify its done, dock at any other invalid address to signify problem

    .binary_trit_in(cmd_param_reg),
    .commandpipe_address(cmd_param_id),
    .command_write_enable(cmd_we),
    .pc_overflow(pc_overflow)
);

ternary_pc_4t parameter_microcode_pc(
    .clk(clk),
    .rst_n(rst_n),       // Active-low synchronous/asynchronous reset
    .inc_enable(),  // High to increment PC by +1 on clock edge
    .w_enable(),    // High to overwrite PC with w_data (Jump/Branch)
    .r_enable(),    // High to drive PC onto r_data bus
    .w_data(),      // 4-trit (8-bit) branch target input
    .r_data(),      // 4-trit (8-bit) gated read output
    .overflow(p_ctr_overflow)     // Pulses high when wrapping from all +1s to all -1s
);

ternary_pc_4t action_microcode_pc(
    .clk(clk),
    .rst_n(rst_n),       // Active-low synchronous/asynchronous reset
    .inc_enable(),  // High to increment PC by +1 on clock edge
    .w_enable(),    // High to overwrite PC with w_data (Jump/Branch)
    .r_enable(),    // High to drive PC onto r_data bus
    .w_data(),      // 4-trit (8-bit) branch target input
    .r_data(),      // 4-trit (8-bit) gated read output
    .overflow(p_ctr_overflow)     // Pulses high when wrapping from all +1s to all -1s
);

native_4t4t4t4t scratchpad0 (
    // Power & Mid-Rail
    .VDD_1V65(VDD_1V65),
    
    input r_enable,
    input w_enable,
    input full12t,
    input [1:0] position,
    // 00 for 4t at position 0
    // 01 for 4t at position 1
    // 10 for 4t at position 2
    // 11 for 4t at position 3

    inout [11:0] data_in_12T,
    inout [3:0]  data_in_4T,

    inout [11:0] data_out_12T,
    inout [3:0]  data_out_4T
);


localparam  threadidle         = 2'b00, //not doing any work? well i can fix that...
            threadwaitdata     = 2'b01, //
            threadbusy         = 2'b10; //alu is up to stuff
reg [1:0]   threadstate = threadidle;


//aliased buffers / masks
//stands for alias mask buffer
reg  [23:0] am_buff_12t;
reg  [7:0] am_buff_4t;
reg  [1:0] am_buff_1t;









always @(posedge clk or negedge rst_n) begin
    //this is the main loop of the system
    if(!rst_n) begin
        am_buff_12t <= 24'd0;
        am_buff_4t <= 8'd0;
        am_buff_1t <= 2'd0;
    end else begin
        //start of the clock
        /*
        load new commands, while the rest of the thread either does housekeeping or something else
        */
    end
end
endmodule