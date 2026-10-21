`timescale 1ns / 1ps

module ternary_to_unsigned_binary_logic_convert_4t (
    // 8 wires total: [7:6] for Trit 3 (MSB), down to [1:0] for Trit 0 (LSB)
    input  wire [7:0] in_trits,
    
    // 7-bit unsigned binary output (Range: 0 to 80)
    output wire [6:0] out_bin
);

    // --- Unbalanced Base-3 Mapping ---
    // Converts balanced dual-wire encoding directly into an unsigned +40 offset space:
    // 01 (-1)       -> 2'd0
    // 00 (0) or 11  -> 2'd1  (Safely defaults illegal 11 states to 0 weight)
    // 10 (+1)       -> 2'd2
    
    wire [1:0] u3 = (in_trits[7:6] == 2'b10) ? 2'd2 : ((in_trits[7:6] == 2'b01) ? 2'd0 : 2'd1);
    wire [1:0] u2 = (in_trits[5:4] == 2'b10) ? 2'd2 : ((in_trits[5:4] == 2'b01) ? 2'd0 : 2'd1);
    wire [1:0] u1 = (in_trits[3:2] == 2'b10) ? 2'd2 : ((in_trits[3:2] == 2'b01) ? 2'd0 : 2'd1);
    wire [1:0] u0 = (in_trits[1:0] == 2'b10) ? 2'd2 : ((in_trits[1:0] == 2'b01) ? 2'd0 : 2'd1);

    // --- Final Unsigned Adder Tree ---
    // Weights: 3^3=27, 3^2=9, 3^1=3, 3^0=1
    // Max possible sum: (2 * 27) + (2 * 9) + (2 * 3) + 2 = 54 + 18 + 6 + 2 = 80
    assign out_bin = (u3 * 7'd27) + (u2 * 7'd9) + (u1 * 7'd3) + u0;

endmodule