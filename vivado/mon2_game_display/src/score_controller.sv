`timescale 1ns / 1ps

module score_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic       game_reset,
    input  logic       hit_valid,
    input  logic [2:0] hit_type,
    output logic [7:0] score,
    output logic       score_underflow
);
    localparam logic [2:0] MOLE_NORMAL = 3'd1;
    localparam logic [2:0] MOLE_RED = 3'd2;
    localparam logic [2:0] MOLE_GREEN = 3'd3;
    localparam logic [2:0] MOLE_BLUE = 3'd4;
    localparam logic [2:0] MISS_MATCH = 3'd5;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            score <= 8'd0;
            score_underflow <= 1'b0;
        end else begin
            score_underflow <= 1'b0;
            if (game_reset) begin
                score <= 8'd0;
            end else if (hit_valid) begin
                case (hit_type)
                    MOLE_NORMAL: begin
                        if (score != 8'd99) score <= score + 1'b1;
                    end
                    MOLE_RED: begin
                        if (score <= 8'd97) score <= score + 8'd2;
                        else score <= 8'd99;
                    end
                    MOLE_BLUE: begin
                        if (score == 8'd0) begin
                            score_underflow <= 1'b1;
                        end else begin
                            score <= score - 1'b1;
                        end
                    end

                    MISS_MATCH : begin
                        if (score == 8'd0) begin
                            score_underflow <= 1'b1;
                        end else begin
                            score <= score - 1'b1;
                        end
                        
                    end
                    default: begin
                    end

                endcase
            end
        end
    end
endmodule

