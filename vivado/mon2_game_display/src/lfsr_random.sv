`timescale 1ns / 1ps

module lfsr_random (
    input  logic       clk,
    input  logic       reset,
    output logic [15:0] random
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            random <= 16'hACE1;
        end else begin
            random <= {random[14:0], random[15] ^ random[13] ^ random[12] ^ random[10]};
        end
    end
endmodule

