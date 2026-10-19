module secondary_register (

    input clk,
    input rst_n,
    output [23:0] trit_out,
    input  [23:0] trit_in,
    input r_enable,
    input w_enable,
    
    input       pc_increment,
    input [3:0] t_addr_in, //thread address
    input sel_cmd1,

    //2 spots, one from the alu and the thread manager to read and write, and another for the commandpipe feed
    input [23:0] binary_trit_in,
    input [3:0] commandpipe_address, 
    // 6 per command, 
    //dock at 0 to signify its done, dock at any other invalid address to signify problem

    input  wire [23:0] binary_trit_in,
    input  wire [3:0]  commandpipe_address,
    input  wire        command_write_enable
);

    //parameter registers
    reg [23:0] cmd0_reg_0;
    reg [23:0] cmd0_reg_1;
    reg [23:0] cmd0_reg_2;
    reg [23:0] cmd0_reg_3;
    reg [23:0] cmd0_reg_4;
    reg [23:0] cmd0_reg_5;

    
    reg [23:0] cmd1_reg_0;
    reg [23:0] cmd1_reg_1;
    reg [23:0] cmd1_reg_2;
    reg [23:0] cmd1_reg_3;
    reg [23:0] cmd1_reg_4;
    reg [23:0] cmd1_reg_5;

    reg [23:0] gp_reg_6;
    reg [23:0] gp_reg_7;
    reg [23:0] gp_reg_8;
    //also the program counter here

    //when this entire command is done,
    //increment pc
    //load in registers (this can be done WHILE another command is being excuted)
    //profit...
    wire        pc_inc_enable;


    wire [23:0] pc_r_data;
    
    // PC Write Enable: High only when w_enable is high AND the target address is 9
    wire pc_w_enable = w_enable && (t_addr_in == 4'd5);
    // PC Read Enable: High only when r_enable is high AND the target address is 9
    wire pc_r_enable = r_enable && (t_addr_in == 4'd5);

    ternary_pc_12T program_counter (
    .clk(clk),
    .rst_n(rst_n),
    .inc_enable(pc_inc_enable),
    .w_enable(pc_w_enable),    // High to overwrite PC with w_data (Jump/Branch)
    .r_enable(pc_r_enable),    // High to drive PC onto r_data bus
    .w_data(trit_in),      // 12-trit (24-bit) branch target input
    .r_data(pc_r_data),      // 12-trit (24-bit) gated read output
    .overflow()     // Pulses high when wrapping from all +1s to all -1s
    );
    reg fetch_state_active;

    // Drive the PC enable directly with the 1-cycle pulse
    assign pc_inc_enable = fetch_state_active;
    always @(*) begin
        if (r_enable) begin
            case (t_addr_in)
                // Command Registers
                4'd9: trit_out = sel_cmd1 ? cmd1_reg_0 : cmd0_reg_0;
                4'd10: trit_out = sel_cmd1 ? cmd1_reg_1 : cmd0_reg_1;
                4'd11: trit_out = sel_cmd1 ? cmd1_reg_2 : cmd0_reg_2;
                4'd12: trit_out = sel_cmd1 ? cmd1_reg_3 : cmd0_reg_3;
                4'd13: trit_out = sel_cmd1 ? cmd1_reg_4 : cmd0_reg_4;
                4'd14: trit_out = sel_cmd1 ? cmd1_reg_5 : cmd0_reg_5;
                
                // General Purpose Registers
                4'd6: trit_out = gp_reg_6;
                4'd7: trit_out = gp_reg_7;
                4'd8: trit_out = gp_reg_8;
                
                // Program Counter Read
                4'd5: trit_out = pc_r_data;
                
                default: trit_out = 24'b0;
            endcase
        end else begin
            trit_out = 24'b0;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            
            cmd0_reg_0 <= 24'b0; cmd0_reg_1 <= 24'b0; cmd0_reg_2 <= 24'b0;
            cmd0_reg_3 <= 24'b0; cmd0_reg_4 <= 24'b0; cmd0_reg_5 <= 24'b0;
            
            cmd1_reg_0 <= 24'b0; cmd1_reg_1 <= 24'b0; cmd1_reg_2 <= 24'b0;
            cmd1_reg_3 <= 24'b0; cmd1_reg_4 <= 24'b0; cmd1_reg_5 <= 24'b0;
            
            gp_reg_6 <= 24'b0; gp_reg_7 <= 24'b0; gp_reg_8 <= 24'b0;
            
            fetch_state_active <= 1'b0;
        end else begin 
            
            // PORT 1: Command Pipe Background Loading
            // "Docking" at 0 or invalid addresses is safe because command_write_enable will be 0.
            // although it is possible to stream 1 while reading the other, it is much safer to NOT do that
            if (command_write_enable) begin
                if (sel_cmd1 == 1'b0) begin
                    // Main thread is using cmd0, so pipe loads cmd1
                    case (commandpipe_address)
                        4'd9: cmd1_reg_0 <= binary_trit_in;
                        4'd10: cmd1_reg_1 <= binary_trit_in;
                        4'd11: cmd1_reg_2 <= binary_trit_in;
                        4'd12: cmd1_reg_3 <= binary_trit_in;
                        4'd13: cmd1_reg_4 <= binary_trit_in;
                        4'd14: cmd1_reg_5 <= binary_trit_in;
                    endcase
                end else begin
                    // Main thread is using cmd1, so pipe loads cmd0
                    case (commandpipe_address)
                        4'd9: cmd0_reg_0 <= binary_trit_in;
                        4'd10: cmd0_reg_1 <= binary_trit_in;
                        4'd11: cmd0_reg_2 <= binary_trit_in;
                        4'd12: cmd0_reg_3 <= binary_trit_in;
                        4'd13: cmd0_reg_4 <= binary_trit_in;
                        4'd14: cmd0_reg_5 <= binary_trit_in;
                    endcase
                end
            end
            else if (w_enable) begin

                case (t_addr_in)
                    // Command Registers Write
                    4'd9: if (sel_cmd1) cmd1_reg_0 <= trit_in; else cmd0_reg_0 <= trit_in;
                    4'd10: if (sel_cmd1) cmd1_reg_1 <= trit_in; else cmd0_reg_1 <= trit_in;
                    4'd11: if (sel_cmd1) cmd1_reg_2 <= trit_in; else cmd0_reg_2 <= trit_in;
                    4'd12: if (sel_cmd1) cmd1_reg_3 <= trit_in; else cmd0_reg_3 <= trit_in;
                    4'd13: if (sel_cmd1) cmd1_reg_4 <= trit_in; else cmd0_reg_4 <= trit_in;
                    4'd14: if (sel_cmd1) cmd1_reg_5 <= trit_in; else cmd0_reg_5 <= trit_in;
                    // Address 4'd9 is implicitly handled by the PC module's own always block
                    // Default case safely does nothing
                endcase
            end
            //(Only GP Registers)
            if (w_enable) begin
                case (t_addr_in)
                    4'd6: gp_reg_6 <= trit_in;
                    4'd7: gp_reg_7 <= trit_in;
                    4'd8: gp_reg_8 <= trit_in;
                endcase
            end


            
            fetch_state_active <= pc_increment && !fetch_state_active; 
        end
    end

endmodule