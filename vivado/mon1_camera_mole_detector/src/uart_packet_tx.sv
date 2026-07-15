`timescale 1ns / 1ps

module uart_packet_tx (
    input  logic       clk,
    input  logic       reset,
    input  logic       event_valid,
    input  logic [7:0] mole_type,
    input  logic [7:0] area,
    output logic       uart_tx_o,
    output logic       busy
);
    localparam logic [7:0] HEADER = 8'hAA;

    typedef enum logic [2:0] {
        S_IDLE,
        S_SEND_HEADER,
        S_SEND_TYPE,
        S_SEND_AREA,
        S_SEND_CHECKSUM,
        S_WAIT
    } state_t;

    state_t state;
    logic [7:0] type_latched;
    logic [7:0] area_latched;
    logic [7:0] tx_data;
    logic       tx_start;
    logic       byte_busy;
    logic       byte_busy_d;

    assign busy = (state != S_IDLE);

    uart_tx U_uart_tx (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx_o),
        .busy(byte_busy)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= S_IDLE;
            tx_start     <= 1'b0;
            tx_data      <= 8'd0;
            type_latched <= 8'd0;
            area_latched <= 8'd0;
            byte_busy_d  <= 1'b0;
        end else begin
            tx_start    <= 1'b0;
            byte_busy_d <= byte_busy;

            case (state)
                S_IDLE: begin
                    if (event_valid) begin
                        type_latched <= mole_type;
                        area_latched <= area;
                        state        <= S_SEND_HEADER;
                    end
                end
                S_SEND_HEADER: begin
                    if (!byte_busy) begin
                        tx_data  <= HEADER;
                        tx_start <= 1'b1;
                        state    <= S_SEND_TYPE;
                    end
                end
                S_SEND_TYPE: begin
                    if (byte_busy_d && !byte_busy) begin
                        tx_data  <= type_latched;
                        tx_start <= 1'b1;
                        state    <= S_SEND_AREA;
                    end
                end
                S_SEND_AREA: begin
                    if (byte_busy_d && !byte_busy) begin
                        tx_data  <= area_latched;
                        tx_start <= 1'b1;
                        state    <= S_SEND_CHECKSUM;
                    end
                end
                S_SEND_CHECKSUM: begin
                    if (byte_busy_d && !byte_busy) begin
                        tx_data  <= HEADER ^ type_latched ^ area_latched;
                        tx_start <= 1'b1;
                        state    <= S_WAIT;
                    end
                end
                S_WAIT: begin
                    if (byte_busy_d && !byte_busy) begin
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

