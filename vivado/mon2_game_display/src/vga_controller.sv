`timescale 1ns / 1ps

module vga_controller (
    input  logic       clk,
    input  logic       reset,
    output logic       pixel_ce,
    output logic       h_sync,
    output logic       v_sync,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel,
    output logic       de
);
    localparam int H_VISIBLE = 640;
    localparam int H_FRONT   = 16;
    localparam int H_SYNC    = 96;
    localparam int H_BACK    = 48;
    localparam int H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
    localparam int V_VISIBLE = 480;
    localparam int V_FRONT   = 10;
    localparam int V_SYNC    = 2;
    localparam int V_BACK    = 33;
    localparam int V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    logic [1:0] ce_count;
    logic [9:0] h_count;
    logic [9:0] v_count;

    always_ff @(posedge clk) begin
        if (reset) begin
            ce_count <= 2'd0;
            pixel_ce <= 1'b0;
        end else begin
            pixel_ce <= (ce_count == 2'd3);
            ce_count <= ce_count + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (pixel_ce) begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    always_comb begin
        h_sync = !((h_count >= H_VISIBLE + H_FRONT) && (h_count < H_VISIBLE + H_FRONT + H_SYNC));
        v_sync = !((v_count >= V_VISIBLE + V_FRONT) && (v_count < V_VISIBLE + V_FRONT + V_SYNC));
        de = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
        x_pixel = h_count;
        y_pixel = v_count;
    end
endmodule
