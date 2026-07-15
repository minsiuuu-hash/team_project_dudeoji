`timescale 1ns / 1ps

module stage_timer (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_ms,
    input  logic       stage_active,
    input  logic       stage_load,
    output logic       stage_done,
    output logic [5:0] time_left
);
    localparam int STAGE_MS = 15_000;
    logic [13:0] ms_elapsed;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ms_elapsed <= 14'd0;
            stage_done <= 1'b0;
            time_left  <= 6'd15;
        end else begin
            stage_done <= 1'b0;
            if (stage_load || !stage_active) begin
                ms_elapsed <= 14'd0;
                time_left <= 6'd15;
            end else if (tick_ms) begin
                if (ms_elapsed == STAGE_MS - 1) begin
                    ms_elapsed <= 14'd0;
                    stage_done <= 1'b1;
                    time_left <= 6'd0;
                end else begin
                    ms_elapsed <= ms_elapsed + 1'b1;
                    case (ms_elapsed)
                        14'd999:   time_left <= 6'd14;
                        14'd1999:  time_left <= 6'd13;
                        14'd2999:  time_left <= 6'd12;
                        14'd3999:  time_left <= 6'd11;
                        14'd4999:  time_left <= 6'd10;
                        14'd5999:  time_left <= 6'd9;
                        14'd6999:  time_left <= 6'd8;
                        14'd7999:  time_left <= 6'd7;
                        14'd8999:  time_left <= 6'd6;
                        14'd9999:  time_left <= 6'd5;
                        14'd10999: time_left <= 6'd4;
                        14'd11999: time_left <= 6'd3;
                        14'd12999: time_left <= 6'd2;
                        14'd13999: time_left <= 6'd1;
                        default:   time_left <= time_left;
                    endcase
                end
            end
        end
    end
endmodule

