`timescale 1ns / 1ps

module uart_tx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD = 9600
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       busy
);
    localparam int BAUD_DIV = CLK_HZ / BAUD;

    logic [31:0] baud_cnt;
    logic [3:0]  bit_idx;
    logic [9:0]  shifter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tx       <= 1'b1;
            busy     <= 1'b0;
            baud_cnt <= 32'd0;
            bit_idx  <= 4'd0;
            shifter  <= 10'h3FF;
        end else begin
            if (!busy) begin
                tx <= 1'b1;
                if (tx_start) begin
                    busy     <= 1'b1;
                    baud_cnt <= 32'd0;
                    bit_idx  <= 4'd0;
                    shifter  <= {1'b1, tx_data, 1'b0};
                    tx       <= 1'b0;
                end
            end else if (baud_cnt == BAUD_DIV - 1) begin
                baud_cnt <= 32'd0;
                shifter  <= {1'b1, shifter[9:1]};
                bit_idx  <= bit_idx + 1'b1;
                tx       <= shifter[1];
                if (bit_idx == 4'd9) begin
                    busy <= 1'b0;
                    tx   <= 1'b1;
                end
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end
endmodule

