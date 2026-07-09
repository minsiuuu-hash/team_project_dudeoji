`timescale 1ns / 1ps
// =====================================================================
//  색 인식 v3 : HSV(색상) 기반  ← 두더지 게임 6구역용으로 이식
//   - RGB444 → HSV 변환은 별도 HSV 모듈 사용 (top에서 연결)
//   - 판정: S/V 게이트로 회색·어두움 제거 + H(색상) 밴드로 빨강/초록/파랑
//   - run-length: 가로로 RUN_MIN 픽셀 연속돼야 인정(점 노이즈 제거)
//   - ROI: 각 칸 가장자리 무시(배경 제거)
//  * 출력 camera_exist / camera_color 는 기존과 동일 → 컨트롤러/렌더러 그대로
//  * 입력이 rgb444 → H,S,V 로 바뀜 → top에서 HSV 모듈 연결 필요(아래 안내)
//
//  H는 0~255가 0~360°.  이 HSV 모듈 기준: 빨강≈0/255, 초록≈85, 파랑≈171
// =====================================================================
module CameraAreaColorDetector #(
    parameter int AREA_COLS        = 3,
    parameter int AREA_ROWS        = 2,
    parameter int FRAME_WIDTH      = 320,
    parameter int FRAME_HEIGHT     = 240,
    // ---- HSV 색 밴드 (여기 범위를 넓히면 스펙트럼이 넓어짐) ----
    parameter logic [7:0] S_MIN    = 8'd150,  // 채도 최소(낮출수록 연한 색도 인정)
    parameter logic [7:0] V_MIN    = 8'd60,   // 명도 최소(낮출수록 어두운 색도 인정)
    parameter logic [7:0] H_RED_HI = 8'd18,   // 빨강: 0 ~ H_RED_HI
    parameter logic [7:0] H_RED_LO = 8'd230,  //       H_RED_LO ~ 255 (빨강은 양끝)
    parameter logic [7:0] H_GRN_LO = 8'd60,   // 초록: LO ~ HI
    parameter logic [7:0] H_GRN_HI = 8'd112,
    parameter logic [7:0] H_BLU_LO = 8'd145,  // 파랑: LO ~ HI
    parameter logic [7:0] H_BLU_HI = 8'd200,
    // ---- 노이즈/영역 판정 ----
    parameter int RUN_MIN          = 3,    // 가로 연속 픽셀 최소(점 노이즈 제거)
    parameter int MIN_COLOR_PIXELS = 150,  // 영역 확정 최소 픽셀 수
    parameter int ROI_MARGIN_X     = 26,   // 칸 좌우 가장자리 무시
    parameter int ROI_MARGIN_Y     = 30,   // 칸 상하 가장자리 무시
    parameter int COUNT_WIDTH      = 16
) (
    input  logic                             clk,
    input  logic                             reset,
    input  logic                             sample_valid,  // = HSV.DE_out (정렬된 유효)
    input  logic                             frame_done,    // HSV 지연분 반영해서 넣을 것
    input  logic [                      9:0] x_pixel,       // = HSV.x_out
    input  logic [                      9:0] y_pixel,       // = HSV.y_out
    input  logic [                      7:0] H,
    input  logic [                      7:0] S,
    input  logic [                      7:0] V,
    output logic [  AREA_COLS*AREA_ROWS-1:0] camera_exist,
    output logic [AREA_COLS*AREA_ROWS*2-1:0] camera_color
);
    localparam int AREA_COUNT = AREA_COLS * AREA_ROWS;
    localparam int AREA_W = FRAME_WIDTH / AREA_COLS;    // 106
    localparam int AREA_H = FRAME_HEIGHT / AREA_ROWS;   // 120
    localparam logic [1:0] COLOR_NONE  = 2'd0;
    localparam logic [1:0] COLOR_RED   = 2'd1;
    localparam logic [1:0] COLOR_BLUE  = 2'd2;
    localparam logic [1:0] COLOR_GREEN = 2'd3;
    // ---- 픽셀 색 판정 (S/V 게이트 + H 밴드) ----
    logic sv_ok, is_red, is_grn, is_blu;
    always_comb begin
        sv_ok  = (S >= S_MIN) && (V >= V_MIN);
        is_red = sv_ok && ((H <= H_RED_HI) || (H >= H_RED_LO));
        is_grn = sv_ok && (H >= H_GRN_LO) && (H <= H_GRN_HI);
        is_blu = sv_ok && (H >= H_BLU_LO) && (H <= H_BLU_HI);
    end
    // ---- run-length: 가로로 연속돼야 인정 ----
    logic [3:0] red_run, grn_run, blu_run;
    logic [9:0] prev_y;
    logic red_valid, grn_valid, blu_valid;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            red_run <= '0; grn_run <= '0; blu_run <= '0; prev_y <= 10'h3FF;
        end else if (sample_valid) begin
            if (y_pixel != prev_y) begin          // 새 줄 시작
                red_run <= is_red ? 4'd1 : 4'd0;
                grn_run <= is_grn ? 4'd1 : 4'd0;
                blu_run <= is_blu ? 4'd1 : 4'd0;
                prev_y  <= y_pixel;
            end else begin
                red_run <= is_red ? (red_run < 4'd15 ? red_run + 4'd1 : 4'd15) : 4'd0;
                grn_run <= is_grn ? (grn_run < 4'd15 ? grn_run + 4'd1 : 4'd15) : 4'd0;
                blu_run <= is_blu ? (blu_run < 4'd15 ? blu_run + 4'd1 : 4'd15) : 4'd0;
            end
        end
    end
    assign red_valid = is_red && (red_run >= RUN_MIN);
    assign grn_valid = is_grn && (grn_run >= RUN_MIN);
    assign blu_valid = is_blu && (blu_run >= RUN_MIN);
    // ---- 현재 픽셀의 영역 + ROI(가운데) ----
    logic [$clog2(AREA_COUNT)-1:0] area_index;
    logic in_roi;
    always_comb begin
        int x_area, y_area, lx, ly;
        if (x_pixel < AREA_W)            begin x_area = 0; lx = x_pixel; end
        else if (x_pixel < (AREA_W * 2)) begin x_area = 1; lx = x_pixel - AREA_W; end
        else                             begin x_area = 2; lx = x_pixel - (AREA_W * 2); end
        if (y_pixel < AREA_H)            begin y_area = 0; ly = y_pixel; end
        else                             begin y_area = 1; ly = y_pixel - AREA_H; end
        area_index = y_area * AREA_COLS + x_area;
        in_roi = (lx >= ROI_MARGIN_X) && (lx < (AREA_W - ROI_MARGIN_X)) &&
                 (ly >= ROI_MARGIN_Y) && (ly < (AREA_H - ROI_MARGIN_Y));
    end
    // ---- 영역별 색 픽셀 누적 ----
    logic [COUNT_WIDTH-1:0] red_count[AREA_COUNT];
    logic [COUNT_WIDTH-1:0] grn_count[AREA_COUNT];
    logic [COUNT_WIDTH-1:0] blu_count[AREA_COUNT];
    // ---- 영역 1등 색 결정 (argmax + 최소치) ----
    function automatic logic [1:0] dominant_color(
        input logic [COUNT_WIDTH-1:0] r_c, g_c, b_c
    );
        logic [COUNT_WIDTH-1:0] mx;
        logic [1:0] col;
        if ((r_c >= g_c) && (r_c >= b_c))      begin mx = r_c; col = COLOR_RED;   end
        else if (g_c >= b_c)                   begin mx = g_c; col = COLOR_GREEN; end
        else                                   begin mx = b_c; col = COLOR_BLUE;  end
        dominant_color = (mx >= MIN_COLOR_PIXELS) ? col : COLOR_NONE;
    endfunction
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            camera_exist <= '0;
            camera_color <= '0;
            for (int i = 0; i < AREA_COUNT; i++) begin
                red_count[i] <= '0; grn_count[i] <= '0; blu_count[i] <= '0;
            end
        end else begin
            if (frame_done) begin
                for (int i = 0; i < AREA_COUNT; i++) begin
                    camera_color[i*2 +: 2] <= dominant_color(red_count[i], grn_count[i], blu_count[i]);
                    camera_exist[i]        <= (dominant_color(red_count[i], grn_count[i], blu_count[i]) != COLOR_NONE);
                    red_count[i] <= '0; grn_count[i] <= '0; blu_count[i] <= '0;
                end
            end else if (sample_valid && in_roi &&
                         (x_pixel < FRAME_WIDTH) && (y_pixel < FRAME_HEIGHT)) begin
                if (red_valid && (red_count[area_index] != {COUNT_WIDTH{1'b1}}))
                    red_count[area_index] <= red_count[area_index] + 1'b1;
                else if (grn_valid && (grn_count[area_index] != {COUNT_WIDTH{1'b1}}))
                    grn_count[area_index] <= grn_count[area_index] + 1'b1;
                else if (blu_valid && (blu_count[area_index] != {COUNT_WIDTH{1'b1}}))
                    blu_count[area_index] <= blu_count[area_index] + 1'b1;
            end
        end
    end
endmodule

module MoleGameController #(
    parameter int AREA_COUNT  = 6,
    parameter int SCORE_WIDTH = 3
) (
    input  logic                           clk,
    input  logic                           reset,
    input  logic                           enable,
    input  logic                           debug_camera_only,
    input  logic                           spawn_tick,
    input  logic                           hit_valid,
    input  logic [$clog2(AREA_COUNT)-1:0]  hit_area,
    input  logic [        AREA_COUNT-1:0]  camera_exist,
    input  logic [      AREA_COUNT*2-1:0]  camera_color,
    output logic [        AREA_COUNT-1:0]  random_exist,
    output logic [        AREA_COUNT-1:0]  final_exist,
    output logic [      AREA_COUNT*3-1:0]  final_type,
    output logic [       SCORE_WIDTH-1:0]  score,
    output logic                           game_over,
    output logic                           hit_scored,
    output logic                           hit_gameover
);
    localparam logic [1:0] COLOR_NONE  = 2'd0;
    localparam logic [1:0] COLOR_RED   = 2'd1;
    localparam logic [1:0] COLOR_BLUE  = 2'd2;
    localparam logic [1:0] COLOR_GREEN = 2'd3;
    // ---- 종류 코드 (렌더러와 동일해야 함) ----
    localparam logic [2:0] TYPE_NONE  = 3'd0;
    localparam logic [2:0] TYPE_BASIC = 3'd1;  // 랜덤 스폰(카메라색 없음) 기본 두더지
    localparam logic [2:0] TYPE_MOLE  = 3'd2;  // 빨강 → 두더지
    localparam logic [2:0] TYPE_BONUS = 3'd3;  // 초록 → 보너스 두더지
    localparam logic [2:0] TYPE_OTHER = 3'd4;  // 파랑 → 다른 캐릭터
    logic [15:0] lfsr;
    logic [AREA_COUNT-1:0] random_mole;
    logic [AREA_COUNT-1:0] random_mask_a;
    logic [AREA_COUNT-1:0] random_mask_b;
    logic [AREA_COUNT-1:0] next_random_mole;
    logic [$clog2(AREA_COUNT)-1:0] random_area;
    logic [$clog2(AREA_COUNT)-1:0] random_area_b;
    assign random_area = lfsr[3:0] % AREA_COUNT;
    assign random_area_b = (random_area == ((lfsr[7:4] % AREA_COUNT))) ?
                           ((random_area == AREA_COUNT - 1) ? '0 : random_area + 1'b1) :
                           (lfsr[7:4] % AREA_COUNT);
    assign random_exist = debug_camera_only ? '0 : random_mole;
    // [FIX 2] 카메라 색 겹침 조건 완화:
    //   기존: camera_exist & random_mole (겹쳐야만 색 반영)
    //   수정: camera_exist 가 있으면 항상 반영
    assign final_exist = debug_camera_only ? camera_exist : (random_mole | camera_exist);
    // ---- 색 → 종류 (규칙을 바꾸려면 여기만 수정) ----
    function automatic logic [2:0] color_to_type(input logic [1:0] color);
        case (color)
            COLOR_RED:   color_to_type = TYPE_MOLE;    // 두더지
            COLOR_GREEN: color_to_type = TYPE_BONUS;   // 보너스 두더지
            COLOR_BLUE:  color_to_type = TYPE_OTHER;   // 다른 캐릭터
            default:     color_to_type = TYPE_NONE;
        endcase
    endfunction
    always_comb begin
        random_mask_a = '0;
        random_mask_b = '0;
        random_mask_a[random_area] = 1'b1;
        random_mask_b[random_area_b] = 1'b1;
        next_random_mole = lfsr[8] ? (random_mask_a | random_mask_b) : random_mask_a;
        // [FIX 2] final_type: 카메라 색 우선, 없으면 TYPE_BASIC
        for (int i = 0; i < AREA_COUNT; i++) begin
            if (camera_exist[i]) begin
                // 카메라 색이 감지된 칸 → 색에 따라 두더지/보너스/다른것
                final_type[i*3 +: 3] = color_to_type(camera_color[i*2 +: 2]);
            end else if (random_mole[i]) begin
                // 카메라 색 없이 랜덤으로만 뜬 칸 → 기본 두더지
                final_type[i*3 +: 3] = TYPE_BASIC;
            end else begin
                final_type[i*3 +: 3] = TYPE_NONE;
            end
        end
    end
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr         <= 16'hACE1;
            random_mole  <= '0;
            score        <= '0;
            game_over    <= 1'b0;
            hit_scored   <= 1'b0;
            hit_gameover <= 1'b0;
        end else begin
            hit_scored   <= 1'b0;
            hit_gameover <= 1'b0;
            if (enable) begin
                lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
                // ===================================================
                // [FIX 1] 타격 판정 로직 추가
                // ===================================================
                if (hit_valid && !game_over) begin
                    if (hit_area < AREA_COUNT && final_exist[hit_area]) begin
                        case (final_type[hit_area*3 +: 3])
                            TYPE_BASIC: begin
                                score      <= score + 16'd1;
                                hit_scored <= 1'b1;
                            end
                            TYPE_MOLE: begin
                                score      <= score + 16'd1;
                                hit_scored <= 1'b1;
                            end
                            TYPE_BONUS: begin
                                score      <= score + 16'd3;
                                hit_scored <= 1'b1;
                            end
                            TYPE_OTHER: begin
                                game_over    <= 1'b1;
                                hit_gameover <= 1'b1;
                            end
                            default: ;
                        endcase
                        // 맞은 칸의 랜덤 두더지 제거
                        random_mole[hit_area] <= 1'b0;
                    end
                end
                if (spawn_tick && !game_over) begin
                    random_mole <= next_random_mole;
                end
            end
        end
    end
endmodule