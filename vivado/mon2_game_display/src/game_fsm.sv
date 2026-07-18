`timescale 1ns / 1ps

module game_fsm (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_pulse,
    input  logic       restart_pulse,
    input  logic       stage_done,
    input  logic       green_hit,
    input  logic       score_underflow,
    input  logic [7:0] score,
    output logic [2:0] game_state,
    output logic       stage_active,
    output logic       stage_load,
    output logic       game_reset_pulse
);
    localparam logic [2:0] IDLE = 3'd0;
    localparam logic [2:0] STAGE1 = 3'd1;
    localparam logic [2:0] STAGE2 = 3'd2;
    localparam logic [2:0] STAGE3 = 3'd3;
    localparam logic [2:0] WIN = 3'd4;
    localparam logic [2:0] GAME_OVER = 3'd5;

    assign stage_active = (game_state == STAGE1) || (game_state == STAGE2) || (game_state == STAGE3);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            game_state <= IDLE;
            stage_load <= 1'b0;
            game_reset_pulse <= 1'b1;
        end else begin
            stage_load <= 1'b0;
            game_reset_pulse <= 1'b0;

            if ((game_state == WIN || game_state == GAME_OVER) && restart_pulse) begin
                game_state <= IDLE;
                game_reset_pulse <= 1'b1;
            end else begin
                case (game_state)
                    IDLE: begin
                        if (start_pulse) begin
                            game_state <= STAGE1;
                            stage_load <= 1'b1;
                            game_reset_pulse <= 1'b1;
                        end
                    end
                    STAGE1, STAGE2, STAGE3: begin
                        if (green_hit || score_underflow) begin
                            game_state <= GAME_OVER;
                        end else if (stage_done) begin
                            if (game_state == STAGE1) begin
                                game_state <= STAGE2;
                                stage_load <= 1'b1;
                            end else if (game_state == STAGE2) begin
                                game_state <= STAGE3;
                                stage_load <= 1'b1;
                            end else begin
                                game_state <= (score >= 8'd50) ? WIN : GAME_OVER;
                            end
                        end
                    end
                    default: begin
                        game_state <= IDLE;
                        game_reset_pulse <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule

