`timescale 1ns / 1ps

module uart_rx #(
    parameter int CLK_HZ = 100_000_000,
    parameter int BAUD = 9600
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);
    localparam int BAUD_DIV = CLK_HZ / BAUD;
    localparam int HALF_DIV = BAUD_DIV / 2;

    typedef enum logic [1:0] {S_IDLE, S_START, S_DATA, S_STOP} state_t;
    state_t state;
    logic [31:0] baud_cnt;
    logic [2:0] bit_idx;
    logic [1:0] rx_sync;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync <= 2'b11;
        end else begin
            rx_sync <= {rx_sync[0], rx};
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= S_IDLE;
            baud_cnt <= 32'd0;
            bit_idx  <= 3'd0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    if (!rx_sync[1]) begin
                        baud_cnt <= 32'd0;
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (baud_cnt == HALF_DIV - 1) begin
                        baud_cnt <= 32'd0;
                        if (!rx_sync[1]) begin
                            bit_idx <= 3'd0;
                            state <= S_DATA;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                S_DATA: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 32'd0;
                        rx_data <= {rx_sync[1], rx_data[7:1]};
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                S_STOP: begin
                    if (baud_cnt == BAUD_DIV - 1) begin
                        baud_cnt <= 32'd0;
                        rx_valid <= rx_sync[1];
                        state <= S_IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

