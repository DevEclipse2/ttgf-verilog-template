//the primary commander for the thread responsible for decoding operations 
module thread_command(





    output  wire [2:0] alu_command,
    output  wire [2:0] tritwise_command,
    output  wire [2:0] tritshift_tritwise_command, //trit shifts up to 3 front and back
    output  wire cmd_ready,
    input   wire res_ready_in,
    //4 trit
    inout [3:0] 4t_a_out,
    inout [3:0] 4t_b_out,
    inout       1t_a_out,
    inout       1t_b_out,

    inout [3:0] 4t_in,
    inout       1t_in,
    inout [7:0] multiply_in

);



endmodule