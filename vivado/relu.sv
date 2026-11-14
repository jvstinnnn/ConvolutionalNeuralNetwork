`timescale 1ns / 1ps
module relu #(
        parameter int WIDTH = 16
    )(
        input logic signed [WIDTH-1:0] data_in,
        output logic signed [WIDTH-1:0] data_out
    );
    
        assign data_out = data_in[WIDTH-1] ? '0 : data_in; //checks signed bit for 1 to see if less than 0
    
endmodule
