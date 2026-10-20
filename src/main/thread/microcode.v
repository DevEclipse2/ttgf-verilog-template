module microcode #(
    parameter [3:0] PAD_NIBBLE = 4'hF // Nibble value representing 'x' (padding)
)(
    input clk,
    input rst_n,

    //thread 0 handler
        input [7:0] macro_op_t0,
        //from 1  to 31 , each micro op corresponds to 2 byte chunked reads
        //from 32 to 112, each micro op corresponds to 4 byte chunked reads
        //from 113 to 191, each micro op corresponds to 8 byte chunked reads
        // uses an 1024 offset for parameters
        // 32 x 2 + 80 x 4 + 80 x 8 = 1024
        //anything beyond 191 is ILLEGAL and should never be seen
        input [6:0] microcode_action_offset_t0, //up to 128 but since its 4 trit to convert to this it's more like 81
        input [6:0] microcode_param_offset_t0,
        //chunked reads mean that you start from indexes 0 , 4 , 8 , 12, etc, but the offsets can allow it to read any position
        //the params are chunked separately, on the same chip but with an offset
        input next_microop,//this one turns on -> off , send new ; off -> on , send new 
        input flush,//this forces the microcode handler to pause, flush cache and read from action position & param position, as well as macro op position
        output data_ready,
        //resulting stuff
        output [3:0] action_t0,
        output [3:0] param0_t0,
        output [3:0] param1_t0,
        output [3:0] param2_t0,

        //this shows the resulting positions of the main in case the thread manager needs it for anything 
        output reg [6:0] microcode_action_offset_t0_res, 
        output reg [6:0] microcode_param_offset_t0_res,

    // ================= THREAD 1 INTERFACE =================
        input  wire [7:0]  macro_op_t1,
        input  wire [6:0]  microcode_action_offset_t1,
        input  wire [6:0]  microcode_param_offset_t1,
        input  wire        next_microop_t1,
        input  wire        flush_t1,
        output reg         data_ready_t1,
        output reg  [3:0]  action_t1,
        output reg  [3:0]  param0_t1,
        output reg  [3:0]  param1_t1,
        output reg  [3:0]  param2_t1,
        output reg  [6:0]  microcode_action_offset_t1_res,
        output reg  [6:0]  microcode_param_offset_t1_res,

    // ================= THREAD 2 INTERFACE =================
        input  wire [7:0]  macro_op_t2,
        input  wire [6:0]  microcode_action_offset_t2,
        input  wire [6:0]  microcode_param_offset_t2,
        input  wire        next_microop_t2,
        input  wire        flush_t2,
        output reg         data_ready_t2,
        output reg  [3:0]  action_t2,
        output reg  [3:0]  param0_t2,
        output reg  [3:0]  param1_t2,
        output reg  [3:0]  param2_t2,
        output reg  [6:0]  microcode_action_offset_t2_res,
        output reg  [6:0]  microcode_param_offset_t2_res,

    // ================= MAIN SRAM BUS =================
    // main bus
        input   [7:0] bus,
        output  [11:0] address,
        output  cycle_threads,
        output  microcode_idle,
);
    
    reg request_data_t0;

    //the parameter offset 
    // address calc
    //    0  to 31  (32 ops): 2-byte chunks -> Base = op * 2
    //    32 to 111 (80 ops): 4-byte chunks -> Base = 64  + (op - 32) * 4
    //    112 to 191(80 ops): 8-byte chunks -> Base = 384 + (op - 112) * 8
    function [9:0] calc_sector_base(input [7:0] macro_op);
        reg [7:0] rel_op;
        begin
            if (macro_op <= 8'd31) begin
                calc_sector_base = {4'b0000, macro_op[4:0], 1'b0};
            end else if (macro_op <= 8'd111) begin
                rel_op = macro_op - 8'd32;
                calc_sector_base = 10'd64 + ({2'b00, rel_op} << 2);
            end else if (macro_op <= 8'd191) begin
                rel_op = macro_op - 8'd112;
                calc_sector_base = 10'd384 + ({2'b00, rel_op} << 3);
            end else begin
                calc_sector_base = 10'd0; // Illegal fallback
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 2. Per-Thread Request Tracking, Importance Counters & Cached Pair State
    // -------------------------------------------------------------------------
    reg        next_d       [0:2];
    reg        request_data [0:2];
    reg [7:0]  importance   [0:2];

    // Each action byte holds 2 micro-ops (even op = upper nibble, odd op = lower nibble).
    // When the even micro-op is fetched, we cache the odd micro-op and its pre-aligned
    // parameters so the second micro-op in the pair can be served or pre-buffered.

    //uses verilog arrays to hold 3 threads
    reg        has_cached_odd [0:2];
    reg [3:0]  cached_act_odd [0:2];
    reg [3:0]  cached_p0_odd  [0:2];
    reg [3:0]  cached_p1_odd  [0:2];
    reg [3:0]  cached_p2_odd  [0:2];
    reg [6:0]  cached_act_off [0:2];
    reg [6:0]  cached_prm_off [0:2];

    wire [2:0] next_edge = {
        (next_microop_t2 ^ next_d[2]),
        (next_microop_t1 ^ next_d[1]),
        (next_microop_t0 ^ next_d[0])
    };
    wire [2:0] flush_vec = {flush_t2, flush_t1, flush_t0};

    assign microcode_idle = !(request_data[0] | request_data[1] | request_data[2]) && (state == ST_IDLE);

    // -------------------------------------------------------------------------
    // 3. Priority Arbiter (Selects waiting thread with highest importance)
    // -------------------------------------------------------------------------
    reg [1:0] winning_thread;
    reg       any_request;

    always @(*) begin
        any_request    = request_data[0] | request_data[1] | request_data[2];
        winning_thread = 2'd0;

        if (request_data[0] &&
           (!request_data[1] || importance[0] >= importance[1]) &&
           (!request_data[2] || importance[0] >= importance[2])) begin
            winning_thread = 2'd0;
        end else if (request_data[1] &&
                    (!request_data[2] || importance[1] >= importance[2])) begin
            winning_thread = 2'd1;
        end else if (request_data[2]) begin
            winning_thread = 2'd2;
        end
    end
        //here it assigns the importance, which ticks by 1 each clock cycle where request_data_t0 is up and also the request is NOT fulfilled
        //data may also not come in the same clock,
        //when there are no stuff, micrcode idle pulls high
        /*
        it determines which bytes are the most important to read from sram
        first reads 1 action and 1 param byte and does a decode to see how much params it needs, 
        param pad1
        if the param byte contains padding, then this means the next instruction contains 3 params, as well as a fast first instruction
        thus the arbiter will read twice to get
        pad2 param1
        param2 param3
        after reading, it will align the params properly
        remember, when doing parameter math, x means padding, p means parameter
        2+2 = 3 bytes p p | x p | p x
        2+1 = 2 bytes p p | p z | 
        1+2 = 2 bytes p x | p p |
        1+3 = 3 bytes p x | x p | p p
        3+1 = 2 bytes p p | p p |
        1+1 = 1 byte  p p |
        when executing these instructions, it also tells the alu to tick the action rom counter as well as the param counter by the precalculated amount
        the local buffer can store up to 64 bytes internally
        */

    // -------------------------------------------------------------------------
    // 4. Memory Interfacer FSM States & Working Registers
    // -------------------------------------------------------------------------
    localparam [2:0]
        ST_IDLE       = 3'd0,
        ST_WAIT_ACT   = 3'd1, // Drive Param0 addr, latch Action byte
        ST_WAIT_PRM0  = 3'd2, // Decode Action + Param0 byte; request Param1 if needed
        ST_WAIT_PRM1  = 3'd3, // Latch Param1 byte; request Param2 if 3-byte pattern
        ST_WAIT_PRM2  = 3'd4, // Latch Param2 byte
        ST_COMMIT     = 3'd5; // Output aligned actions/params & update offsets

    reg [2:0]  state;
    reg [1:0]  active_t;
    reg [9:0]  active_base;
    reg [6:0]  cur_act_off;
    reg [6:0]  cur_prm_off;

    reg [7:0]  latched_act_byte;
    reg [7:0]  latched_prm0;
    reg [7:0]  latched_prm1;
    reg [7:0]  latched_prm2;
    reg [1:0]  extra_reads_needed;

    // Multiplexed inputs for the currently active thread
    wire [7:0] sel_macro_op = (winning_thread == 2'd0) ? macro_op_t0 :
                              (winning_thread == 2'd1) ? macro_op_t1 : macro_op_t2;
    wire [6:0] sel_act_off  = (winning_thread == 2'd0) ? microcode_action_offset_t0_res :
                              (winning_thread == 2'd1) ? microcode_action_offset_t1_res :
                                                         microcode_action_offset_t2_res;
    wire [6:0] sel_prm_off  = (winning_thread == 2'd0) ? microcode_param_offset_t0_res :
                              (winning_thread == 2'd1) ? microcode_param_offset_t1_res :
                                                         microcode_param_offset_t2_res;

    integer i;
    
    // -------------------------------------------------------------------------
    // 5. Main Sequential Logic (Note: active-low reset !rst_n fixed from template)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                          <= ST_IDLE;
            active_t                       <= 2'd0;
            active_base                    <= 10'd0;
            cur_act_off                    <= 7'd0;
            cur_prm_off                    <= 7'd0;
            address                        <= 12'd0;
            cycle_threads                  <= 1'b0;
            latched_act_byte               <= 8'd0;
            latched_prm0                   <= 8'd0;
            latched_prm1                   <= 8'd0;  
            latched_prm2                   <= 8'd0;
            extra_reads_needed             <= 2'd0;

            data_ready_t0                  <= 1'b0;
            data_ready_t1                  <= 1'b0;
            data_ready_t2                  <= 1'b0;
            action_t0  <= 4'd0; param0_t0 <= 4'd0; param1_t0 <= 4'd0; param2_t0 <= 4'd0;
            action_t1  <= 4'd0; param0_t1 <= 4'd0; param1_t1 <= 4'd0; param2_t1 <= 4'd0;
            action_t2  <= 4'd0; param0_t2 <= 4'd0; param1_t2 <= 4'd0; param2_t2 <= 4'd0;

            microcode_action_offset_t0_res <= 7'd0;
            microcode_param_offset_t0_res  <= 7'd0;
            microcode_action_offset_t1_res <= 7'd0;
            microcode_param_offset_t1_res  <= 7'd0;
            microcode_action_offset_t2_res <= 7'd0;
            microcode_param_offset_t2_res  <= 7'd0;

            for (i = 0; i < 3; i = i + 1) begin
                next_d[i]         <= 1'b0;
                request_data[i]   <= 1'b0;
                importance[i]     <= 8'd0;
                has_cached_odd[i] <= 1'b0;
                cached_act_odd[i] <= 4'd0;
                cached_p0_odd[i]  <= 4'd0;
                cached_p1_odd[i]  <= 4'd0;
                cached_p2_odd[i]  <= 4'd0;
                cached_act_off[i] <= 7'd0;
                cached_prm_off[i] <= 7'd0;
            end
        end else begin
            
            cycle_threads <= 1'b0;

            // Sample edge-detection flip-flops
            next_d[0] <= next_microop_t0;
            next_d[1] <= next_microop_t1;
            next_d[2] <= next_microop_t2;

            // -----------------------------------------------------------------
            // Per-Thread Flush & Request / Importance Management
            // -----------------------------------------------------------------
            if (flush_t0) begin
                microcode_action_offset_t0_res  <= microcode_action_offset_t0;
                microcode_param_offset_t0_res   <= microcode_param_offset_t0;
                has_cached_odd[0]               <= 1'b0;
                request_data[0]                 <= 1'b1;
                importance[0]                   <= 8'd1;
            end else if (next_edge[0]) begin
                data_ready_t0                   <= 1'b0;
                request_data[0]                 <= 1'b1;
            end

            if (flush_t1) begin
                microcode_action_offset_t1_res  <= microcode_action_offset_t1;
                microcode_param_offset_t1_res   <= microcode_param_offset_t1;
                has_cached_odd[1]               <= 1'b0;
                request_data[1]                 <= 1'b1;
                importance[1]                   <= 8'd1;
            end else if (next_edge[1]) begin
                data_ready_t1                   <= 1'b0;
                request_data[1]                 <= 1'b1;
            end

            if (flush_t2) begin
                microcode_action_offset_t2_res <= microcode_action_offset_t2;
                microcode_param_offset_t2_res  <= microcode_param_offset_t2;
                has_cached_odd[2]              <= 1'b0;
                request_data[2]                <= 1'b1;
                importance[2]                  <= 8'd1;
            end else if (next_edge[2]) begin
                data_ready_t2                  <= 1'b0;
                request_data[2]                <= 1'b1;
            end

            // Increment importance for every waiting thread (saturating at 255)
            for (i = 0; i < 3; i = i + 1) begin
                if (request_data[i] && !(state == ST_COMMIT && active_t == i[1:0])) begin
                    if (importance[i] != 8'hFF)
                        importance[i] <= importance[i] + 8'd1;
                end
            end

            // -----------------------------------------------------------------
            // Memory Interfacer & Parameter Alignment State Machine
            // -----------------------------------------------------------------
            case (state)
                ST_IDLE: begin
                    if (any_request) begin
                        active_t <= winning_thread;

                        // Fast-path: if the 2nd micro-op of the byte pair is already cached
                        // and the thread wasn't just flushed, serve it immediately in 1 cycle
                        if (has_cached_odd[winning_thread] && !flush_vec[winning_thread]) begin
                            has_cached_odd[winning_thread]  <= 1'b0;
                            request_data[winning_thread]    <= 1'b0;
                            importance[winning_thread]      <= 8'd0;
                            cycle_threads                   <= 1'b1;

                            case (winning_thread)
                                2'd0: begin
                                    action_t0 <= cached_act_odd[0];
                                    param0_t0 <= cached_p0_odd[0];
                                    param1_t0 <= cached_p1_odd[0];
                                    param2_t0 <= cached_p2_odd[0];
                                    microcode_action_offset_t0_res <= cached_act_off[0];
                                    microcode_param_offset_t0_res  <= cached_prm_off[0];
                                    data_ready_t0 <= 1'b1;
                                end
                                2'd1: begin
                                    action_t1 <= cached_act_odd[1];
                                    param0_t1 <= cached_p0_odd[1];
                                    param1_t1 <= cached_p1_odd[1];
                                    param2_t1 <= cached_p2_odd[1];
                                    microcode_action_offset_t1_res <= cached_act_off[1];
                                    microcode_param_offset_t1_res  <= cached_prm_off[1];
                                    data_ready_t1 <= 1'b1;
                                end
                                2'd2: begin
                                    action_t2 <= cached_act_odd[2];
                                    param0_t2 <= cached_p0_odd[2];
                                    param1_t2 <= cached_p1_odd[2];
                                    param2_t2 <= cached_p2_odd[2];
                                    microcode_action_offset_t2_res <= cached_act_off[2];
                                    microcode_param_offset_t2_res  <= cached_prm_off[2];
                                    data_ready_t2 <= 1'b1;
                                end
                            endcase
                        end else begin
                            // Issue Action Byte Read from SRAM (Offset < 1024)
                            active_base <= calc_sector_base(sel_macro_op);
                            cur_act_off <= flush_vec[winning_thread] ?
                                           ((winning_thread == 2'd0) ? microcode_action_offset_t0 :
                                            (winning_thread == 2'd1) ? microcode_action_offset_t1 :
                                                                       microcode_action_offset_t2) : sel_act_off;
                            cur_prm_off <= flush_vec[winning_thread] ?
                                           ((winning_thread == 2'd0) ? microcode_param_offset_t0 :
                                            (winning_thread == 2'd1) ? microcode_param_offset_t1 :
                                                                       microcode_param_offset_t2) : sel_prm_off;

                            address <= {2'b00, calc_sector_base(sel_macro_op)} +
                                       {5'b00000, sel_act_off};
                            state   <= ST_WAIT_ACT;
                        end
                    end
                end

                // Cycle 1: Latch Action Byte, Drive First Parameter Byte Address (+1024 offset)
                ST_WAIT_ACT: begin
                    if (flush_vec[active_t]) begin
                        state <= ST_IDLE; // Abort and restart if active thread flushed mid-read
                    end else begin
                        latched_act_byte               <= bus;
                        address                        <= 12'd1024 + {2'b00, active_base} + {5'b00000, cur_prm_off};
                        state                          <= ST_WAIT_PRM0;
                    end
                end

                // Cycle 2: Latch First Param Byte (p_byte0) & Inspect Padding Nibbles
                //   If lower nibble == PAD_NIBBLE ('p x'), the first instruction has 1 param,
                //   and the second instruction has 2 or 3 params starting in the next byte(s).
                ST_WAIT_PRM0: begin
                    if (flush_vec[active_t]) begin
                        state <= ST_IDLE;
                    end else begin
                        latched_prm0 <= bus;
                        // Determine additional parameter bytes required for the 2-op pair:
                        // If p_byte0 is [p | x], we must fetch at least p_byte1 (to see if it's [p p] or [x p]).
                        // If p_byte0 is [p | p], we also fetch p_byte1 for the remaining parameters of the pair.
                        address <= 12'd1024 + {2'b00, active_base} + {5'b00000, cur_prm_off + 7'd1};
                        state   <= ST_WAIT_PRM1;
                    end
                end

                // Cycle 3: Latch Second Param Byte (p_byte1) & Check if a 3rd Byte is Required
                //   Patterns needing a 3rd byte:
                //   - 1+3 = 3 bytes: p x | x p | p p  (latched_prm0[3:0] == PAD && bus[7:4] == PAD)
                //   - 2+2 = 3 bytes: p p | x p | p x  (latched_prm0[3:0] != PAD && bus[7:4] == PAD)
                ST_WAIT_PRM1: begin
                    if (flush_vec[active_t]) begin
                        state <= ST_IDLE;
                    end else begin
                        latched_prm1 <= bus;
                        if (bus[7:4] == PAD_NIBBLE) begin
                            // Upper nibble of byte 1 is padding ('x p') -> 3-byte parameter packet!
                            extra_reads_needed <= 2'd3;
                            address            <= 12'd1024 + {2'b00, active_base} + {5'b00000, cur_prm_off + 7'd2};
                            state              <= ST_WAIT_PRM2;
                        end else begin
                            // 2-byte parameter packet (e.g., 1+2 'p x | p p', 2+1 'p p | p x', or 3+1 'p p | p p')
                            extra_reads_needed <= 2'd2;
                            state              <= ST_COMMIT;
                        end
                    end
                end

                // Cycle 4 (Only when 3rd parameter byte is needed): Latch p_byte2
                ST_WAIT_PRM2: begin
                    if (flush_vec[active_t]) begin
                        state <= ST_IDLE;
                    end else begin
                        latched_prm2 <= bus;
                        state        <= ST_COMMIT;
                    end
                end

                // Commit Stage: Align Parameters for Op0 (immediate) and Op1 (cached) & Tick Counters
                ST_COMMIT: begin
                    request_data[active_t] <= 1'b0;
                    importance[active_t]   <= 8'd0;
                    cycle_threads          <= 1'b1;
                    has_cached_odd[active_t] <= 1'b1;
                    cached_act_odd[active_t] <= latched_act_byte[3:0];

                    // Advance Action Offset by 1 byte (since 1 byte holds 2 micro-ops)
                    cached_act_off[active_t] <= cur_act_off + 7'd1;
                    // Advance Param Offset by number of parameter bytes consumed (2 or 3)
                    cached_prm_off[active_t] <= cur_prm_off + {5'd0, extra_reads_needed};

                    // ---------------------------------------------------------
                    // Parameter Alignment Multiplexer (Matches your 6 patterns)
                    // ---------------------------------------------------------
                    if (latched_prm0[3:0] == PAD_NIBBLE) begin
                        // First op has 1 parameter ('p x | ...')
                        if (latched_prm1[7:4] == PAD_NIBBLE) begin
                            // Pattern: 1+3 = 3 bytes (p x | x p | p p)
                            // Op0 gets 1 param; Op1 gets 3 params
                            cached_p0_odd[active_t] <= latched_prm1[3:0];
                            cached_p1_odd[active_t] <= latched_prm2[7:4];
                            cached_p2_odd[active_t] <= latched_prm2[3:0];
                        end else begin
                            // Pattern: 1+2 = 2 bytes (p x | p p)
                            // Op0 gets 1 param; Op1 gets 2 params
                            cached_p0_odd[active_t] <= latched_prm1[7:4];
                            cached_p1_odd[active_t] <= latched_prm1[3:0];
                            cached_p2_odd[active_t] <= 4'd0;
                        end
                    end else begin
                        // First op starts with 'p p | ...'
                        if (latched_prm1[7:4] == PAD_NIBBLE) begin
                            // Pattern: 2+2 = 3 bytes (p p | x p | p x)
                            cached_p0_odd[active_t] <= latched_prm1[3:0];
                            cached_p1_odd[active_t] <= latched_prm2[7:4];
                            cached_p2_odd[active_t] <= 4'd0;
                        end else if (latched_prm1[3:0] == PAD_NIBBLE) begin
                            // Pattern: 2+1 = 2 bytes (p p | p x)
                            cached_p0_odd[active_t] <= latched_prm1[7:4];
                            cached_p1_odd[active_t] <= 4'd0;
                            cached_p2_odd[active_t] <= 4'd0;
                        end else begin
                            // Pattern: 3+1 = 2 bytes (p p | p p)
                            cached_p0_odd[active_t] <= latched_prm1[3:0];
                            cached_p1_odd[active_t] <= 4'd0;
                            cached_p2_odd[active_t] <= 4'd0;
                        end
                    end

                    // Drive Thread Outputs for the First Micro-Op (Op0)
                    case (active_t)
                        2'd0: begin
                            action_t0 <= latched_act_byte[7:4];
                            param0_t0 <= latched_prm0[7:4];
                            param1_t0 <= (latched_prm0[3:0] == PAD_NIBBLE) ? 4'd0 : latched_prm0[3:0];
                            param2_t0 <= (latched_prm0[3:0] != PAD_NIBBLE &&
                                          latched_prm1[7:4] != PAD_NIBBLE &&
                                          latched_prm1[3:0] != PAD_NIBBLE) ? latched_prm1[7:4] : 4'd0;
                            microcode_action_offset_t0_res <= cur_act_off;
                            microcode_param_offset_t0_res  <= cur_prm_off;
                            data_ready_t0 <= 1'b1;
                        end
                        2'd1: begin
                            action_t1 <= latched_act_byte[7:4];
                            param0_t1 <= latched_prm0[7:4];
                            param1_t1 <= (latched_prm0[3:0] == PAD_NIBBLE) ? 4'd0 : latched_prm0[3:0];
                            param2_t1 <= (latched_prm0[3:0] != PAD_NIBBLE &&
                                          latched_prm1[7:4] != PAD_NIBBLE &&
                                          latched_prm1[3:0] != PAD_NIBBLE) ? latched_prm1[7:4] : 4'd0;
                            microcode_action_offset_t1_res <= cur_act_off;
                            microcode_param_offset_t1_res  <= cur_prm_off;
                            data_ready_t1 <= 1'b1;
                        end
                        2'd2: begin
                            action_t2 <= latched_act_byte[7:4];
                            param0_t2 <= latched_prm0[7:4];
                            param1_t2 <= (latched_prm0[3:0] == PAD_NIBBLE) ? 4'd0 : latched_prm0[3:0];
                            param2_t2 <= (latched_prm0[3:0] != PAD_NIBBLE &&
                                          latched_prm1[7:4] != PAD_NIBBLE &&
                                          latched_prm1[3:0] != PAD_NIBBLE) ? latched_prm1[7:4] : 4'd0;
                            microcode_action_offset_t2_res <= cur_act_off;
                            microcode_param_offset_t2_res  <= cur_prm_off;
                            data_ready_t2 <= 1'b1;
                        end
                    endcase

                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule