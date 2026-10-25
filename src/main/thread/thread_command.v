//the primary commander for the thread responsible for decoding operations 
module thread_command(
    input wire clk,
    input wire rst_n,
    inout wire VDD_1V65,

    //from the microcode parsers
        output wire [7:0] macro_op,
        output wire [7:0] action_counter,
        output wire [7:0] param_counter,
        output wire flush,
        input wire [3:0] command,
        input wire [3:0] param_0,
        input wire [3:0] param_1,
        input wire [3:0] param_2,
        output reg  command_req_new,
        input  wire command_data_sent,

        // input [6:0] microcode_action_offset_t0, //up to 128 but since its 4 trit to convert to this it's more like 81
        //input [6:0] microcode_param_offset_t0,
        //.flush(),//this forces the microcode handler to pause, flush cache and read from action position & param position, as well as macro op position
        // output wire ,
    //secondary register
        input  wire  [23:0] trit_in_from_2nd_reg,
        output wire [23:0] trit_out_to_reg,
        output r_enable,
        output w_enable,
        
        output pc_increment,
        output [3:0] t_addr, //thread address
        output sel_cmd1,


    //alu interface
        output  wire [2:0] alu_command,
        output  wire [2:0] tritwise_command,
        output  wire [2:0] tritshift_tritwise_command, //trit shifts up to 3 front and back
        output  wire cmd_ready,
        input   wire res_ready_in,
        //4 trit
        inout [3:0] t4_a_out,
        inout [3:0] t4_b_out,
        inout       t1_a_out,
        inout       t1_b_out,

        //results here
        inout [3:0] t4_in,
        inout       t1_in,
        inout [7:0] multiply_in,

    //overlord interface
        input  wire stall,
        input  wire [7:0] bus_data_in,
        input wire data_valid,
        input wire data_done,
        output wire request_set_pc,
        output wire pipe_empty,
        output wire pipe_full_rej,
        output wire request_new_cmd,

    //error
        output wire pc_overflow,
        output wire a_ctr_overflow,
        output wire p_ctr_overflow,
        output wire reg_overflow,
        output wire [3:0] offending_id
);

reg [15:0] macroop_register;
reg using_macroop_1;//remember to only flip after macro op 1 finishes

// Expose active macro-op to the microcode parser
assign macro_op = using_macroop_1 ? macroop_register[15:8] : macroop_register[7:0];
assign sel_cmd1 = using_macroop_1;

// Request a new command from Overlord whenever pipeline isn't full and not currently streaming
assign request_new_cmd = !pipe_full_rej && (op_read_state == 2'b00);


// Secondary register internal signals
wire [23:0] reg_data_from;
reg  [23:0] reg_data_to;
reg         reg_r_en;
reg         reg_w_en;
reg  [3:0]  reg_addr;
reg         override_cmd_sel_en;
reg         override_cmd_sel;
wire        reg_collision;

assign trit_out_to_reg = reg_data_to;
assign r_enable        = reg_r_en;
assign w_enable        = reg_w_en;
assign t_addr          = reg_addr;

// Thread buffer occupancy states
localparam  THREAD_EMPTY  = 2'b00, // Neither slot has a valid command
            THREAD_FULL   = 2'b01, // Both slots occupied
            THREAD_EMPTY0 = 2'b10, // Slot 0 empty, Slot 1 active
            THREAD_EMPTY1 = 2'b11; // Slot 1 empty, Slot 0 active
reg [1:0]   threadstate = threadempty;


//aliased buffers / masks
//stands for alias mask buffer
reg  [23:0] am_buff_12t;
reg  [7:0] am_buff_4t;
reg  [1:0] am_buff_1t;
reg [3:0] alias_addr_12t; // the 0000 state is to mark it to be used as a mask
reg [2:0] alias_addr_4t;
reg [2:0] alias_addr_1t;
reg alias_active_1t; //since 1 t has a valid 0 address, one more is needed
reg alias_active_4t; //since 1 t has a valid 0 address, one more is needed


reg ret_micro;
reg [23:0] cmd_param_reg;
reg [2:0]  cmd_param_id;
reg        cmd_we;
reg [1:0]  op_read_state; // 00: idle, 01: byte 0, 10: byte 1, 11: byte 2 & write


// Microcode PC control signals
reg        p_pc_inc, p_pc_we, p_pc_re;
reg  [7:0] p_pc_wdata;
wire [7:0] p_pc_rdata;

reg        a_pc_inc, a_pc_we, a_pc_re;
reg  [7:0] a_pc_wdata;
wire [7:0] a_pc_rdata;

assign action_counter = a_pc_rdata;
assign param_counter  = p_pc_rdata;

// Native Scratchpad & Flag control signals
reg        sp0_re, sp0_we, sp0_full12t;
reg  [1:0] sp0_pos;
reg        sp1_re, sp1_we, sp1_full12t;
reg  [1:0] sp1_pos;
reg        flag_re, flag_we;
reg  [3:0] flag_pos;

// Native Tri-State / Analog Bus interconnects
wire [11:0] sp0_din_12T, sp0_dout_12T;
wire [3:0]  sp0_din_4T,  sp0_dout_4T;
wire [11:0] sp1_din_12T, sp1_dout_12T;
wire [3:0]  sp1_din_4T,  sp1_dout_4T;
wire [11:0] flag_din_12T, flag_dout_12T;
wire [3:0]  flag_din_4T,  flag_dout_4T;
wire        flag_din_1T,  flag_dout_1T;

always @(posedge clk or negedge rst_n) begin
    //this is the main loop of the system
    if(!rst_n) begin
        // Clear Alias-Mask buffers
        am_buff_12t         <= 24'd0;
        am_buff_4t          <= 8'd0;
        am_buff_1t          <= 2'd0;
        alias_addr_12t      <= 4'b0000;
        alias_addr_4t       <= 3'b000;
        alias_addr_1t       <= 3'b000;
        alias_active_1t     <= 1'b0;
        alias_active_4t     <= 1'b0;
        carry_flag_reg      <= 1'b0;

        // Clear pipeline & stream states
        macroop_register    <= 16'd0;
        using_macroop_1     <= 1'b0;
        threadstate         <= THREAD_EMPTY;
        opstate             <= OP_WAIT_CMD;
        ret_micro           <= 1'b0;
        cmd_param_reg       <= 24'd0;
        cmd_param_id        <= 3'd0;
        cmd_we              <= 1'b0;
        op_read_state       <= 2'b00;
        pipe_empty          <= 1'b1;
        pipe_full_rej       <= 1'b0;
        request_set_pc      <= 1'b0;

        // Clear register & microcode control lines
        reg_data_to         <= 24'd0;
        reg_r_en            <= 1'b0;
        reg_w_en            <= 1'b0;
        reg_addr            <= 4'd0;
        pc_increment        <= 1'b0;
        override_cmd_sel_en <= 1'b0;
        override_cmd_sel    <= 1'b0;
        flush               <= 1'b0;
        command_req_new     <= 1'b0;

        // Clear ALU & sub-module controls
        alu_command                <= 3'd0;
        tritwise_command           <= 3'd0;
        tritshift_tritwise_command <= 3'd0;
        cmd_ready                  <= 1'b0;
        p_pc_inc <= 1'b0; p_pc_we <= 1'b0; p_pc_re <= 1'b1; p_pc_wdata <= 8'd0;
        a_pc_inc <= 1'b0; a_pc_we <= 1'b0; a_pc_re <= 1'b1; a_pc_wdata <= 8'd0;
        sp0_re <= 1'b0; sp0_we <= 1'b0; sp0_full12t <= 1'b0; sp0_pos <= 2'b11;
        sp1_re <= 1'b0; sp1_we <= 1'b0; sp1_full12t <= 1'b0; sp1_pos <= 2'b11;
        flag_re <= 1'b0; flag_we <= 1'b0; flag_pos <= 4'b0000;
        offending_id <= 4'd0;
    end 
    else begin
        //start of the clock, reset single clock stuff
        reg_r_en            <= 1'b0;
        reg_w_en            <= 1'b0;
        override_cmd_sel_en <= 1'b0;
        pc_increment        <= 1'b0;
        cmd_we              <= 1'b0;
        flush               <= 1'b0;
        command_req_new     <= 1'b0;
        cmd_ready           <= 1'b0;
        p_pc_inc            <= 1'b0;
        p_pc_we             <= 1'b0;
        a_pc_inc            <= 1'b0;
        a_pc_we             <= 1'b0;
        sp0_re              <= 1'b0;
        sp0_we              <= 1'b0;
        sp1_re              <= 1'b0;
        sp1_we              <= 1'b0;
        flag_re             <= 1'b0;
        flag_we             <= 1'b0;
        /*
        load new commands, while the rest of the thread either does housekeeping or something else
        when it is valid 

        */
        if(ret_micro) begin
            // open for business
            if(pipe_full_rej) begin
                //normal, shows that it is ready for data!                
                if(!data_valid) begin //if there is no data in
                    pipe_full_rej = 1'b0;
                    opstate = op_wait_cmd;
                    //the state handles itself here
                end
                else begin 
                    if(using_macroop_1) begin
                        //thus macro op 0 shoulde be used at this moment
                        //writes into macro_op 1
                        macroop_register[15:8] <= bus_data_in;
                        threadstate = THREAD_EMPTY1;
                    end
                    else begin
                        macroop_register[7:0] <= bus_data_in;
                        threadstate = THREAD_EMPTY0;
                    end

                    op_read_state = 2'b01;
                    //if there is incoming data, then it is treated as the first incoming data
                    using_macroop_1 <= ~using_macroop_1; //non blocking to execute at the end of the cycle
                end
            end
            else begin
                //the pipe is fully empty
                //warn
                if(!data_valid) begin //if there is no data in
                    pipe_empty = 1'b1;
                    //pull pipe empty
                    threadstate = THREAD_EMPTY;
                    //the state handles itself here
                end
                else begin //if there is incoming data, then it is treated as the first incoming data
                    macroop_register[7:0] <= bus_data_in; //if fully empty then you should of course fill from command 0
                    using_macroop_1 <= 1'b0;
                    op_read_state = 2'b01;
                end
            end
            //ret micro is now 0
            
            //housekeeping section ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            //best clock for housekeeping btw
            //make sure that the aliased buffers that write into the command parameter addresses are written into the new command parameter space
            //excellent for doing carry over stuff, which is intended behaviou
            if(alias_addr_12t != 4'b0000) begin
                reg_data_to = am_buff_12t;
                reg_w_en = 1'b1; // pull this to high for a single clock
                override_cmd_sel_en = 1'b1; //1 clock
                override_cmd_sel <= ~using_macroop_1;
                

                //also check if this falls into the scratchpad registers /flag registers cause they are different
            end
            if(alias_active_4t) begin
                //4t write
            end
            if(alias_active_1t) begin
                //1t write
            end
        end


        //these are outside of returning micro because they can keep executing / reading the second commad while the device is stil ticking
        if(data_valid) begin
            if(op_read_stat > 2'b00) begin
                //
                case (op_read_state)
                    2'b01: cmd_param_reg [7:0] <= bus_data_in;  
                    2'b10: cmd_param_reg [15:8] <= bus_data_in;
                    2'b11: begin
                        op_read_state <= 2'b01;
                        cmd_param_id <= cmd_param_id + 1'b1;
                        //1 full 24 bit param is ready, push into the registers, increment cmd_param_id
                        //make sure that this happens all within a clock cycle because the bus data waits for no handshakes
                        cmd_we = 1'b1;
                    end
                endcase
                if(op_read_state != 2'b11) begin
                    op_read_state <= op_read_state + 1'b1;
                    cmd_we = 1'b0;
                end
            end
        end

        if(data_done) begin
            // on the overlord side, make sure that when data done is sent, the bus is still transmitting properly,
            // cmd_param_id is not changed from last clock, data valid is low
            
            //if the pipe was empty, you can start executing command 0
            //if it was not, pull pipe full rej
            //either way something interesting is gonna happen
            //pull cmd write enable to false
            
        end
    end
        //as long as the alu/reading microcode isnt active you should do housekeeping
        //the key part is that you don't need to be using the alu to be busy. 
        //some logical evaluations happen without the need of an alu so housekeeping shouldn't happen then too
        //the idle command is for housekeeping
        //theres a full reset command that forces all scratchpads, alias-mask and carry to clear
        //when reading from / writing to the same registers currently being written to from overlord, it prioritise overlord always
        // there arre
end

reg override_cmd_sel_en;
reg override_cmd_sel;


secondary_register secondary_register_inst (
        .clk                  (clk),
        .rst_n                (rst_n),
        .trit_out             (reg_data_from),
        .trit_in              (reg_data_to),
        .r_enable             (reg_r_en),
        .w_enable             (reg_w_en),
        .pc_increment         (pc_increment),
        .t_addr_in            (reg_addr),
        .sel_cmd1             (using_macroop_1),
        .override_cmd_sel_en  (override_cmd_sel_en),
        .override_cmd_sel     (override_cmd_sel),
        .binary_trit_in       (cmd_param_reg),
        .commandpipe_address  (cmd_param_id),
        .command_write_enable (cmd_we),
        .pc_overflow          (pc_overflow),
        .collision            (reg_collision)
    );

    ternary_pc_4t parameter_microcode_pc (
        .clk        (clk),
        .rst_n      (rst_n),
        .inc_enable (p_pc_inc),
        .w_enable   (p_pc_we),
        .r_enable   (p_pc_re),
        .w_data     (p_pc_wdata),
        .r_data     (p_pc_rdata),
        .overflow   (p_ctr_overflow)
    );

    ternary_pc_4t action_microcode_pc (
        .clk        (clk),
        .rst_n      (rst_n),
        .inc_enable (a_pc_inc),
        .w_enable   (a_pc_we),
        .r_enable   (a_pc_re),
        .w_data     (a_pc_wdata),
        .r_data     (a_pc_rdata),
        .overflow   (a_ctr_overflow) // Fixed: was connected to p_ctr_overflow
    );

    native_4t4t4t scratchpad0 (
        .VDD_1V65     (VDD_1V65),
        .r_enable     (sp0_re),
        .w_enable     (sp0_we),
        .full12t      (sp0_full12t),
        .position     (sp0_pos),
        .data_in_12T  (sp0_din_12T),
        .data_in_4T   (sp0_din_4T),
        .data_out_12T (sp0_dout_12T),
        .data_out_4T  (sp0_dout_4T)
    );

    native_4t4t4t scratchpad1 (
        .VDD_1V65     (VDD_1V65),
        .r_enable     (sp1_re),
        .w_enable     (sp1_we),
        .full12t      (sp1_full12t),
        .position     (sp1_pos),
        .data_in_12T  (sp1_din_12T),
        .data_in_4T   (sp1_din_4T),
        .data_out_12T (sp1_dout_12T),
        .data_out_4T  (sp1_dout_4T)
    );

    native_8t_flags_4t_pc flag_trits (
        .VDD_1V65     (VDD_1V65),
        .r_enable     (flag_re),
        .w_enable     (flag_we),
        .position     (flag_pos),
        .data_in_12T  (flag_din_12T),
        .data_in_4T   (flag_din_4T),
        .data_in_1T   (flag_din_1T),
        .data_out_12T (flag_dout_12T),
        .data_out_4T  (flag_dout_4T),
        .data_out_1T  (flag_dout_1T)
    );


    native_1t_storage (
    .VDD_1V65(VDD_1V65)
    
    input r_enable,
    input w_enable,
    inout data_in,
    inout data_out
    );
endmodule