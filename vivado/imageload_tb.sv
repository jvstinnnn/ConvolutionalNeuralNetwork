`timescale 1ns / 1ps
module imageload_tb;

    parameter int WIDTH = 16;
    parameter int IMAGE_X = 4;
    parameter int IMAGE_Y = 4;

    logic clk = 0;
    logic reset;
    logic valid_in;
    logic signed [WIDTH-1:0] data_in;
    logic image_ready;
    logic signed [WIDTH-1:0] data_out;

    // 10 ns clock period
    always #5 clk = ~clk;

    conv #(
        .WIDTH(WIDTH),
        .IMAGE_X(IMAGE_X),
        .IMAGE_Y(IMAGE_Y),
        .OUTPUT_CHANNEL(1),
        .WEIGHT_FILE("test weights.txt"),
        .BIAS_FILE("test bias.txt")
    ) dut (
        .clk(clk),
        .reset(reset),
        .valid_in(valid_in),
        .data_in(data_in),
        .image_ready(image_ready),
        .data_out(data_out)
    );

    initial begin
        reset = 1;
        valid_in = 0;
        data_in = 0;

        repeat (2) @(negedge clk);
        reset = 0;

        // Send 784 pixels
        for (int i = 0; i < IMAGE_X*IMAGE_Y; i++) begin
            @(negedge clk);
            valid_in = 1;
            data_in = i;
        end

        @(negedge clk);
        valid_in = 0;

        // Check image_ready
        if (image_ready !== 1'b1)
            $fatal(1, "ERROR: Image not fully loaded!");

        // Check every pixel
        for (int r = 0; r < IMAGE_X; r++) begin
            for (int c = 0; c < IMAGE_Y; c++) begin

                if (dut.image[r][c] !== (r*IMAGE_Y+c)) begin
                    $fatal(1,
                        "ERROR at row=%0d col=%0d: Expected=%0d Got=%0d",
                        r, c,
                        r*IMAGE_Y+c,
                        dut.image[r][c]
                    );
                end
            end
        end

        $display("PASS: All 16 pixels loaded correctly!");
        $finish;
    end
endmodule
