`timescale 1ns / 1ps

module button_debounce #(
    parameter int WIDTH = 1,
    parameter int CLK_HZ = 100_000_000,
    parameter int DEBOUNCE_MS = 10
) (
    input  logic             clk,
    input  logic             reset,
    input  logic [WIDTH-1:0] raw_btn,
    output logic [WIDTH-1:0] debounced
);
    localparam int COUNT_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;
    logic [WIDTH-1:0] sync0;
    logic [WIDTH-1:0] sync1;
    logic [31:0] count [0:WIDTH-1];

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sync0 <= '0;
            sync1 <= '0;
            debounced <= '0;
            for (int i = 0; i < WIDTH; i++) begin
                count[i] <= 32'd0;
            end
        end else begin
            sync0 <= raw_btn;
            sync1 <= sync0;
            for (int i = 0; i < WIDTH; i++) begin
                if (sync1[i] == debounced[i]) begin
                    count[i] <= 32'd0;
                end else if (count[i] >= COUNT_MAX - 1) begin
                    debounced[i] <= sync1[i];
                    count[i] <= 32'd0;
                end else begin
                    count[i] <= count[i] + 1'b1;
                end
            end
        end
    end
endmodule

