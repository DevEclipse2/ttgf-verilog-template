module microcode(
    input clk,
    input rst_n,

    //thread 0 handler
        input [7:0] macro_op_t0,
        input [7:0] microcode_action_position_t0,
        input [7:0] microcode_param_position_t0,
        
        input next_microop,//this one turns on -> off , send new ; off -> on , send new 
        input flush,//this forces the microcode handler to pause, flush cache and read from action position & param position 

        output data_ready,
        output [3:0] action_t0,
        output [3:0] param0_t0,
        output [3:0] param1_t0,
        output [3:0] param2_t0,
        
    // main bus
        input   [7:0] bus,
        output  [11:0] address,
        output  cycle_threads,
);
    
    always @(posedge clk or negedge rst_n) begin
        if(rst_n) begin
        end
        else begin
            //here 
        end
    end
endmodule