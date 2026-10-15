module alu(
    /*
    the alu has a floating priority system and decides to operate upon the data
    it has been slimmed down to stateless
    */
    input   wire clk,
    input   wire rst_n,
    //command lines
    input   wire [2:0] cmd_t0,
    //
    input   wire [1:0] tshift_t0,
    input   wire [4:0] tritwise_t0,

    input   wire cmd_ready_t0,
    output  reg  res_ready_t0,
    //4 trit
    inout [3:0] 4t_a_i_t0,
    inout [3:0] 4t_b_i_t0,
    inout [3:0]   4t_o_t0,
    //1 trit
    inout       1t_a_i_t0,
    inout       1t_b_i_t0,
    inout         1t_o_t0,

    inout [7:0] multiply_o_t0,

    //command lines
    input   wire [2:0] cmd_t1,
    //
    input   wire [1:0] tshift_t1,
    input   wire [4:0] tritwise_t1,

    input   wire cmd_ready_t1,
    output  reg  res_ready_t1,
    //4 trit
    inout [3:0] 4t_a_i_t1,
    inout [3:0] 4t_b_i_t1,
    inout [3:0]   4t_o_t1,
    //1 trit
    inout       1t_a_i_t1,
    inout       1t_b_i_t1,
    inout         1t_o_t1,
    
    inout [7:0] multiply_o_t1,


    input   wire [2:0] cmd_t2,
    //
    input   wire [1:0] tshift_t2,
    input   wire [4:0] tritwise_t2,

    input   wire cmd_ready_t2,
    output  reg  res_ready_t2,
    //4 trit
    inout [3:0] 4t_a_i_t2,
    inout [3:0] 4t_b_i_t2,
    inout [3:0]   4t_o_t2,
    //1 trit
    inout       1t_a_i_t2,
    inout       1t_b_i_t2,
    inout         1t_o_t2,
    inout [7:0] multiply_o_t2,

);
    
reg [6:0] locked_t0, locked_t1, locked_t2;

reg [1:0] priority_t0 = 2'b00;
reg [1:0] priority_t1 = 2'b00;
reg [1:0] priority_t2 = 2'b00;

// adder, multiplier,tritshift and tritwise 1, 2, 3, 4,

reg [6:0] claimed;
reg [6:0] grant_t0;
reg [6:0] grant_t1;
reg [6:0] grant_t2;


wire [6:0] req_mask_t0 = (cmd_t0 != 3'b000) ? (7'b0000001 << (cmd_t0 - 1'b1)) : 7'b0000000;
wire [6:0] req_mask_t1 = (cmd_t1 != 3'b000) ? (7'b0000001 << (cmd_t1 - 1'b1)) : 7'b0000000;
wire [6:0] req_mask_t2 = (cmd_t2 != 3'b000) ? (7'b0000001 << (cmd_t2 - 1'b1)) : 7'b0000000;

always @(*) begin
    // Base claimed mask inherits currently locked units
    claimed  = locked_t0 | locked_t1 | locked_t2;
    grant_t0 = 7'b0;
    grant_t1 = 7'b0;
    grant_t2 = 7'b0;
    // --- Priority 0 ---
    // A thread is only evaluated if it is NOT currently holding a lock (!res_ready)
    if (priority_t0 == 2'd0 && cmd_ready_t0 && !res_ready_t0) begin
        grant_t0 = req_mask_t0 & ~claimed;
        claimed  = claimed | grant_t0;
    end
    if (priority_t1 == 2'd0 && cmd_ready_t1 && !res_ready_t1) begin
        grant_t1 = req_mask_t1 & ~claimed;
        claimed  = claimed | grant_t1;
    end
    if (priority_t2 == 2'd0 && cmd_ready_t2 && !res_ready_t2) begin
        grant_t2 = req_mask_t2 & ~claimed;
        claimed  = claimed | grant_t2;
    end

    // --- Priority 1 ---
    if (priority_t0 == 2'd1 && cmd_ready_t0 && !res_ready_t0) begin
        grant_t0 = req_mask_t0 & ~claimed;
        claimed  = claimed | grant_t0;
    end
    if (priority_t1 == 2'd1 && cmd_ready_t1 && !res_ready_t1) begin
        grant_t1 = req_mask_t1 & ~claimed;
        claimed  = claimed | grant_t1;
    end
    if (priority_t2 == 2'd1 && cmd_ready_t2 && !res_ready_t2) begin
        grant_t2 = req_mask_t2 & ~claimed;
        claimed  = claimed | grant_t2;
    end

    // --- Priority 2 ---
    if (priority_t0 == 2'd2 && cmd_ready_t0 && !res_ready_t0) begin
        grant_t0 = req_mask_t0 & ~claimed;
        claimed  = claimed | grant_t0;
    end
    if (priority_t1 == 2'd2 && cmd_ready_t1 && !res_ready_t1) begin
        grant_t1 = req_mask_t1 & ~claimed;
        claimed  = claimed | grant_t1;
    end
    if (priority_t2 == 2'd2 && cmd_ready_t2 && !res_ready_t2) begin
        grant_t2 = req_mask_t2 & ~claimed;
        claimed  = claimed | grant_t2;
    end
end

//identify if a thread made a request but was not given a reply/hasn't read it yet
wire unsatisfied_t0 = (cmd_ready_t0 && !res_ready_t0 && grant_t0 == 7'b0);
wire unsatisfied_t1 = (cmd_ready_t1 && !res_ready_t1 && grant_t1 == 7'b0);
wire unsatisfied_t2 = (cmd_ready_t2 && !res_ready_t2 && grant_t2 == 7'b0);

//ageing unsatisfied priorities at the clock edge
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        priority_t0  <= 2'd0;
        priority_t1  <= 2'd1;
        priority_t2  <= 2'd2;
        res_ready_t0 <= 1'b0;
        res_ready_t1 <= 1'b0;
        res_ready_t2 <= 1'b0;
        locked_t0    <= 7'b0;
        locked_t1    <= 7'b0;
        locked_t2    <= 7'b0;
    end else begin

        if (unsatisfied_t0 && priority_t0 > 2'd0) begin
            priority_t0 <= priority_t0 - 1'b1; 
        end
        
        if (grant_t0 != 7'b0) begin
            res_ready_t0 <= 1'b1;
            locked_t0    <= grant_t0; // Lock the granted unit
        end else if (!cmd_ready_t0) begin
            res_ready_t0 <= 1'b0;
            locked_t0    <= 7'b0;     // Release the unit
        end
        // --- Thread 1 ---
        if (unsatisfied_t1 && priority_t1 > 2'd0) begin
            priority_t1 <= priority_t1 - 1'b1;
        end

        if (grant_t1 != 7'b0) begin
            res_ready_t1 <= 1'b1;
            locked_t1    <= grant_t1;
        end else if (!cmd_ready_t1) begin
            res_ready_t1 <= 1'b0;
            locked_t1    <= 7'b0;
        end

        // --- Thread 2 ---
        if (unsatisfied_t2 && priority_t2 > 2'd0) begin
            priority_t2 <= priority_t2 - 1'b1;
        end

        if (grant_t2 != 7'b0) begin
            res_ready_t2 <= 1'b1;
            locked_t2    <= grant_t2;
        end else if (!cmd_ready_t2) begin
            res_ready_t2 <= 1'b0;
            locked_t2    <= 7'b0;
        end
    end
end

endmodule