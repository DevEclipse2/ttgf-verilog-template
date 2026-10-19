
module ternary_pc_4trit (
    input  wire       clk,
    input  wire       rst_n,       // Active-low synchronous/asynchronous reset
    input  wire       inc_enable,  // High to increment PC by +1 on clock edge
    input  wire       w_enable,    // High to overwrite PC with w_data (Jump/Branch)
    input  wire       r_enable,    // High to drive PC onto r_data bus
    input  wire [7:0] w_data,      // 4-trit (8-bit) branch target input
    output wire [7:0] r_data,      // 4-trit (8-bit) gated read output
    output wire       overflow     // Pulses high when wrapping from all +1s to all -1s
);

    // Internal 8-bit register holding 4 trits
    reg  [7:0] pc_reg;
    wire [7:0] pc_inc;
    
    // Carry and Propagate wires for 4 trits
    wire [3:0] prop;
    wire [4:0] carry;

    // Base carry-in is 1 for the +1 increment operation
    assign carry[0] = 1'b1;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_trit_inc
            wire t1 = pc_reg[2*i + 1];
            wire t0 = pc_reg[2*i];

            // Trit propagates carry ONLY if it is currently +1 (2'b10)
            assign prop[i] = t1 & ~t0;

            // Prefix Carry-Lookahead: carry[i+1] is high only if ALL trits 0..i are +1
            assign carry[i+1] = &prop[i:0];

            // Next-state combinational logic with automatic 2'b11 fault sanitization
            assign pc_inc[2*i + 1] = carry[i] ? (~t1 & ~t0) : (t1 & ~t0);
            assign pc_inc[2*i]     = carry[i] ? (t1 & ~t0)  : (~t1 & t0);
        end
    endgenerate

    // Overflow flag when wrapping from +40 (all 10) to -40 (all 01)
    assign overflow = carry[4];

    // Sequential State Update 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset to 0 (4 trits of 2'b00)
            pc_reg <= 8'b0;
        end else if (w_enable) begin
            pc_reg <= w_data;
        end else if (inc_enable) begin
            pc_reg <= pc_inc;
        end
    end

    // Read Output Gating (Pull-to-0 when disabled)
    assign r_data = r_enable ? pc_reg : 8'b0;

endmodule