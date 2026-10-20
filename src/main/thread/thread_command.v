//the primary commander for the thread responsible for decoding operations 
module thread_command(
    input wire clk,
    input wire rst_n,


    //from the microcode parsers
        input wire [3:0] command,
        input wire [3:0] param_0,
        input wire [3:0] param_1,
        input wire [3:0] param_2,
        output reg  command_req_new,
        input  wire command_data_sent,
        // output wire ,
    //secondary register
        input wire  [23:0] trit_in_from_2nd_reg,
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
);

reg [15:0] macroop_register;
reg using_macroop_1;

ternary_pc_4trit parameter_microcode_counter(
    .clk(clk),
    .rst_n(rst_n),       // Active-low synchronous/asynchronous reset
    .inc_enable(),  // High to increment PC by +1 on clock edge
    .w_enable(),    // High to overwrite PC with w_data (Jump/Branch)
    .r_enable(),    // High to drive PC onto r_data bus
    .w_data(),      // 4-trit (8-bit) branch target input
    .r_data(),      // 4-trit (8-bit) gated read output
    .overflow()     // Pulses high when wrapping from all +1s to all -1s
);

//command pipe fills up to 
//up to 

localparam  threadidle         = 2'b00, //not doing any work? well i can fix that...
            threadwaitdata     = 2'b01, //
            threadbusy         = 2'b10; //alu is up to stuff
reg [1:0]   threadstate = threadidle;

always @(posedge clk or negedge rst_n) begin
    //this is the main loop of the system
    if(rst_n) begin
        command_param_pipe  <= 192'd0;
        command_pipe        <= 64'd0;
    end else begin
        //start of the clock

    end
end
endmodule