`timescale 1ns / 1ps
// =====================================================================
//  렌더러: 색에 따라 결정된 종류(final_type)를 화면에 그림
//   - 두더지(TYPE_MOLE/BONUS/BASIC): 몸통 + 분홍 코
//   - 다른 캐릭터(TYPE_OTHER)        : 보라 몸통 + 검은 눈 (두더지와 확실히 구분)
//  * TYPE_* 코드는 컨트롤러와 동일해야 함
//
// [FIX 3] select_border 렌더링 추가
// =====================================================================
module MoleScreenRenderer (
    input  logic        de,
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,
    input  logic [11:0] camera_rgb,
    input  logic [5:0]  camera_exist,
    input  logic [11:0] camera_color,
    input  logic [5:0]  final_exist,
    input  logic [17:0] final_type,
    input  logic [3:0]  hit_area,
    input  logic [15:0] score, 
    input  logic        game_over,
    output logic [11:0] rgb_out
);
    localparam logic [11:0] BLACK  = 12'h000;
    localparam logic [11:0] WHITE  = 12'hFFF;
    localparam logic [11:0] GRAY   = 12'h333;
    localparam logic [11:0] DGRAY  = 12'h111;
    localparam logic [11:0] SKY    = 12'h4BF;
    localparam logic [11:0] GRASS  = 12'h4B2;
    localparam logic [11:0] GRASS2 = 12'h6D2;
    localparam logic [11:0] DIRT   = 12'h853;
    localparam logic [11:0] HOLE   = 12'h210;
    localparam logic [11:0] WOOD   = 12'hA52;
    localparam logic [11:0] PINK   = 12'hF7A;
    localparam logic [11:0] YELLOW = 12'hFE0;
    localparam logic [11:0] RED    = 12'hF11;
    localparam logic [11:0] BLUE   = 12'h25F;
    localparam logic [11:0] GREEN  = 12'h2E3;
    localparam logic [11:0] BASIC  = 12'hFA6;
    localparam logic [11:0] PURPLE = 12'h80F;  // '다른 캐릭터' 몸통색
    localparam logic [1:0] COLOR_RED   = 2'd1;
    localparam logic [1:0] COLOR_BLUE  = 2'd2;
    localparam logic [1:0] COLOR_GREEN = 2'd3;
    // ---- 종류 코드 (컨트롤러와 동일) ----
    localparam logic [2:0] TYPE_NONE  = 3'd0;
    localparam logic [2:0] TYPE_BASIC = 3'd1;
    localparam logic [2:0] TYPE_MOLE  = 3'd2;
    localparam logic [2:0] TYPE_BONUS = 3'd3;
    localparam logic [2:0] TYPE_OTHER = 3'd4;
    logic right_side;
    logic [9:0] xr;
    logic [3:0] game_area;
    logic [3:0] cam_area;
    logic [1:0] game_col;
    logic [1:0] game_row;
    logic [1:0] cam_col;
    logic [1:0] cam_row;
    logic [6:0] cell_x;
    logic [6:0] cell_y;
    logic [7:0] cam_cell_x;
    logic [7:0] cam_cell_y;
    logic board_area;
    logic mole_box;
    logic mole_face;
    logic mole_nose;
    logic other_eye;
    logic is_other;
    logic hole_ring;
    logic hole_dark;
    logic sign_area;
    logic select_border;
    logic grid_line;
    logic cam_border;
    logic score_box;
    logic [2:0]  cur_type;
    logic [11:0] mole_rgb;
    logic [11:0] cam_border_rgb;
    assign right_side = x_pixel >= 10'd320;
    assign xr = x_pixel - 10'd320;
    // 몸통색: 종류별로 다르게
    function automatic logic [11:0] type_rgb(input logic [2:0] mole_type);
        case (mole_type)
            TYPE_BASIC: type_rgb = BASIC;    // 기본 두더지(황토)
            TYPE_MOLE:  type_rgb = RED;      // 빨강 두더지
            TYPE_BONUS: type_rgb = GREEN;    // 보너스 두더지
            TYPE_OTHER: type_rgb = PURPLE;   // 다른 캐릭터
            default:    type_rgb = GRAY;
        endcase
    endfunction
    function automatic logic [11:0] color_rgb(input logic [1:0] color);
        case (color)
            COLOR_RED:   color_rgb = RED;
            COLOR_BLUE:  color_rgb = BLUE;
            COLOR_GREEN: color_rgb = GREEN;
            default:     color_rgb = WHITE;
        endcase
    endfunction
    always_comb begin
        rgb_out = BLACK;
        game_area = 4'd15;
        game_col = 2'd0;
        game_row = 2'd0;
        cell_x = 7'd0;
        cell_y = 7'd0;
        if ((x_pixel >= 10'd10) && (x_pixel < 10'd310) && (y_pixel >= 10'd145) && (y_pixel < 10'd345)) begin
            if (x_pixel < 10'd110) begin
                game_col = 2'd0;
                cell_x = x_pixel - 10'd10;
            end else if (x_pixel < 10'd210) begin
                game_col = 2'd1;
                cell_x = x_pixel - 10'd110;
            end else begin
                game_col = 2'd2;
                cell_x = x_pixel - 10'd210;
            end
            if (y_pixel < 10'd245) begin
                game_row = 2'd0;
                cell_y = y_pixel - 10'd145;
            end else begin
                game_row = 2'd1;
                cell_y = y_pixel - 10'd245;
            end
            game_area = {2'b00, game_row} * 4'd3 + {2'b00, game_col};
        end
        if (xr < 10'd106) begin
            cam_col = 2'd0;
            cam_cell_x = xr[7:0];
        end else if (xr < 10'd213) begin
            cam_col = 2'd1;
            cam_cell_x = (xr - 10'd106);
        end else begin
            cam_col = 2'd2;
            cam_cell_x = (xr - 10'd213);
        end
        if (y_pixel < 10'd240) begin
            cam_row = 2'd0;
            cam_cell_y = y_pixel[7:0];
        end else begin
            cam_row = 2'd1;
            cam_cell_y = (y_pixel - 10'd240);
        end
        cam_area = {2'b00, cam_row} * 4'd3 + {2'b00, cam_col};
        board_area = (game_area < 4'd6);
        // 현재 칸의 종류
        cur_type = (game_area < 4'd6) ? final_type[game_area*3 +: 3] : TYPE_NONE;
        is_other = board_area && final_exist[game_area] && (cur_type == TYPE_OTHER);
        mole_box  = board_area && (cell_x >= 7'd30) && (cell_x < 7'd70) && (cell_y >= 7'd30) && (cell_y < 7'd70);
        mole_face = board_area && (cell_x >= 7'd34) && (cell_x < 7'd66) && (cell_y >= 7'd20) && (cell_y < 7'd70);
        mole_nose = board_area && (cell_x >= 7'd45) && (cell_x < 7'd56) && (cell_y >= 7'd42) && (cell_y < 7'd52);
        // '다른 캐릭터' 눈 두 개 (두더지와 구분되는 표식)
        other_eye = board_area && (cell_y >= 7'd34) && (cell_y < 7'd44) &&
                    (((cell_x >= 7'd38) && (cell_x < 7'd46)) || ((cell_x >= 7'd54) && (cell_x < 7'd62)));
        hole_ring = board_area && (cell_x >= 7'd18) && (cell_x < 7'd82) && (cell_y >= 7'd58) && (cell_y < 7'd88);
        hole_dark = board_area && (cell_x >= 7'd25) && (cell_x < 7'd75) && (cell_y >= 7'd65) && (cell_y < 7'd84);
        sign_area = (x_pixel >= 10'd78) && (x_pixel < 10'd242) && (y_pixel >= 10'd18) && (y_pixel < 10'd66);
        select_border = board_area && (game_area == hit_area) &&
                        ((cell_x < 7'd4) || (cell_x >= 7'd96) || (cell_y < 7'd4) || (cell_y >= 7'd96));
        score_box = (y_pixel >= 10'd420) && (y_pixel < 10'd440) && (x_pixel >= 10'd10) && (x_pixel < 10'd266);
        grid_line = right_side && ((xr == 10'd106) || (xr == 10'd107) ||
                                   (xr == 10'd213) || (xr == 10'd214) ||
                                   (y_pixel == 10'd240) || (y_pixel == 10'd241));
        cam_border = right_side && camera_exist[cam_area] &&
                     ((cam_cell_x < 8'd8) || (cam_cell_x >= 8'd98) ||
                      (cam_cell_y < 8'd8) || (cam_cell_y >= 8'd232));
        mole_rgb = (game_area < 4'd6) ? type_rgb(cur_type) : GRAY;
        cam_border_rgb = color_rgb(camera_color[cam_area*2 +: 2]);
        if (!de) begin
            rgb_out = BLACK;
        end else if (!right_side) begin
            rgb_out = (y_pixel < 10'd105) ? SKY : GRASS;
            if (y_pixel < 10'd4 || y_pixel >= 10'd476 || x_pixel < 10'd4 || x_pixel >= 10'd316) begin
                rgb_out = WHITE;
            end else if ((y_pixel >= 10'd105) && (y_pixel < 10'd145)) begin
                rgb_out = 12'h6C3;
            end else if (sign_area) begin
                if ((y_pixel < 10'd24) || (y_pixel >= 10'd60) || (x_pixel < 10'd84) || (x_pixel >= 10'd236)) begin
                    rgb_out = DIRT;
                end else begin
                    rgb_out = WOOD;
                end
                if ((x_pixel >= 10'd108) && (x_pixel < 10'd212) && (y_pixel >= 10'd32) && (y_pixel < 10'd48)) begin
                    rgb_out = YELLOW;
                end
            end else if (board_area) begin
                if (hole_ring) begin
                    rgb_out = DIRT;
                end else if (hole_dark) begin
                    rgb_out = HOLE;
                end else begin
                    rgb_out = ((x_pixel[4] ^ y_pixel[3]) ? GRASS : GRASS2);
                end
                if (hole_dark) begin
                    rgb_out = HOLE;
                end
                // 몸통
                if (final_exist[game_area] && mole_face) begin
                    rgb_out = mole_rgb;
                end
                // 두더지 → 분홍 코 / 다른 캐릭터 → 검은 눈
                if (final_exist[game_area] && !is_other && mole_nose) begin
                    rgb_out = PINK;
                end
                if (is_other && other_eye) begin
                    rgb_out = BLACK;
                end
                // [FIX 3] 선택된 칸 테두리 표시 (노란색)
                if (select_border) begin
                    rgb_out = YELLOW;
                end
            end else if (score_box) begin
                if (score[(x_pixel - 10'd10) >> 4]) begin
                    rgb_out = YELLOW;
                end else begin
                    rgb_out = GRAY;
                end
            end
        end else begin
            rgb_out = camera_rgb;
            if (grid_line) begin
                rgb_out = WHITE;
            end
            if (cam_border) begin
                rgb_out = cam_border_rgb;
            end
        end
    end
endmodule
