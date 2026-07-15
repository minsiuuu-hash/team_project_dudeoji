`timescale 1ns / 1ps

module mole_spawn_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_ms,
    input  logic       game_reset,
    input  logic [2:0] game_state,
    input  logic [5:0] occupied,
    input  logic [15:0] random,
    input  logic       special_valid,
    input  logic [7:0] special_type,
    input  logic [7:0] special_area,
    output logic       special_ready,
    output logic       spawn_valid,
    output logic [5:0] spawn_mask,
    output logic [17:0] spawn_type_flat
);
    localparam logic [2:0] STAGE1 = 3'd1;
    localparam logic [2:0] STAGE2 = 3'd2;
    localparam logic [2:0] STAGE3 = 3'd3;
    localparam logic [2:0] MOLE_NONE   = 3'd0;
    localparam logic [2:0] MOLE_NORMAL = 3'd1;
    localparam logic [2:0] MOLE_RED    = 3'd2;
    localparam logic [2:0] MOLE_GREEN  = 3'd3;
    localparam logic [2:0] MOLE_BLUE   = 3'd4;

    logic [10:0] ms_count;
    logic [10:0] spawn_ms;
    logic [5:0] empty_mask;
    logic [2:0] preferred_area;
    logic       play_active;
    logic [2:0] desired_count;
    logic [2:0] chosen_count;
    logic [5:0] normal_spawn_mask;
    logic       pending_special_valid;
    logic [2:0] pending_special_type;
    logic [2:0] pending_special_area;
    logic [5:0] wave_spawn_mask;
    logic [17:0] wave_spawn_type_flat;

    assign play_active = (game_state == STAGE1) || (game_state == STAGE2) || (game_state == STAGE3);
    assign empty_mask = 6'b111111;
    assign special_ready = play_active && (special_area <= 8'd5);

    always_comb begin
        case (game_state)
            STAGE1: spawn_ms = 11'd1500;
            STAGE2: spawn_ms = 11'd1000;
            default: spawn_ms = 11'd600;
        endcase

        preferred_area = random[2:0];
        if (preferred_area >= 3'd6) begin
            preferred_area = preferred_area - 3'd6;
        end

        case (game_state)
            STAGE1: desired_count = random[3] ? 3'd2 : 3'd1;
            STAGE2: desired_count = {1'b0, random[4:3]} + 3'd1;
            default: desired_count = random[4] ? 3'd4 : ({1'b0, random[3:2]} + 3'd1);
        endcase

        chosen_count = 3'd0;
        normal_spawn_mask = 6'd0;
        for (int n = 0; n < 6; n++) begin
            int idx;
            idx = preferred_area + n;
            if (idx >= 6) begin
                idx = idx - 6;
            end

            if ((chosen_count < desired_count) &&
                empty_mask[idx] &&
                !(pending_special_valid && (idx[2:0] == pending_special_area))) begin
                normal_spawn_mask[idx] = 1'b1;
                chosen_count = chosen_count + 1'b1;
            end
        end

        wave_spawn_mask = normal_spawn_mask;
        wave_spawn_type_flat = 18'd0;
        for (int i = 0; i < 6; i++) begin
            if (normal_spawn_mask[i]) begin
                wave_spawn_type_flat[i*3 +: 3] = MOLE_NORMAL;
            end
        end

        if (pending_special_valid) begin
            wave_spawn_mask[pending_special_area] = 1'b1;
            wave_spawn_type_flat[pending_special_area*3 +: 3] = pending_special_type;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ms_count <= 11'd0;
            spawn_valid <= 1'b0;
            spawn_mask <= 6'd0;
            spawn_type_flat <= 18'd0;
            pending_special_valid <= 1'b0;
            pending_special_type <= MOLE_NONE;
            pending_special_area <= 3'd0;
        end else begin
            spawn_valid <= 1'b0;
            spawn_mask <= 6'd0;
            spawn_type_flat <= 18'd0;
            if (game_reset || !play_active) begin
                ms_count <= 11'd0;
                pending_special_valid <= 1'b0;
            end else begin
                if (special_valid && special_area <= 8'd5 && !pending_special_valid) begin
                    pending_special_valid <= 1'b1;
                    pending_special_area <= special_area[2:0];
                    case (special_type)
                        8'h01: pending_special_type <= MOLE_RED;
                        8'h02: pending_special_type <= MOLE_GREEN;
                        8'h03: pending_special_type <= MOLE_BLUE;
                        default: pending_special_type <= MOLE_NONE;
                    endcase
                end

                if (tick_ms) begin
                    if (ms_count >= spawn_ms - 1) begin
                        ms_count <= 11'd0;
                        if (wave_spawn_mask != 6'd0) begin
                            spawn_valid <= 1'b1;
                            spawn_mask <= wave_spawn_mask;
                            spawn_type_flat <= wave_spawn_type_flat;
                            if (pending_special_valid) begin
                                pending_special_valid <= 1'b0;
                            end
                        end
                    end else begin
                        ms_count <= ms_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule
