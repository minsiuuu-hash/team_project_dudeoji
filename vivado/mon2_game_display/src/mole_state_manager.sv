`timescale 1ns / 1ps

module mole_state_manager (
    input  logic        clk,
    input  logic        reset,
    input  logic        tick_ms,
    input  logic        game_reset,
    input  logic [ 2:0] game_state,
    input  logic        spawn_valid,
    input  logic [ 5:0] spawn_mask,
    input  logic [17:0] spawn_type_flat,
    input  logic        hit_valid,
    input  logic [ 2:0] hit_area,
    output logic [ 5:0] active_mask,
    output logic [17:0] mole_type_flat,
    output logic [ 5:0] hit_anim_mask,
    output logic        scored_hit_valid,
    output logic [ 2:0] scored_mole_type,
    output logic        green_hit
);
    localparam logic [2:0] STAGE1 = 3'd1;
    localparam logic [2:0] STAGE2 = 3'd2;
    localparam logic [2:0] STAGE3 = 3'd3;
    localparam logic [2:0] MOLE_NONE = 3'd0;
    localparam logic [2:0] MOLE_NORMAL = 3'd1;
    localparam logic [2:0] MOLE_RED = 3'd2;
    localparam logic [2:0] MOLE_GREEN = 3'd3;
    localparam logic [2:0] MOLE_BLUE = 3'd4;
    localparam logic [2:0] MISS_MATCH = 3'd5;

    logic [2:0] mole_type[0:5];
    logic [10:0] remain_ms[0:5];
    logic [8:0] hit_anim_ms[0:5];
    logic already_hit[0:5];
    logic [10:0] hold_ms;
    logic stage_playing;
    assign stage_playing = (game_state == STAGE1) ||
                           (game_state == STAGE2) ||
                           (game_state == STAGE3);


    always_comb begin
        case (game_state)
            STAGE1:  hold_ms = 11'd1200;
            STAGE2:  hold_ms = 11'd800;
            default: hold_ms = 11'd700;
        endcase

        active_mask = 6'd0;
        hit_anim_mask = 6'd0;
        mole_type_flat = 18'd0;
        for (int i = 0; i < 6; i++) begin
            active_mask[i] = (mole_type[i] != MOLE_NONE);
            hit_anim_mask[i] = (hit_anim_ms[i] != 0);
            mole_type_flat[i*3+:3] = mole_type[i];
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            scored_hit_valid <= 1'b0;
            scored_mole_type <= MOLE_NONE;
            green_hit <= 1'b0;
            for (int i = 0; i < 6; i++) begin
                mole_type[i]   <= MOLE_NONE;
                remain_ms[i]   <= 11'd0;
                hit_anim_ms[i] <= 9'd0;
                already_hit[i] <= 1'b0;
            end
        end else begin
            scored_hit_valid <= 1'b0;
            scored_mole_type <= MOLE_NONE;
            green_hit <= 1'b0;

            if (game_reset) begin
                for (int i = 0; i < 6; i++) begin
                    mole_type[i]   <= MOLE_NONE;
                    remain_ms[i]   <= 11'd0;
                    hit_anim_ms[i] <= 9'd0;
                    already_hit[i] <= 1'b0;
                end
            end else begin
                if (tick_ms) begin
                    for (int i = 0; i < 6; i++) begin
                        if (remain_ms[i] != 0) begin
                            remain_ms[i] <= remain_ms[i] - 1'b1;
                            if (remain_ms[i] == 11'd1) begin
                                mole_type[i]   <= MOLE_NONE;
                                already_hit[i] <= 1'b0;
                            end
                        end
                        if (hit_anim_ms[i] != 0) begin
                            hit_anim_ms[i] <= hit_anim_ms[i] - 1'b1;
                        end
                    end
                end

                if (spawn_valid) begin
                    for (int i = 0; i < 6; i++) begin
                        mole_type[i]   <= MOLE_NONE;
                        remain_ms[i]   <= 11'd0;
                        already_hit[i] <= 1'b0;
                    end

                    for (int i = 0; i < 6; i++) begin
                        if (spawn_mask[i] &&
                            (spawn_type_flat[i*3 +: 3] != MOLE_NONE)) begin
                            mole_type[i]   <= spawn_type_flat[i*3+:3];
                            remain_ms[i]   <= hold_ms;
                            already_hit[i] <= 1'b0;
                        end
                    end
                end

                if (hit_valid && stage_playing) begin
                    if (active_mask[hit_area] && !already_hit[hit_area]) begin
                        scored_hit_valid <= 1'b1;
                        scored_mole_type <= mole_type[hit_area];
                        green_hit <= (mole_type[hit_area] == MOLE_GREEN);
                        already_hit[hit_area] <= 1'b1;
                        mole_type[hit_area] <= MOLE_NONE;
                        remain_ms[hit_area] <= 11'd0;
                        hit_anim_ms[hit_area] <= 9'd250;
                    end else begin
                        scored_hit_valid <= 1'b1;
                        scored_mole_type <= MISS_MATCH;
                    end
                end
            end
        end
    end
endmodule
