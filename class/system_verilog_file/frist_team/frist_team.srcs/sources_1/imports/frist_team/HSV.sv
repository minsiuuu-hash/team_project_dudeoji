module HSV (
    input  wire       clk,
    input  wire       reset,
    input  wire       DE_in,
    input  wire [9:0] x_in,
    input  wire [9:0] y_in,
    input  wire [3:0] R,
    input  wire [3:0] G,
    input  wire [3:0] B,
    output reg        DE_out,
    output reg  [9:0] x_out,
    output reg  [9:0] y_out,
    output reg  [7:0] H,
    output reg  [7:0] S,
    output reg  [7:0] V
);
    // ============================================================
    // LUT 선언 및 초기화
    // ============================================================
    reg [7:0] s_lut[0:255];
    reg [7:0] h_lut[0:255];
    integer i, j;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                s_lut[i*16+j] = (j == 0) ? 8'd0 : (i * 255) / j;
                h_lut[i*16+j] = (j == 0) ? 8'd0 : (i * 42) / j;
            end
        end
    end
    // ============================================================
    // Stage 1: MAX / MIN / DELTA 계산
    // 6가지 대소관계를 완전히 명시 → cmax/cmin/delta 확정
    // H diff 계산은 Stage3에서 max_ch 기준으로 별도 처리
    // ============================================================
    reg [9:0] s1_x, s1_y;
    reg s1_DE;
    reg [3:0] s1_r, s1_g, s1_b;
    reg [3:0] s1_cmax, s1_cmin, s1_delta;
    reg [1:0] s1_max_ch;
    reg       s1_valid;
    reg [3:0] cmax_comb, cmin_comb;
    reg [1:0] max_ch_comb;
    always @(*) begin
        // 6가지 대소관계 완전 명시
        // 동점은 R>G>B 우선순위로 처리
        if (R >= G && G >= B) begin
            cmax_comb   = R;
            cmin_comb   = B;
            max_ch_comb = 2'd0;
        end else if (R >= B && B > G) begin
            cmax_comb   = R;
            cmin_comb   = G;
            max_ch_comb = 2'd0;
        end else if (G > R && R >= B) begin
            cmax_comb   = G;
            cmin_comb   = B;
            max_ch_comb = 2'd1;
        end else if (G >= B && B > R) begin
            cmax_comb   = G;
            cmin_comb   = R;
            max_ch_comb = 2'd1;
        end else if (B > R && R >= G) begin
            cmax_comb   = B;
            cmin_comb   = G;
            max_ch_comb = 2'd2;
        end else begin
            cmax_comb   = B;
            cmin_comb   = R;
            max_ch_comb = 2'd2;
        end
    end
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s1_r      <= 4'd0;
            s1_g      <= 4'd0;
            s1_b      <= 4'd0;
            s1_cmax   <= 4'd0;
            s1_cmin   <= 4'd0;
            s1_delta  <= 4'd0;
            s1_max_ch <= 2'd0;
            s1_x      <= 10'd0;
            s1_y      <= 10'd0;
            s1_DE     <= 1'd0;
        end else begin
            s1_x      <= x_in;
            s1_y      <= y_in;
            s1_DE     <= DE_in;
            s1_r      <= R;
            s1_g      <= G;
            s1_b      <= B;
            s1_cmax   <= cmax_comb;
            s1_cmin   <= cmin_comb;
            s1_max_ch <= max_ch_comb;
            s1_delta  <= cmax_comb - cmin_comb;
        end
    end
    // ============================================================
    // Stage 2: V, S 계산
    // ============================================================
    reg [9:0] s2_x, s2_y;
    reg s2_DE;
    reg [7:0] s2_v, s2_s;
    reg [3:0] s2_r, s2_g, s2_b;
    reg [3:0] s2_delta, s2_cmax;
    reg [1:0] s2_max_ch;
    reg       s2_valid;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s2_r      <= 4'd0;
            s2_g      <= 4'd0;
            s2_b      <= 4'd0;
            s2_delta  <= 4'd0;
            s2_cmax   <= 4'd0;
            s2_max_ch <= 2'd0;
            s2_v      <= 8'd0;
            s2_s      <= 8'd0;
            s2_x      <= 10'd0;
            s2_y      <= 10'd0;
            s2_DE     <= 1'd0;
        end else begin
            s2_x <= s1_x;
            s2_y <= s1_y;
            s2_DE <= s1_DE;
            s2_r <= s1_r;
            s2_g <= s1_g;
            s2_b <= s1_b;
            s2_delta <= s1_delta;
            s2_cmax <= s1_cmax;
            s2_max_ch <= s1_max_ch;
            // V: 삼항 연산자로 cmax 직접 판별
            // 명도
            s2_v <= (s1_r >= s1_g && s1_r >= s1_b) ? {s1_r, s1_r} :
                    (s1_g >= s1_r && s1_g >= s1_b) ? {s1_g, s1_g} :
                                                        {s1_b, s1_b};
            // S: LUT 조회
            //채도
            s2_s <= (s1_cmax == 4'd0) ? 8'd0 : s_lut[{s1_delta, s1_cmax}];
        end
    end
    // ============================================================
    // Stage 3: H 계산
    // diff는 max_ch 기준으로 원래 공식 그대로 유지
    //   R max: diff = G - B
    //   G max: diff = B - R
    //   B max: diff = R - G
    // ============================================================
    reg [9:0] s3_x, s3_y;
    reg s3_DE;
    reg [7:0] s3_h, s3_s, s3_v;
    reg s3_valid;
    wire [3:0] diff_gb = (s2_g >= s2_b) ? (s2_g - s2_b) : (s2_b - s2_g);
    wire sign_gb_neg = (s2_g < s2_b);
    wire [3:0] diff_br = (s2_b >= s2_r) ? (s2_b - s2_r) : (s2_r - s2_b);
    wire sign_br_neg = (s2_b < s2_r);
    wire [3:0] diff_rg = (s2_r >= s2_g) ? (s2_r - s2_g) : (s2_g - s2_r);
    wire sign_rg_neg = (s2_r < s2_g);
    wire [7:0] h_gb = h_lut[{diff_gb, s2_delta}];
    wire [7:0] h_br = h_lut[{diff_br, s2_delta}];
    wire [7:0] h_rg = h_lut[{diff_rg, s2_delta}];
    wire [8:0] h_r_raw = sign_gb_neg ? (9'd256 - {1'b0, h_gb}) : {1'b0, h_gb};
    wire [8:0] h_g_raw = sign_br_neg ? (9'd85 + 9'd256 - {1'b0, h_br}) : (9'd85 + {1'b0, h_br});
    wire [8:0] h_b_raw = sign_rg_neg ? (9'd171 + 9'd256 - {1'b0, h_rg}) : (9'd171 + {1'b0, h_rg});
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            s3_h  <= 8'd0;
            s3_s  <= 8'd0;
            s3_v  <= 8'd0;
            s3_x  <= 10'd0;
            s3_y  <= 10'd0;
            s3_DE <= 1'd0;
        end else begin
            s3_x  <= s2_x;
            s3_y  <= s2_y;
            s3_DE <= s2_DE;
            s3_s  <= s2_s;
            s3_v  <= s2_v;
            if (s2_delta == 4'd0) begin
                s3_h <= 8'd0;
            end else begin
                case (s2_max_ch)
                    2'd0:    s3_h <= h_r_raw[7:0];
                    2'd1:    s3_h <= h_g_raw[7:0];
                    2'd2:    s3_h <= h_b_raw[7:0];
                    default: s3_h <= 8'd0;
                endcase
            end
        end
    end
    // ============================================================
    // Stage 4: 출력 래치
    // ============================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            H <= 8'd0;
            S <= 8'd0;
            V <= 8'd0;
            DE_out <= 1'd0;
            x_out <= 10'd0;
            y_out <= 10'd0;
        end else begin
            DE_out    <= s3_DE;
            x_out    <= s3_x;
            y_out    <= s3_y;
            H <= s3_h;
            S <= s3_s;
            V <= s3_v;
        end
    end
endmodule