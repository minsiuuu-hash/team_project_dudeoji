`timescale 1ns / 1ps

module tick_gen #(
    parameter int CLK_HZ = 100_000_000
) (
    input  logic clk,
    input  logic reset,
    output logic tick_ms
);
    localparam int MS_CYCLES = CLK_HZ / 1000;
    logic [31:0] count;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 32'd0;
            tick_ms <= 1'b0;
        end else begin
            tick_ms <= 1'b0;
            if (count == MS_CYCLES - 1) begin
                count <= 32'd0;
                tick_ms <= 1'b1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule

