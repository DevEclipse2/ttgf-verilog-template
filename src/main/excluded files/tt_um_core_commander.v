module tt_um_core_commander (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n,
    output wire [7:0] tracker,


    //from alu
    input wire b2t_translation_err,
    input wire microcode_miss,

    //internal routing and stuff below
    output wire o_microcode_fence,  //this pauses cpu execution after each micro operation
    output wire o_direct_instruction, //bypasses command buffers
    output wire show_tracker, 
    output reg  purge_microcode,
    input  wire purge_microcode_ack,
    output reg [1:0] register_read_stage,
    output reg [2:0] register_read_id,
    output reg is_read,
    output reg single_execute,
    input  wire single_execute_ack,
    output reg [1:0] thread_select //this manages shadow volumes but hush
);
    


    //overcommand opcode
    wire [3:0] cmd_opcode   = ui_in[6:3];

    //this section holds internal state governance
    reg [7:0]   error_tracker = 0;
    reg [7:0]   microcode_miss_tracker = 0;

    assign tracker = showing_errors ? error_tracker :
    showing_microcode_miss ? microcode_miss_tracker : 
    8'b00000000;
    reg microcode_fence = 1'b0; //this tracks the microcode fencing behaviour
    reg direct_instruction = 1'b0;
    reg showing_errors = 1'b0;
    reg showing_microcode_miss = 1'b0;
    assign show_tracker = showing_errors | showing_microcode_miss; // cannot be both hig 
    reg freeze_core = 1'b0;
    
    reg command_op_ack = 1'b0;
    reg bus_ready = 1'b0;
    assign uo_out [4] = command_op_ack;
    assign uo_out [7] = bus_ready;

    assign o_direct_instruction = direct_instruction;
    assign o_microcode_fence = microcode_fence;
    //internal state
    reg [2:0] controller_state      = 3'b000;

    localparam  state_idle          = 3'b000;
    localparam  state_rcv_pc        = 3'b001;    //receive new program counter FROM fpga
    localparam  state_trn_pc        = 3'b010;    // transmit pc TO fpga
    localparam  state_rcv_reg       = 3'b011;    //receive the registers TO fpga
    localparam  state_trn_reg       = 3'b100;    //transmit register data TO fpga
    localparam  state_soft_reset    = 3'b101;    //soft reset
    localparam  state_cmd_clr       = 3'b110;    //clear all command buffers
    localparam  state_cmd_trn       = 3'b111;    //transmit command buffer to fpga
    reg err_delay;
always @(posedge clk) begin
    err_delay <= b2t_translation_err;
    if (b2t_translation_err && !err_delay) begin
        error_tracker <= error_tracker + 1'b1;
    end
end

    //setting the program counter pauses alu execution, resets mirocode counter and dumps current microcode
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            //this is chip level reset. clear all data stored
            error_tracker           <= 8'b0;
            microcode_miss_tracker  <= 8'b0;
            microcode_fence         <= 1'b0;
            direct_instruction      <= 1'b0;
            showing_errors          <= 1'b0;
            showing_microcode_miss  <= 1'b0;
            freeze_core             <= 1'b0;
            purge_microcode         <= 1'b0;
        end
        else begin
            
            if(ena) begin
                if(single_execute_ack) begin
                    single_execute <= 1'b0;                
                end
                if(purge_microcode_ack) begin
                    purge_microcode <= 1'b0;
                end

                if(cmd_opcode == 4'b0000) begin
                    command_op_ack <= 1'b0;
                    //set operation ack to 0
                    //statemachine below
                    //pumps the registers
                    // if showing errors, dont do this
                    if(!showing_errors && !showing_microcode_miss) begin
                        case(controller_state)
                            state_trn_pc: begin
                                //if bus ready is high and read ack is low
                                //here it checks read ack first
                                //turns bus ready to low
                                //if read ack turns low in response, transmit data and flip bus ready to high
                                //
                                if(ui_in[7]) begin
                                    if(bus_ready) begin
                                        bus_ready <= 1'b0;
                                        register_read_stage <= register_read_stage + 1'b1;
                                        if(register_read_stage == 2'b10) begin
                                            //reset
                                            register_read_stage <= 2'b0;
                                            register_read_id    <= 3'b000;
                                            bus_ready <= 1'b0;
                                            controller_state    <= state_idle;
                                        end
                                    end
                                end
                                else begin
                                    if(bus_ready == 1'b0) begin
                                        bus_ready <= 1'b1;
                                    end
                                end
                            end
                            state_rcv_pc: begin
                                // STEP 1: FPGA asserts ui_in[7] HIGH to signal "Valid data is on uio_in"
                                if (ui_in[7]) begin
                                    
                                    // Check if we are currently holding the line READY
                                    if (bus_ready) begin
                                        
                                        // 1. Drop bus_ready to LOW to acknowledge we see the data
                                        bus_ready <= 1'b0;
                                        
                                        // 2. Capture the incoming byte from the FPGA via the IO bus
                                        // We route it to the correct byte of the 24-bit PC based on the stage
                                        // 3. Advance to the next byte chunk
                                        register_read_stage <= register_read_stage + 1'b1;
                                        
                                        // 4. If we just captured the 3rd byte (stage 2), finish the transaction
                                        if (register_read_stage == 2'b10) begin
                                            register_read_stage <= 2'b0;       // Reset chunk counter
                                            register_read_id    <= 3'b000;     // Reset ID (if used)
                                            bus_ready           <= 1'b0;       // Ensure bus remains unready
                                            controller_state    <= state_idle; // Return to idle state
                                        end
                                    end
                                end
                                
                                // STEP 2: FPGA lowers ui_in[7] to acknowledge our receipt or to prepare the next byte
                                else begin
                                    // Once the FPGA drops its signal, we raise bus_ready HIGH to say 
                                    // "I am ready for you to send the next byte"
                                    if (bus_ready == 1'b0) begin
                                        bus_ready <= 1'b1;
                                    end
                                end
                                //when the new program counter is being inserted,
                                // bus ready is set to high when its ready to read from the bus
                                // fpga sets read ack to high
                                // bus ready lows in reasponse
                                // the fpga reads this and sends data through bus as well as read ack low
                                // data gets written, everyone goes home
                                // bus ready is set to high once ready again
                            end
                            state_trn_reg: begin
                                //registers from id 1 to 6
                                //each register has 3 clocks
                                // STEP 1: FPGA asserts ui_in[7] HIGH to acknowledge it read the current byte
                                if (ui_in[7]) begin
                                    
                                    // Check if we were actively signaling that data is valid
                                    if (bus_ready) begin
                                        
                                        // 1. Drop bus_ready to LOW (transitioning to the next byte)
                                        bus_ready <= 1'b0;
                                        
                                        // 2. Handle the nested counters (3 bytes per register, 6 registers total)
                                        if (register_read_stage == 2'b10) begin
                                            
                                            // We just finished the 3rd byte (stage 2) of the current register
                                            register_read_stage <= 2'b00; 
                                            
                                            // Check if we just finished the final register (ID 6 / 3'b110)
                                            if (register_read_id == 3'b110) begin
                                                register_read_id <= 3'b000;    // Reset ID counter
                                                bus_ready        <= 1'b0;      // Keep bus unready
                                                controller_state <= state_idle;// Transaction complete, return to idle
                                            end else begin
                                                // Move to the next register
                                                register_read_id <= register_read_id + 1'b1;
                                            end
                                            
                                        end else begin
                                            // Move to the next byte of the current register
                                            register_read_stage <= register_read_stage + 1'b1;
                                        end
                                    end
                                end
                                
                                // STEP 2: FPGA lowers ui_in[7] to acknowledge our transition
                                else begin
                                    // Once the FPGA drops its acknowledge signal, we raise bus_ready HIGH 
                                    // to signal "The next byte is now valid on the uio_out bus"
                                    if (bus_ready == 1'b0) begin
                                        bus_ready <= 1'b1;
                                    end
                                end
                            end
                            state_rcv_reg: begin
                                // STEP 1: FPGA asserts ui_in[7] HIGH to signal "Valid data is on uio_in"
                                if (ui_in[7]) begin
                                    
                                    // Check if we are currently holding the line READY
                                    if (bus_ready) begin
                                        
                                        // 1. Drop bus_ready to LOW to acknowledge we see the data
                                        bus_ready <= 1'b0;
                                        
                                        // 2. Route the incoming byte to the correct register and byte offset
                                        // (Assuming you have 6 registers: reg1 to reg6, each 24 bits wide)
                                        // 3. Handle the nested counters
                                        if (register_read_stage == 2'b10) begin
                                            // We just captured the 3rd byte (stage 2) of the current register
                                            register_read_stage <= 2'b00; 
                                            
                                            // Check if we just finished the final register (ID 6 / 3'b110)
                                            if (register_read_id == 3'b110) begin
                                                register_read_id <= 3'b000;    // Reset ID counter
                                                bus_ready        <= 1'b0;      // Ensure bus remains unready
                                                controller_state <= state_idle;// Transaction complete, return to idle
                                            end else begin
                                                // Move to the next register
                                                register_read_id <= register_read_id + 1'b1;
                                            end
                                            
                                        end else begin
                                            // Move to the next byte of the current register
                                            register_read_stage <= register_read_stage + 1'b1;
                                        end
                                    end
                                end
                                
                                // STEP 2: FPGA lowers ui_in[7] to acknowledge our receipt or to prepare the next byte
                                else begin
                                    // Once the FPGA drops its signal, we raise bus_ready HIGH to say 
                                    // "I am ready for you to send the next byte"
                                    if (bus_ready == 1'b0) begin
                                        bus_ready <= 1'b1;
                                    end
                                end
                            end

                        endcase
                    end
                end
                else //if its an actual command
                if (command_op_ack == 1'b0 && controller_state == state_idle) begin
                //state governance part 1:  
                //only run this case statement when command op read ack low and statemachine idle
                case(cmd_opcode)
                    //no operation
                    4'b0001: direct_instruction <= ~direct_instruction;
                    4'b0010: begin 
                        controller_state <= state_trn_pc;
                        register_read_stage <= 2'b0;
                        bus_ready <= 1'b0;
                        register_read_id <= 3'b111;
                        is_read <= 1'b1;
                        showing_microcode_miss <= 1'b0;
                        showing_errors <= 1'b0;
                    end
                    4'b0011: begin
                        thread_select <= (thread_select == 2'b10) ? 2'b00 : (thread_select + 1'b1);
                    end
                    4'b0100: begin
                        if (microcode_fence) begin
                            if(!single_execute_ack) begin
                            single_execute <= 1'b1;
                            end
                        end
                        else begin microcode_fence <= 1'b1;
                        end
                    end//microop fence (step execute), running this again allows 1 cpu step
                    4'b0101: begin
                        controller_state <= state_rcv_pc;
                        register_read_stage <= 2'b0;
                        bus_ready <= 1'b0;
                        register_read_id <= 3'b111;
                        is_read <= 1'b0;
                        showing_microcode_miss <= 1'b0;
                        showing_errors <= 1'b0;
                    end
                    4'b0110: begin//command buffer dump
                    end
                    4'b0111: begin
                        controller_state <= state_trn_reg;
                        register_read_stage <= 2'b0;
                        bus_ready <= 1'b0;
                        register_read_id <= 3'b001;
                        is_read <= 1'b1; 
                        showing_microcode_miss <= 1'b0;
                        showing_errors <= 1'b0;
                    end
                    4'b1000: begin
                    freeze_core <= 1'b0; //unfreezes core or stops stepping
                    microcode_fence <= 1'b0;
                    end
                    4'b1001: //command buffer clear
                    4'b1010: freeze_core <= 1'b1;//freeze core
                    4'b1011: begin
                        //regset
                        controller_state <= state_rcv_reg;
                        register_read_stage <= 2'b0;
                        bus_ready <= 1'b0;
                        register_read_id <= 3'b001;
                        is_read <= 1'b0;
                        showing_microcode_miss <= 1'b0;
                        showing_errors <= 1'b0;
                    end
                    4'b1100: purge_microcode <= 1'b1;//purge microcode
                    4'b1101: begin
                        showing_microcode_miss <= 1'b0;
                        showing_errors <= ~showing_errors;
                        //show error count
                        //sets microcode miss count to off
                        //output bus
                    end
                    4'b1110: begin
                        showing_errors <= 1'b0;
                        showing_microcode_miss <= ~showing_microcode_miss;
                        //show microcode miss count
                    end
                endcase
                command_op_ack <= 1'b1;
                end
            //theres a difference between chip reset and cpu reset btw
            end
        end 
    end

endmodule