`timescale 1ns / 1ps

module ov7670_capture #(
    parameter int H_RES = 320,
    parameter int V_RES = 240
) (
    input  logic                       pclk,
    input  logic                       reset,
    input  logic                       href,
    input  logic                       vsync,
    input  logic [7:0]                 pdata,
    output logic                       pixel_valid,
    output logic [$clog2(H_RES)-1:0]   pixel_x,
    output logic [$clog2(V_RES)-1:0]   pixel_y,
    output logic [15:0]                pixel_rgb565,
    output logic                       frame_done,
    output logic                       fb_we,
    output logic [$clog2(H_RES*V_RES)-1:0] fb_waddr,
    output logic [15:0]                fb_wdata
);
    logic        byte_phase;
    logic [7:0]  first_byte;
    logic [$clog2(H_RES)-1:0] x_cnt;
    logic [$clog2(V_RES)-1:0] y_cnt;
    logic vsync_d;
    logic href_d;

    assign pixel_x = x_cnt;
    assign pixel_y = y_cnt;
    assign fb_we = pixel_valid;
    assign fb_wdata = pixel_rgb565;

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            byte_phase   <= 1'b0;
            first_byte   <= 8'd0;
            x_cnt        <= '0;
            y_cnt        <= '0;
            pixel_rgb565 <= 16'd0;
            pixel_valid  <= 1'b0;
            frame_done   <= 1'b0;
            fb_waddr     <= '0;
            vsync_d      <= 1'b0;
            href_d       <= 1'b0;
        end else begin
            pixel_valid <= 1'b0;
            frame_done  <= 1'b0;
            vsync_d     <= vsync;
            href_d      <= href;

            if (vsync && !vsync_d) begin
                x_cnt      <= '0;
                y_cnt      <= '0;
                fb_waddr   <= '0;
                byte_phase <= 1'b0;
                frame_done <= 1'b1;
            end else if (href) begin
                if (!byte_phase) begin
                    first_byte <= pdata;
                    byte_phase <= 1'b1;
                end else begin
                    byte_phase   <= 1'b0;
                    pixel_rgb565 <= {first_byte, pdata};

                    if ((x_cnt < H_RES) && (y_cnt < V_RES)) begin
                        pixel_valid <= 1'b1;
                        fb_waddr    <= fb_waddr + 1'b1;
                    end

                    if (x_cnt == H_RES - 1) begin
                        x_cnt <= '0;
                    end else begin
                        x_cnt <= x_cnt + 1'b1;
                    end
                end
            end else begin
                byte_phase <= 1'b0;
                if (href_d) begin
                    x_cnt <= '0;
                    // Advance the row only when HREF falls, including full-width lines.
                    if (y_cnt != V_RES - 1) begin
                        y_cnt <= y_cnt + 1'b1;
                    end
                end
            end
        end
    end
endmodule

