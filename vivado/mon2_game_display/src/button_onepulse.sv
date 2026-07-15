`timescale 1ns / 1ps

module button_onepulse #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic             reset,
    input  logic [WIDTH-1:0] btn,
    output logic [WIDTH-1:0] pulse
);
    logic [WIDTH-1:0] prev;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            prev <= '0;
            pulse <= '0;
        end else begin
            pulse <= btn & ~prev;
            prev <= btn;
        end
    end
endmodule

