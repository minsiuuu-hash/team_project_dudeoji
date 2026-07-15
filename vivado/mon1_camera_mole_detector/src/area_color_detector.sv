`timescale 1ns / 1ps

module area_color_detector #(
    parameter int H_RES = 320,
    parameter int V_RES = 240,
    parameter int THRESHOLD = 550  //Accumulated number of pixels 
) (
    input  logic       pclk,
    input  logic       reset,
    input  logic       pixel_valid,
    input  logic [$clog2(H_RES)-1:0] pixel_x,
    input  logic [$clog2(V_RES)-1:0] pixel_y,
    input  logic [7:0] H,
    input  logic [7:0] S,
    input  logic [7:0] V,
    input  logic       frame_done,
    output logic [5:0] frame_red,
    output logic [5:0] frame_green,
    output logic [5:0] frame_blue,
    output logic       frame_result_valid
);
    localparam int AREA_W = H_RES / 3;
    localparam int AREA_H = V_RES / 2;

    logic [15:0] red_count   [0:5];
    logic [15:0] green_count [0:5];
    logic [15:0] blue_count  [0:5];
    logic [2:0]  area_idx;
    logic        is_red;
    logic        is_green;
    logic        is_blue;
    logic        vivid_pixel;

    always_comb begin
        if (pixel_y < AREA_H) begin
            if (pixel_x < AREA_W) begin
                area_idx = 3'd0;
            end else if (pixel_x < AREA_W * 2) begin
                area_idx = 3'd1;
            end else begin
                area_idx = 3'd2;
            end
        end else begin
            if (pixel_x < AREA_W) begin
                area_idx = 3'd3;
            end else if (pixel_x < AREA_W * 2) begin
                area_idx = 3'd4;
            end else begin
                area_idx = 3'd5;
            end
        end

        // Average for pixel
        vivid_pixel = (S >= 8'd115) && (V >= 8'd55);
        is_red      = vivid_pixel && (((H <= 8'd12) || (H >= 8'd244)));
        is_blue     = vivid_pixel && (H >= 8'd150) && (H <= 8'd205);
        // Wide for green area
        is_green    = (S >= 8'd60) && (V >= 8'd30) && (H >= 8'd50)  && (H <= 8'd125);
    end

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            frame_red          <= 6'd0;
            frame_green        <= 6'd0;
            frame_blue         <= 6'd0;
            frame_result_valid <= 1'b0;
            for (int i = 0; i < 6; i++) begin
                red_count[i]   <= 16'd0;
                green_count[i] <= 16'd0;
                blue_count[i]  <= 16'd0;
            end
        end else begin
            frame_result_valid <= 1'b0;

            if (pixel_valid) begin
                if (is_red && red_count[area_idx] != 16'hFFFF) begin
                    red_count[area_idx] <= red_count[area_idx] + 1'b1;
                end
                if (is_green && green_count[area_idx] != 16'hFFFF) begin
                    green_count[area_idx] <= green_count[area_idx] + 1'b1;
                end
                if (is_blue && blue_count[area_idx] != 16'hFFFF) begin
                    blue_count[area_idx] <= blue_count[area_idx] + 1'b1;
                end
            end

            if (frame_done) begin
                for (int i = 0; i < 6; i++) begin
                    frame_red[i]   <= (red_count[i] >= THRESHOLD);
                    frame_green[i] <= (green_count[i] >= THRESHOLD);
                    frame_blue[i]  <= (blue_count[i] >= THRESHOLD);
                    red_count[i]   <= 16'd0;
                    green_count[i] <= 16'd0;
                    blue_count[i]  <= 16'd0;
                end
                frame_result_valid <= 1'b1;
            end
        end
    end
endmodule
