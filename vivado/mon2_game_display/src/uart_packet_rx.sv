`timescale 1ns / 1ps

module uart_packet_rx (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data,
    input  logic       rx_valid,
    input  logic       event_ready,
    output logic       event_valid,
    output logic [7:0] event_type,
    output logic [7:0] event_area,
    output logic       packet_error
);
    localparam logic [7:0] HEADER = 8'hAA;

    typedef enum logic [1:0] {S_HEADER, S_TYPE, S_AREA, S_CHECKSUM} state_t;
    state_t state;
    logic [7:0] type_reg;
    logic [7:0] area_reg;
    logic       pending_valid;
    logic [7:0] pending_type;
    logic [7:0] pending_area;

    assign event_valid = pending_valid;
    assign event_type  = pending_type;
    assign event_area  = pending_area;

    function automatic logic valid_type(input logic [7:0] value);
        begin
            valid_type = (value == 8'h01) || (value == 8'h02) || (value == 8'h03);
        end
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= S_HEADER;
            type_reg      <= 8'd0;
            area_reg      <= 8'd0;
            pending_valid <= 1'b0;
            pending_type  <= 8'd0;
            pending_area  <= 8'd0;
            packet_error  <= 1'b0;
        end else begin
            packet_error <= 1'b0;

            if (pending_valid && event_ready) begin
                pending_valid <= 1'b0;
            end

            if (rx_valid) begin
                if (rx_data == HEADER && state != S_HEADER) begin
                    state <= S_TYPE;
                end else begin
                    case (state)
                        S_HEADER: begin
                            if (rx_data == HEADER) begin
                                state <= S_TYPE;
                            end
                        end
                        S_TYPE: begin
                            if (valid_type(rx_data)) begin
                                type_reg <= rx_data;
                                state <= S_AREA;
                            end else begin
                                packet_error <= 1'b1;
                                state <= S_HEADER;
                            end
                        end
                        S_AREA: begin
                            if (rx_data <= 8'd5) begin
                                area_reg <= rx_data;
                                state <= S_CHECKSUM;
                            end else begin
                                packet_error <= 1'b1;
                                state <= S_HEADER;
                            end
                        end
                        S_CHECKSUM: begin
                            if (rx_data == (HEADER ^ type_reg ^ area_reg)) begin
                                if (!pending_valid) begin
                                    pending_valid <= 1'b1;
                                    pending_type  <= type_reg;
                                    pending_area  <= area_reg;
                                end
                            end else begin
                                packet_error <= 1'b1;
                            end
                            state <= S_HEADER;
                        end
                        default: state <= S_HEADER;
                    endcase
                end
            end
        end
    end
endmodule
