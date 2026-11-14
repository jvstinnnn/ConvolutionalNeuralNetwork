`timescale 1ns / 1ps
module conv #(
        parameter int WIDTH = 16,
        parameter int IMAGE_X = 4,
        parameter int IMAGE_Y = 4,
        parameter int KERNAL = 3,
        parameter int FRAC_BITS = 14,
        parameter WEIGHT_FILE = "conv1_weight.mem",
        parameter BIAS_FILE = "conv1_bias.mem",
        parameter int OUTPUT_CHANNEL = 12,
        parameter int INPUT_CHANNEL = 1
        //parameter INPUT_FILE = ""
    )
    (
        input logic clk, reset,
        input logic valid_in,
        input logic signed [WIDTH-1:0] data_in,
        
        output logic image_ready,
        output logic signed [WIDTH-1:0] data_out,
        output logic valid_out,
        output logic done,
        output logic signed [WIDTH-1:0] image [0:IMAGE_Y-1][0:IMAGE_X-1]    
    );
        
        //Set up parameters for bringing in weights
        localparam int TAPS = KERNAL * KERNAL;
        localparam int WEIGHT_VALS = TAPS * INPUT_CHANNEL * OUTPUT_CHANNEL;
        localparam int ACC_WIDTH = 2*WIDTH + $clog2(INPUT_CHANNEL*TAPS) + 1;
        localparam logic signed [ACC_WIDTH-1:0] MAX_OUTPUT = {{(ACC_WIDTH-WIDTH){1'b0}}, 1'b0, {(WIDTH-1){1'b1}}};
        localparam logic signed [ACC_WIDTH-1:0] MIN_OUTPUT = {{(ACC_WIDTH-WIDTH){1'b1}}, 1'b1, {(WIDTH-1){1'b0}}};
        
        //Dimensions of Output map due to no padding
        localparam int NEW_X = IMAGE_X - KERNAL + 1;
        localparam int NEW_Y = IMAGE_Y - KERNAL + 1;
    
        logic [$clog2(IMAGE_X)-1:0] col;
        logic [$clog2(IMAGE_Y)-1:0] row;
        
        logic signed [WIDTH-1:0] weights [0:WEIGHT_VALS-1];
        logic signed [WIDTH-1:0] biases [0:OUTPUT_CHANNEL-1];
        
        integer out_row;
        integer out_col;
        integer out_channel;
        integer kernal_row;
        integer kernal_col;
        
        logic signed [WIDTH-1:0] current_pixel;
        logic signed [WIDTH-1:0] current_weight;
        assign current_pixel = image[out_row + kernal_row][out_col + kernal_col];
        assign current_weight = weights[out_channel * TAPS + kernal_row * KERNAL + kernal_col];
        
        logic signed [2*WIDTH-1:0] product;
        logic signed [ACC_WIDTH-1:0] extended_product;
        logic signed [ACC_WIDTH-1:0] accumulate;
        logic signed [ACC_WIDTH-1:0] extended_bias;
        logic signed [ACC_WIDTH-1:0] full_result;
        logic signed [ACC_WIDTH-1:0] scaled_result;
        
        assign product = current_pixel * current_weight;
        
        //sign extension
        assign extended_product = {{(ACC_WIDTH-2*WIDTH){product[2*WIDTH-1]}}, product};
        assign extended_bias = {{(ACC_WIDTH-WIDTH){biases[out_channel][WIDTH-1:0]}}, biases[out_channel]};
        assign full_result = accumulate + (extended_bias <<< FRAC_BITS);
        assign scaled_result = full_result >>> FRAC_BITS;
        
        typedef enum logic [1:0] {
            LOAD,
            MAC,
            RESULT,
            FINISH
        } step;
        
        step state, next_state;
        
        initial begin
            $readmemh(WEIGHT_FILE, weights);
            $readmemh(BIAS_FILE, biases);
        end
        
        //State register
        always_ff @(posedge clk) begin
            if(reset)
                state <= LOAD;
            else
                state <= next_state;
        end
        
        //Logic for switching between states
        always_comb begin
            next_state = state;
            case(state)
                LOAD: begin
                    if(valid_in && row == IMAGE_Y-1 && col == IMAGE_X - 1)
                        next_state = MAC;
                end
                MAC: begin
                    if(kernal_row == KERNAL - 1 && kernal_col == KERNAL - 1)
                        next_state = RESULT;
                end
                RESULT: begin
                    if(out_row == NEW_Y - 1 && out_col == NEW_X - 1 && out_channel == OUTPUT_CHANNEL - 1)
                        next_state = FINISH;
                    else
                        next_state = MAC;
                end
                FINISH: begin
                    next_state = LOAD;
                end
                default: next_state = LOAD;
            endcase
        end
        
        //Datapath
        always_ff @(posedge clk) begin
            if(reset) begin //instantiate everything not assigned a value yet to 0 for default values
                row <= 0;
                col <= 0;
                out_row <= 0;
                out_col <= 0;
                out_channel <= 0;
                kernal_row <= 0;
                kernal_col <= 0;
                accumulate <= 0;
                image_ready <= 0;
                data_out <= 0;
                valid_out <= 0;
                done <= 0;
            end 
            else begin
                valid_out <= 1'b0;
                done <= 1'b0;
                case(state)
                    LOAD: begin
                        if(valid_in) begin
                            image[row][col] <= data_in;
                            if(col == IMAGE_X - 1) begin
                                col <= 0;
                                if(row == IMAGE_Y-1)
                                    image_ready <= 1;
                                else
                                    row <= row + 1;
                            end
                            else begin
                                col <= col + 1;
                            end
                        end
                    end
                    
                    MAC: begin
                        accumulate <= accumulate + extended_product;
                        if(kernal_col == KERNAL - 1) begin
                            kernal_col <= 0;
                            if(kernal_row == KERNAL - 1)
                                kernal_row <= 0;
                            else
                                kernal_row <= kernal_row + 1;
                        end 
                        else begin
                            kernal_col <= kernal_col + 1;
                        end
                    end
                    
                    RESULT: begin
                        if(scaled_result > MAX_OUTPUT)
                            data_out <= {1'b0, {(WIDTH-1){1'b1}}};
                        else if(scaled_result < MIN_OUTPUT)
                            data_out <= {1'b1, {(WIDTH-1){1'b0}}};
                        else
                            data_out <= scaled_result[WIDTH-1:0];
                        
                        valid_out <= 1'b1;
                        accumulate <= 0;
                        
                        if(out_col == NEW_Y - 1) begin 
                            out_col <= 0;
                            if(out_row == NEW_X - 1) begin
                                out_row <= 0;
                                if(out_channel != OUTPUT_CHANNEL -1)
                                    out_channel <= out_channel + 1;
                            end
                            else begin
                                out_row <= out_row + 1;
                            end
                        end
                        else begin
                            out_col <= out_col + 1;
                        end
                    end
                    
                    FINISH: begin
                        done <= 1'b1;
                        image_ready <= 1'b0;
                        row <= 0;
                        col <= 0;
                        out_row <= 0;
                        out_col <= 0;
                        out_channel <= 0;
                        kernal_row <= 0;
                        kernal_col <= 0;
                        accumulate <= 0;
                    end
                endcase
            end    
        end     
endmodule
