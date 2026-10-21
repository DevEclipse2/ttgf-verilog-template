module logic_tester(
    
    inout VDD_1V65,
    input clk,
    input rst_n,

    input  wire [7:0] ui_in,    // Dedicated inputs (Pins 0-7)
    output wire [7:0] uo_out,   // Dedicated outputs (Pins 16-23)
    input  wire [7:0] uio_in,   // IOs: Input path (Pins 8-15)
    output wire [7:0] uio_out,  // IOs: Output path (Pins 8-15)
    output wire [7:0] uio_oe   // IOs: Enable path (active high: 1=drive, 0=high-Z)
);

endmodule