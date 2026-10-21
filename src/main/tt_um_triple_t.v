module tt_um_triple_t_devEclipse2 (
    `ifdef USE_POWER_PINS
    inout VDD_3V3,  // Hidden from Yosys, used by OpenROAD
    inout VSS,
    `endif

    input  wire [7:0] ui_in,    // Dedicated inputs (Pins 0-7)
    output wire [7:0] uo_out,   // Dedicated outputs (Pins 16-23)
    input  wire [7:0] uio_in,   // IOs: Input path (Pins 8-15)
    output wire [7:0] uio_out,  // IOs: Output path (Pins 8-15)
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 1=drive, 0=high-Z)
    inout  wire [7:0] ua,
    input  wire       ena,      // Always 1 when powered
    input  wire       clk,      // Clock 
    input  wire       rst_n     // Reset (Active low)
);

    wire [2:0] mux_sel     = ui_in[7:5];
    wire [7:0] forwarded_ui = ui_in[7:0]; //fully forwarded

    // Output busses from the 4 distinct sub-modules
    wire [7:0] uo_000,  uo_001,  uo_111,  uo_def;
    wire [7:0] uio_out_000, uio_out_001, uio_out_111, uio_out_def;
    wire [7:0] uio_oe_000,  uio_oe_001,  uio_oe_111,  uio_oe_def;

    logic_container main_module(

        VDD_1V65(ua[0]),
        .ui_in(ui_in),    // Dedicated inputs (Pins 0-7)
        .uo_out(uo_def),   // Dedicated outputs (Pins 16-23)
        .uio_in(uio_in),   // IOs: Input path (Pins 8-15)
        .uio_out(uio_out_def),  // IOs: Output path (Pins 8-15)
        .uio_oe(uio_oe_def),   // IOs: Enable path (active high: 1=drive, 0=high-Z)
        .clk(clk),
        .rst_n(rst_n),
    );

    logic_tester testbench(

        VDD_1V65(ua[0]),
        .ui_in(ui_in),    // Dedicated inputs (Pins 0-7)
        .uo_out(uo_000),   // Dedicated outputs (Pins 16-23)
        .uio_in(uio_in),   // IOs: Input path (Pins 8-15)
        .uio_out(uio_out_000),  // IOs: Output path (Pins 8-15)
        .uio_oe(uio_oe_000),   // IOs: Enable path (active high: 1=drive, 0=high-Z)
        .clk(clk),
        .rst_n(rst_n),
    );

    tt_um_core_commander commander_inst (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .ui_in                  (ui_in), 
        
        // Output routing
        .uo_out                 (commander_uo_out),
        .tracker                (commander_tracker),
        
        // Inputs from Core
        .b2t_translation_err    (b2t_translation_err),
        .microcode_miss         (microcode_miss),
        .single_execute_ack     (single_execute_ack),
        
        // Internal Controller Outputs
        .o_microcode_fence      (o_microcode_fence),
        .o_direct_instruction   (o_direct_instruction),
        .show_tracker           (show_tracker),
        .register_read_stage    (register_read_stage),
        .register_read_id       (register_read_id),
        .is_read                (is_read),
        .single_execute         (single_execute),
        .soft_reset             (soft_reset),
        .thread_select          (thread_select)
    );
    
    //multiplexer
    reg [7:0] uo_out_reg;
    reg [7:0] uio_out_reg;
    reg [7:0] uio_oe_reg;

    always @(*) begin
        case (mux_sel)
            3'b000: begin
                uo_out_reg  = uo_000;
                uio_out_reg = uio_out_000;
                uio_oe_reg  = uio_oe_000;
            end
            3'b001: begin
                uo_out_reg  = uo_001;
                uio_out_reg = uio_out_def;
                uio_oe_reg  = uio_oe_def;
            end
            3'b111: begin
                uo_out_reg  = uo_111;
                uio_out_reg = uio_out_111;
                uio_oe_reg  = uio_oe_111;
            end
            default: begin // Covers 010, 011, 100, 101, 110
                uo_out_reg  = uo_def;
                uio_out_reg = uio_out_def;
                uio_oe_reg  = uio_oe_def;
            end
        endcase
    end

    assign uo_out  = uo_out_reg;
    assign uio_out = uio_out_reg;
    assign uio_oe  = uio_oe_reg;

    // Tie off unused signals to prevent synthesis warnings
    wire _unused = &{ena, 1'b0};
endmodule