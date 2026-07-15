`timescale 1ns / 1ps

module camera_area_debug_renderer (
    input  logic       de,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [15:0] fb_rgb565,
    input  logic [5:0] stable_red,
    input  logic [5:0] stable_green,
    input  logic [5:0] stable_blue,
    output logic [$clog2(320*240)-1:0] fb_raddr,
    output logic [11:0] rgb
);
    logic [8:0] cam_x;
    logic [7:0] cam_y;
    logic [2:0] area;
    logic [9:0] local_x;
    logic [9:0] local_y;
    logic grid_line;
    logic border_line;
    logic [11:0] border_rgb;

    assign cam_x = x_pixel[9:1];
    assign cam_y = y_pixel[8:1];
    assign fb_raddr = ({9'd0, cam_y} << 8) + ({9'd0, cam_y} << 6) + cam_x;

    always_comb begin
        if (cam_y < 8'd120) begin
            if (cam_x < 9'd106) begin
                area = 3'd0;
                local_x = cam_x;
            end else if (cam_x < 9'd213) begin
                area = 3'd1;
                local_x = cam_x - 9'd106;
            end else begin
                area = 3'd2;
                local_x = cam_x - 9'd213;
            end
            local_y = cam_y;
        end else begin
            if (cam_x < 9'd106) begin
                area = 3'd3;
                local_x = cam_x;
            end else if (cam_x < 9'd213) begin
                area = 3'd4;
                local_x = cam_x - 9'd106;
            end else begin
                area = 3'd5;
                local_x = cam_x - 9'd213;
            end
            local_y = cam_y - 8'd120;
        end

        grid_line = (cam_x == 9'd106) || (cam_x == 9'd107) ||
                    (cam_x == 9'd213) || (cam_x == 9'd214) ||
                    (cam_y == 8'd120) || (cam_y == 8'd121);

        border_line = (local_x < 10'd3) || (local_x > 10'd102) ||
                      (local_y < 10'd3) || (local_y > 10'd116);

        if (stable_green[area]) begin
            border_rgb = 12'h0F0;
        end else if (stable_red[area]) begin
            border_rgb = 12'hF00;
        end else if (stable_blue[area]) begin
            border_rgb = 12'h04F;
        end else begin
            border_rgb = 12'hFFF;
        end

        if (!de) begin
            rgb = 12'h000;
        end else if (border_line && (stable_red[area] || stable_green[area] || stable_blue[area])) begin
            rgb = border_rgb;
        end else if (grid_line) begin
            rgb = 12'hFFF;
        end else begin
            rgb = {fb_rgb565[15:12], fb_rgb565[10:7], fb_rgb565[4:1]};
        end
    end
endmodule

