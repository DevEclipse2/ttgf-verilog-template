module tt_um_triple_t_devEclipse2 (
    input  wire [7:0] ui_in,    // Dedicated inputs (Pins 0-7)
    output wire [7:0] uo_out,   // Dedicated outputs (Pins 16-23)
    input  wire [7:0] uio_in,   // IOs: Input path (Pins 8-15)
    output wire [7:0] uio_out,  // IOs: Output path (Pins 8-15)
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 1=drive, 0=high-Z)
    input  wire       ena,      // Always 1 when powered
    input  wire       clk,      // Clock 
    input  wire       rst_n     // Reset (Active low)
);


    //the first 3 bits are separated and the rest are shared
    wire [2:0] addresser   = ui_in[2:0];
    wire [4:0] shared_ctrl = ui_in[7:3];
    wire [7:0] shared_data = uio_in;

    //internal wires to catch the outputs from each sub-module
    wire [7:0] mod0_uo_out, mod0_uio_out, mod0_uio_oe;
    wire [7:0] mod1_uo_out, mod1_uio_out, mod1_uio_oe;
    wire [7:0] mod2_uo_out, mod2_uio_out, mod2_uio_oe;

    // 3. Instantiate the sub-modules
    // The data is broadcast to all of them, but only the one matching the 
    // current addresser gets its `module_enable` flag pulled HIGH.
    dummy_worker sub_module_0 (
        .clk(clk), .rst_n(rst_n),
        .module_enable (addresser == 3'd0), 
        .ctrl_payload  (shared_ctrl), 
        .data_payload  (shared_data),
        .out_dedicated (mod0_uo_out), 
        .out_bus_write (mod0_uio_out), 
        .out_bus_oe    (mod0_uio_oe)
    );

    dummy_worker sub_module_1 (
        .clk(clk), .rst_n(rst_n),
        .module_enable (addresser == 3'd1), 
        .ctrl_payload  (shared_ctrl), 
        .data_payload  (shared_data),
        .out_dedicated (mod1_uo_out), 
        .out_bus_write (mod1_uio_out), 
        .out_bus_oe    (mod1_uio_oe)
    );

    dummy_worker sub_module_2 (
        .clk(clk), .rst_n(rst_n),
        .module_enable (addresser == 3'd2), 
        .ctrl_payload  (shared_ctrl), 
        .data_payload  (shared_data),
        .out_dedicated (mod2_uo_out), 
        .out_bus_write (mod2_uio_out), 
        .out_bus_oe    (mod2_uio_oe)
    );
//multiplexer
    reg [7:0] active_uo_out, active_uio_out, active_uio_oe;
    

    //this is a dummy function to be replaced later
    always @(*) begin
        case (addresser)
            3'd0: begin
                active_uo_out  = mod0_uo_out;
                active_uio_out = mod0_uio_out;
                active_uio_oe  = mod0_uio_oe;
            end
            3'd1: begin
                active_uo_out  = mod1_uo_out;
                active_uio_out = mod1_uio_out;
                active_uio_oe  = mod1_uio_oe;
            end
            3'd2: begin
                active_uo_out  = mod2_uo_out;
                active_uio_out = mod2_uio_out;
                active_uio_oe  = mod2_uio_oe;
            end
            default: begin      
                // Failsafe for unassigned addresses: output zeros, release the bus
                active_uo_out  = 8'h00;
                active_uio_out = 8'h00;
                active_uio_oe  = 8'h00; 
            end
        endcase
    end

    // Drive the physical Tiny Tapeout pins
    assign uo_out  = active_uo_out;
    assign uio_out = active_uio_out;
    assign uio_oe  = active_uio_oe;
endmodule