`timescale 1ns / 1ps

module camera_vga_reader #(
    parameter int H_RES = 320,
    parameter int V_RES = 240
) (
    input  logic [9:0] vga_x,
    input  logic [9:0] vga_y,
    input  logic       vga_de,
    output logic [$clog2(H_RES*V_RES)-1:0] fb_raddr,
    input  logic [15:0] fb_rdata,
    output logic [11:0] rgb444
);
    logic [$clog2(H_RES)-1:0] cam_x;
    logic [$clog2(V_RES)-1:0] cam_y;

    assign cam_x = vga_x[9:1];
    assign cam_y = vga_y[8:1];
    assign fb_raddr = cam_y * H_RES + cam_x;

    always_comb begin
        if (!vga_de) begin
            rgb444 = 12'h000;
        end else begin
            rgb444 = {fb_rdata[15:12], fb_rdata[10:7], fb_rdata[4:1]};
        end
    end
endmodule

