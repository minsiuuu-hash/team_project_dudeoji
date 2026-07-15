
`timescale 1ns / 1ps

module game_renderer (
    input  logic        clk,
    input  logic        de,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [ 2:0] game_state,
    input  logic [ 7:0] score,
    input  logic [ 5:0] time_left,
    input  logic [17:0] mole_type_flat,
    input  logic [ 5:0] active_mask,
    input  logic [ 5:0] hit_anim_mask,
    output logic [11:0] rgb
);
    localparam logic [2:0] IDLE = 3'd0;
    localparam logic [2:0] STAGE1 = 3'd1;
    localparam logic [2:0] STAGE2 = 3'd2;
    localparam logic [2:0] STAGE3 = 3'd3;
    localparam logic [2:0] WIN = 3'd4;
    localparam logic [2:0] GAME_OVER = 3'd5;

    logic [9:0] lx;
    logic [9:0] ly;
    assign lx = x_pixel[9:1];
    assign ly = y_pixel[9:1];

    logic title_on;
    logic score_label_on;
    logic score_value_on;
    logic stage_label_on;
    logic stage_value_on;
    logic hit_on;

    text_renderer U_title (
        .x(lx),
        .y(ly),
        .origin_x(10'd112),
        .origin_y(10'd8),
        .scale(4'd2),
        .char_count(4'd9),
        .word_id(4'd0),
        .value(8'd0),
        .pixel_on(title_on)
    );
    text_renderer U_score_label (
        .x(lx),
        .y(ly),
        .origin_x(10'd8),
        .origin_y(10'd8),
        .scale(4'd1),
        .char_count(4'd5),
        .word_id(4'd1),
        .value(8'd0),
        .pixel_on(score_label_on)
    );
    text_renderer U_score_value (
        .x(lx),
        .y(ly),
        .origin_x(10'd46),
        .origin_y(10'd8),
        .scale(4'd1),
        .char_count(4'd2),
        .word_id(4'd6),
        .value(score),
        .pixel_on(score_value_on)
    );
    text_renderer U_stage_label (
        .x(lx),
        .y(ly),
        .origin_x(10'd240),
        .origin_y(10'd8),
        .scale(4'd1),
        .char_count(4'd5),
        .word_id(4'd2),
        .value(8'd0),
        .pixel_on(stage_label_on)
    );
    text_renderer U_stage_value (
        .x(lx),
        .y(ly),
        .origin_x(10'd280),
        .origin_y(10'd8),
        .scale(4'd1),
        .char_count(4'd1),
        .word_id(4'd7),
        .value({5'd0, game_state}),
        .pixel_on(stage_value_on)
    );

    logic [2:0] area;
    logic [9:0] cx;
    logic [9:0] cy;
    logic [10:0] cx_p;    // physical center = cx * 2
    logic [10:0] cy_p;    // physical center = cy * 2
    logic signed [10:0] dx;
    logic signed [10:0] dy;
    logic [10:0] adx;
    logic [10:0] ady;
    logic in_sprite;
    logic [10:0] sprite_x_full;
    logic [10:0] sprite_y_full;
    logic [6:0] sprite_x;   // 0-95, native resolution
    logic [6:0] sprite_y;   // 0-95, native resolution
    logic [2:0] current_type;
    logic [11:0] sprite_rgb;
    logic sprite_opaque;
    logic [9:0] hit_origin_x;
    logic [9:0] hit_origin_y;

    // ================================================================
    //  Stage time gauge bar - 3 segments of 15s each (45s total), drawn
    //  as a thin bar in the empty space below the HUD text (ly 24-30).
    //  Assumes time_left resets to 15 at the start of each stage and
    //  counts down to 0.
    // ================================================================
    localparam [9:0] GAUGE_X0 = 10'd16;
    localparam [9:0] GAUGE_Y0 = 10'd24;
    localparam [9:0] GAUGE_Y1 = 10'd30;  // exclusive
    localparam [9:0] GAUGE_SEG_W = 10'd96;
    localparam [5:0] GAUGE_SECS = 6'd15;

    logic [7:0] gauge_fill_px;   // 0-96, how full the CURRENT stage's segment is
    logic [5:0] gauge_elapsed;   // 0-15 seconds elapsed in current stage
    logic [11:0] gauge_fill_tmp;
    logic [11:0] gauge_fill_div;

    logic [1:0] gseg_idx;
    logic [9:0] gseg_idx_full;
    logic [7:0] gseg_x;
    logic [9:0] gseg_x_full;
    logic [7:0] gseg_filled;
    logic [11:0] gseg_color;

    always_comb begin
        if (time_left <= GAUGE_SECS) begin
            gauge_elapsed = GAUGE_SECS - time_left;
        end else begin
            gauge_elapsed = 6'd0;
        end
        gauge_fill_tmp = {6'd0, gauge_elapsed} * 12'd96;
        gauge_fill_div = gauge_fill_tmp / 12'd15;
        gauge_fill_px  = gauge_fill_div[7:0];
    end

    always_comb begin
        gseg_idx_full = (lx - GAUGE_X0) / GAUGE_SEG_W;
        gseg_idx      = gseg_idx_full[1:0];
        gseg_x_full   = (lx - GAUGE_X0) - ({8'd0, gseg_idx} * GAUGE_SEG_W);
        gseg_x        = gseg_x_full[7:0];

        case (gseg_idx)
            2'd0: gseg_color = 12'h2E4;  // stage 1: green
            2'd1: gseg_color = 12'hFE3;  // stage 2: amber/yellow
            default: gseg_color = 12'hF43;  // stage 3: red
        endcase

        case (gseg_idx)
            2'd0: gseg_filled = (game_state > STAGE1) ? 8'd96 :
                                 (game_state == STAGE1) ? gauge_fill_px : 8'd0;
            2'd1: gseg_filled = (game_state > STAGE2) ? 8'd96 :
                                 (game_state == STAGE2) ? gauge_fill_px : 8'd0;
            default: gseg_filled = (game_state == STAGE3) ? gauge_fill_px : 8'd0;
        endcase
    end

    always_comb begin
        area = 3'd0;
        if (ly < 10'd137) begin
            if (lx < 10'd106) area = 3'd0;
            else if (lx < 10'd213) area = 3'd1;
            else area = 3'd2;
        end else begin
            if (lx < 10'd106) area = 3'd3;
            else if (lx < 10'd213) area = 3'd4;
            else area = 3'd5;
        end

        case (area)
            3'd0: begin
                cx = 10'd72;
                cy = 10'd136;
            end
            3'd1: begin
                cx = 10'd162;
                cy = 10'd136;
            end
            3'd2: begin
                cx = 10'd249;
                cy = 10'd136;
            end
            3'd3: begin
                cx = 10'd72;
                cy = 10'd186;
            end
            3'd4: begin
                cx = 10'd162;
                cy = 10'd187;
            end
            default: begin
                cx = 10'd249;
                cy = 10'd186;
            end
        endcase

        cx_p = {cx, 1'b0};
        cy_p = {cy, 1'b0};

        dx = $signed({1'b0, lx}) - $signed({1'b0, cx});
        dy = $signed({1'b0, ly}) - $signed({1'b0, cy});
        adx = dx < 0 ? -dx : dx;
        ady = dy < 0 ? -dy : dy;

        // Sprite bounding box in PHYSICAL pixels (96x96 native)
        in_sprite = (x_pixel >= (cx_p - 11'd48)) && (x_pixel < (cx_p + 11'd48)) &&
                    (y_pixel >= (cy_p - 11'd96)) && (y_pixel < cy_p);

        sprite_x_full = {1'b0, x_pixel} - (cx_p - 11'd48);
        sprite_y_full = {1'b0, y_pixel} - (cy_p - 11'd96);
        sprite_x = sprite_x_full[6:0];
        sprite_y = sprite_y_full[6:0];

        current_type = active_mask[area] ? mole_type_flat[area*3+:3] : 3'd0;
        hit_origin_x = cx - 10'd13;
        if (area < 3'd3) begin
            hit_origin_y = cy - 10'd62;  // top row: above the mole
        end else begin
            hit_origin_y = cy + 10'd10;  // bottom row: below the hole
        end
    end

    sprite_renderer #(
        .NORMAL_FILE("normal_96x96.mem"),
        .RED_FILE   ("red_96x96.mem"),
        .GREEN_FILE ("green_96x96.mem"),
        .BLUE_FILE  ("blue_96x96.mem")
        // .NORMAL_FILE("C:/ondevice2026_kang/class/system_verilog_file/260713_teamproj_mon2_btn/260713_teamproj_mon2_btn.srcs/sources_1/imports/assets/normal_96x96.mem"),
        // .RED_FILE   ("C:/ondevice2026_kang/class/system_verilog_file/260713_teamproj_mon2_btn/260713_teamproj_mon2_btn.srcs/sources_1/imports/assets/red_96x96.mem"),
        // .GREEN_FILE ("C:/ondevice2026_kang/class/system_verilog_file/260713_teamproj_mon2_btn/260713_teamproj_mon2_btn.srcs/sources_1/imports/assets/green_96x96.mem"),
        // .BLUE_FILE  ("C:/ondevice2026_kang/class/system_verilog_file/260713_teamproj_mon2_btn/260713_teamproj_mon2_btn.srcs/sources_1/imports/assets/blue_96x96.mem")
    ) U_sprite (
        .clk(clk),
        .mole_type(current_type),
        .sprite_x(sprite_x),
        .sprite_y(sprite_y),
        .rgb(sprite_rgb),
        .opaque(sprite_opaque)
    );

    text_renderer U_hit (
        .x(lx),
        .y(ly),
        .origin_x(hit_origin_x),
        .origin_y(hit_origin_y),
        .scale(4'd2),
        .char_count(4'd4),
        .word_id(4'd5),
        .value(8'd0),
        .pixel_on(hit_on)
    );

    // ================================================================
    //  Photo Background ROM
    // ================================================================
    logic [11:0] bg_rgb;

    bg_renderer #(
        .BG_FILE("background_320x240.mem")
    ) U_background (
        .clk(clk),
        .lx (lx),
        .ly (ly),
        .rgb(bg_rgb)
    );

    // ================================================================
    //  MAIN PIXEL OUTPUT
    // ================================================================
    always_comb begin
        rgb = 12'h000;
        if (!de) begin
            rgb = 12'h000;

        // ============================================================
        //  WIN / GAME OVER screen (overlay drawn on Python side; this is
        //  just a black screen + small color marker so the PC vision
        //  detector can tell WIN from GAME_OVER without UART)
        // ============================================================
        end else if (game_state == WIN || game_state == GAME_OVER) begin
            rgb = 12'h000;
            if (lx >= 10'd120 && lx < 10'd200 && ly >= 10'd95 && ly < 10'd145) begin
                rgb = (game_state == WIN) ? 12'hFF0 : 12'hF22;  // yellow=WIN, red=GAME_OVER
            end

        // ============================================================
        //  IDLE / STAGE gameplay
        // ============================================================
        end else begin
            // Layer 0: Photo background
            rgb = bg_rgb;

            // Layer 1: Dark top bar behind HUD
            if (ly < 10'd32) begin
                rgb = 12'h124;
            end

            // Layer 1.5: Stage time gauge bar (3 segments, green/amber/red),
            // drawn on top of the HUD bar, below the SCORE/STAGE text
            if (ly >= GAUGE_Y0 && ly < GAUGE_Y1 && lx >= GAUGE_X0 && lx < (GAUGE_X0 + 3 * GAUGE_SEG_W)) begin
                rgb = (gseg_x < gseg_filled) ? gseg_color : 12'h333;
            end

            // Layer 2: UI text (white)
            if (title_on || score_label_on || score_value_on ||
                stage_label_on || stage_value_on)
                rgb = 12'hFFF;

            // Layer 3: Mole sprite (Holes are in the background image)
            if (in_sprite && sprite_opaque) begin
                rgb = sprite_rgb;
            end
        end

        // ---- Layer 5: HIT animation (yellow text, highest priority) ----
        if (de &&
            ((game_state == STAGE1) || (game_state == STAGE2) || (game_state == STAGE3)) &&
            hit_anim_mask[area] && hit_on) begin
            rgb = 12'hFF0;
        end
    end
endmodule