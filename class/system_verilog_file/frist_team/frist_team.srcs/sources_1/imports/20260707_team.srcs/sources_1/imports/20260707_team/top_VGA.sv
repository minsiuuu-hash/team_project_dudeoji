`timescale 1ns / 1ps

module top_VGA (
    input logic clk,
    input logic reset,

    // sw
    input logic sw_mode,  // 게임 모드: 올리면 랜덤 / 내리면 지정 (아래 debug_camera_only 참고)
    input logic sw_filter,  // between RGB amd grey -> mode change
    input logic [2:0] sw,  // RGB
    input logic [3:0] hit_area_sw,
    input logic btn_u,

    // ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] pdata,

    //
    output logic        scl,
    inout  logic        sda,
    // vga side
    output logic        h_sync,
    output logic        v_sync,
    output logic [ 3:0] port_red,
    output logic [ 3:0] port_green,
    output logic [ 3:0] port_blue,
    output logic [15:0] led
);

    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       de;

    logic [$clog2(320*240)-1:0] addr;
    logic [               15:0] imgPxlData;

    logic [$clog2(320*240)-1:0] qvga_addr;
    logic [               15:0] qvga_imgPxlData;

    logic [$clog2(320*240)-1:0] frame_addr;
    logic [               15:0] frame_imgPxlData;

    logic [3:0] frame_red, frame_green, frame_blue;
    logic [3:0] upscale_red, upscale_green, upscale_blue;

    logic [$clog2(320*240)-1:0] upscale_addr;
    logic [               15:0] upscale_imgPxlData;

    logic [$clog2(320*240)-1:0] addr_selected;
    logic [               15:0] imgPxlData_selected;

    logic [               11:0] RGB_filter_data;
    logic [               11:0] grey_filter_data;
    // framebuffer side
    logic                       we;
    logic [$clog2(320*240)-1:0] wAddr;
    logic [               15:0] wData;

    logic clk_100M, clk_25M, rclk;

    logic cam_start, cam_done;
    logic start_fired;
    logic btn_u_meta, btn_u_sync, btn_u_prev;
    logic        hit_valid;
    logic [ 3:0] hit_area;
    logic        color_debug_mode;
    logic        spawn_tick;
    logic [28:0] spawn_counter;
    logic        frame_done;
    logic [ 5:0] camera_exist;
    logic [11:0] camera_color;
    logic [ 5:0] random_exist;
    logic [ 5:0] final_exist;
    logic [17:0] final_type;
    logic [15:0] score;
    logic        game_over;
    logic        hit_scored;
    logic        hit_gameover;
    logic [ 9:0] camera_x;
    logic [ 9:0] camera_y;
    logic [11:0] camera_rgb;
    logic [11:0] screen_rgb;
    logic        sample_valid;

    // ---- HSV 변환 관련 (신규) ----
    logic        hsv_de;
    logic [9:0] hsv_x, hsv_y;
    logic [7:0] Hc, Sc, Vc;
    logic [ 3:0] fd_pipe;  // frame_done 파이프라인 정렬용
    logic        debug_camera_only;  // 게임 모드 (1=지정, 0=랜덤)

    // ==========================================
    // 2. 색상 및 픽셀 데이터 (Camera -> HSV -> Detector -> Renderer)
    // ==========================================
    logic [11:0] rgb444;

    assign xclk = clk_25M;
    assign color_debug_mode = hit_area_sw[0];  // LED 디버그 화면 선택용 (게임 모드와 별개)
    assign hit_area = (hit_area_sw > 4'd8) ? 4'd8 : hit_area_sw;
    logic frame_done_raw, frame_done_d;

    assign frame_done_raw = de && (x_pixel == 10'd0) && (y_pixel == 10'd0);

    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) frame_done_d <= 1'b0;
        else frame_done_d <= frame_done_raw;
    end

    assign frame_done = frame_done_raw && !frame_done_d;  // rising edge 1클럭 펄스
    assign led = color_debug_mode ? {camera_color[9:0], camera_exist} : {4'b0, game_over, score[4:0], final_exist};
    assign camera_x = (x_pixel >= 10'd320) ? (x_pixel - 10'd320) : 10'd0;
    assign camera_y = y_pixel[9:1];
    assign camera_rgb = {
        qvga_imgPxlData[15:12], qvga_imgPxlData[10:7], qvga_imgPxlData[4:1]
    };
    assign {port_red, port_green, port_blue} = screen_rgb;

    // 카메라 픽셀 유효 (오른쪽 절반에서 카메라 표시)
    logic [9:0] xp_d, yp_d;
    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            xp_d <= '0;
            yp_d <= '0;
        end else begin
            xp_d <= x_pixel;
            yp_d <= y_pixel;
        end
    end

    assign sample_valid = de && (x_pixel >= 10'd320) &&
                      ((x_pixel != xp_d) || (y_pixel != yp_d));

    // 게임 모드: 스위치 올리면(1) 랜덤, 내리면(0) 지정
    //  debug_camera_only=1 → 카메라만(지정),  =0 → 랜덤+카메라
    assign debug_camera_only = ~sw_mode;

    clk_wiz_0 U_ClockWizard (
        .clk_100M(clk_100M),
        .clk_25M (clk_25M),
        .reset   (reset),
        .clk_in1 (clk)
    );

    VGA_Decoder U_VGA_Decoder (
        .clk    (clk_100M),
        .reset  (reset),
        .rclk   (rclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    frameBuffer U_frameBuffer (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (rclk),
        .rAddr(addr_selected),
        .rData(qvga_imgPxlData)
    );

    OV7670MemController U_OV7670MemController (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .pdata(pdata),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );

    always_comb begin
        if (de && (x_pixel >= 10'd320)) begin
            addr_selected = {camera_y, 8'b0} + {camera_y, 6'b0} + camera_x;
        end else begin
            addr_selected = {y_pixel[9:1], 8'b0} + {y_pixel[9:1], 6'b0} + x_pixel[9:1];
        end
    end

    // ---- (신규) RGB444 → HSV : 4단 파이프라인, x/y/DE 정렬 출력 ----
    HSV U_HSV (
        .clk   (clk_100M),
        .reset (reset),
        .DE_in (sample_valid),
        .x_in  (camera_x),
        .y_in  (camera_y),
        .R     (camera_rgb[11:8]),
        .G     (camera_rgb[7:4]),
        .B     (camera_rgb[3:0]),
        .DE_out(hsv_de),
        .x_out (hsv_x),
        .y_out (hsv_y),
        .H     (Hc),
        .S     (Sc),
        .V     (Vc)
    );

    // ---- (신규) HSV 지연(4클럭)만큼 frame_done 정렬 ----
    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) fd_pipe <= 4'd0;
        else fd_pipe <= {fd_pipe[2:0], frame_done};
    end

    // ---- HSV 기반 색 검출기 (입력이 H/S/V 로 바뀜) ----
    CameraAreaColorDetector #(
        .AREA_COLS(3),
        .AREA_ROWS(2),
        .FRAME_WIDTH(320),
        .FRAME_HEIGHT(240),
        .S_MIN(8'd100),  // 채도 최소 (낮출수록 연한 색 인식)
        .V_MIN(8'd50),  // 명도 최소 (낮출수록 어두운 색 인식)
        .RUN_MIN(3),  // 가로 연속 픽셀 최소(노이즈 제거)
        .MIN_COLOR_PIXELS(80),  // 영역당 최소 픽셀 수
        .ROI_MARGIN_X(26),
        .ROI_MARGIN_Y(30)
    ) U_CameraAreaColorDetector (
        .clk         (clk_100M),
        .reset       (reset),
        .sample_valid(hsv_de),        // HSV 정렬 유효
        .frame_done  (fd_pipe[3]),    // HSV 지연 반영
        .x_pixel     (hsv_x),
        .y_pixel     (hsv_y),
        .H           (Hc),
        .S           (Sc),
        .V           (Vc),
        .camera_exist(camera_exist),
        .camera_color(camera_color)
    );

    MoleScreenRenderer U_MoleScreenRenderer (
        .de(de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .camera_rgb(camera_rgb),
        .camera_exist(camera_exist),
        .camera_color(camera_color),
        .final_exist(final_exist),
        .final_type(final_type),
        .hit_area(hit_area),  // 상수 → 실제 선택 칸으로 연결
        .score(score),
        .game_over(game_over),
        .rgb_out(screen_rgb)
    );

    MoleGameController #(
        .AREA_COUNT (6),
        .SCORE_WIDTH(3)
    ) U_MoleGameController (
        .clk(clk_100M),
        .reset(reset),
        .enable(1'b1),
        .debug_camera_only(debug_camera_only),  // sw_mode 로 랜덤/지정 선택
        .spawn_tick(spawn_tick),
        .hit_valid(hit_valid),
        .hit_area(hit_area[2:0]),  // 상수 → 선택 칸 (0~5)
        .camera_exist(camera_exist),
        .camera_color(camera_color),
        .random_exist(random_exist),
        .final_exist(final_exist),
        .final_type(final_type),
        .score(score),
        .game_over(game_over),
        .hit_scored(hit_scored),
        .hit_gameover(hit_gameover)
    );

    OV7670_config_top #(
        .CAM_WADDR(8'h42)
    ) U_OVGA_CNTL (
        .clk  (clk_100M),
        .rst  (reset),
        .start(cam_start),
        .done (cam_done),
        .scl  (scl),
        .sda  (sda)
    );

    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            cam_start   <= 1'b0;
            start_fired <= 1'b0;
        end else begin
            cam_start <= 1'b0;
            if (!start_fired) begin
                cam_start   <= 1'b1;
                start_fired <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            btn_u_meta <= 1'b0;
            btn_u_sync <= 1'b0;
            btn_u_prev <= 1'b0;
            hit_valid  <= 1'b0;
        end else begin
            btn_u_meta <= btn_u;
            btn_u_sync <= btn_u_meta;
            btn_u_prev <= btn_u_sync;
            hit_valid  <= btn_u_sync && !btn_u_prev;
        end
    end

    always_ff @(posedge clk_100M or posedge reset) begin
        if (reset) begin
            spawn_counter <= '0;
            spawn_tick <= 1'b0;
        end else begin
            spawn_tick <= 1'b0;
            if (spawn_counter == 29'd299_999_999) begin
                spawn_counter <= '0;
                spawn_tick <= 1'b1;
            end else begin
                spawn_counter <= spawn_counter + 1'b1;
            end
        end
    end

endmodule

module mux_2x1 #(
    parameter PORT_WIDTH = 12
) (
    input  logic                  sel,
    input  logic [PORT_WIDTH-1:0] x0,
    input  logic [PORT_WIDTH-1:0] x1,
    output logic [PORT_WIDTH-1:0] y
);
    assign y = sel ? x1 : x0;
endmodule


module demux_2x1 #(
    parameter PORT_WIDTH = 12
) (
    input  logic                  sel,
    input  logic [PORT_WIDTH-1:0] y,
    output logic [PORT_WIDTH-1:0] x0,
    output logic [PORT_WIDTH-1:0] x1
);
    always_comb begin
        case (sel)
            1'b0: begin
                x0 = y;
                x1 = 0;
            end
            1'b1: begin
                x1 = y;
                x0 = 0;
            end
            default: begin
                x0 = y;
                x1 = 0;
            end
        endcase
    end
endmodule
