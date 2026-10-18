module secondary_register (
    inout [11:0] trit_out,
    inout [11:0] trit_in,

    input r_enable,
    input w_enable,

    input [3:0] threadmg_address,


    //2 spots, one from the alu and the thread manager to read and write, and another for the commandpipe feed
    input [23:0] binary_trit_in,
    input [3:0] commandpipe_address,  
    // 6 per command, 
    //dock at 0 to signify its done, dock at any other invalid address to signify problem
);

    reg [23:0] cmd0_reg_0;
    reg [23:0] cmd0_reg_1;
    reg [23:0] cmd0_reg_2;
    reg [23:0] cmd0_reg_3;
    reg [23:0] cmd_reg_4;
    reg [23:0] cmd_reg_5;
    //when this entire command is done,
    //increment pc
    //load in registers (this can be done WHILE another command is being excuted)
    //profit...
endmodule