`timescale 1ns / 1ps
module conv #(
        parameter int WIDTH = 16,
        
        parameter int IMAGE_X = 28,
        parameter int IMAGE_Y = 28,
        
        parameter int KERNAL = 3,
        parameter int FRAC_BITS = 14,
        parameter WEIGHT_FILE = "conv1_weight.mem",
        parameter BIAS_FILE = "conv1_bias.mem",
        
        parameter int OUTPUT_CHANNEL = 12,
        parameter int INPUT_CHANNEL = 1,
        
        parameter INPUT_FILE = ""
    )
    (
        input logic clk, reset,
        input logic valid_in,
        input logic signed [WIDTH-1:0] data_in,
        
        output logic image_ready,
        output logic signed [WIDTH-1:0] data_out,
        output logic valid_out,
        output logic done
    );
        
        //Set up parameters for bringing in weights
        localparam int TAPS = KERNAL * KERNAL;
        localparam int WEIGHT_VALS = TAPS * INPUT_CHANNEL * OUTPUT_CHANNEL;
        localparam int ACC_WIDTH = 2*WIDTH + $clog2(INPUT_CHANNEL*TAPS) + 1;
        
        //Dimensions of Output map due to no padding
        localparam int NEW_X = IMAGE_X - KERNAL + 1;
        localparam int NEW_Y = IMAGE_Y - KERNAL + 1;
    
        logic signed [WIDTH-1:0] image [0:IMAGE_Y-1][0:IMAGE_X-1];
        logic [$clog2(IMAGE_X)-1:0] col;
        logic [$clog2(IMAGE_Y)-1:0] row;
        
        logic signed [WIDTH-1:0] weights [0:WEIGHT_VALS-1];
        logic signed [WIDTH-1:0] biases [0:OUTPUT_CHANNEL-1];
        
        integer out_row;
        integer out_col;
        integer out_channel;
        
        integer kernal_row;
        integer kernal_col;
        
        initial begin
            $readmemh(WEIGHT_FILE, weights);
            $readmemh(BIAS_FILE, biases);
        end
        
        //Loads image data into a 2D Array
        always_ff @(posedge clk) begin
            if(reset) begin
                row <= 0;
                col <= 0;
                image_ready <= 0;
            end else if(valid_in && !image_ready) begin
                image[row][col] <= data_in;
                
                if(col == IMAGE_X - 1) begin
                    col <= 0;
                    if(row == IMAGE_Y-1) begin
                        image_ready <= 1;
                    end else begin
                        row <= row + 1;
                    end
                end else begin
                    col <= col + 1;
                end
            end
        end 
        
        
        
endmodule