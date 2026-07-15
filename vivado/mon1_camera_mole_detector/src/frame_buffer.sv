`timescale 1ns / 1ps

module frame_buffer #(
    parameter int H_RES = 320,
    parameter int V_RES = 240,
    parameter int DATA_W = 16
) (
    input  logic                         wclk,
    input  logic                         we,
    input  logic [$clog2(H_RES*V_RES)-1:0] waddr,
    input  logic [DATA_W-1:0]            wdata,
    input  logic                         rclk,
    input  logic [$clog2(H_RES*V_RES)-1:0] raddr,
    output logic [DATA_W-1:0]            rdata
);
    (* ram_style = "block" *) logic [DATA_W-1:0] mem [0:H_RES*V_RES-1];

    always_ff @(posedge wclk) begin
        if (we) begin
            mem[waddr] <= wdata;
        end
    end

    always_ff @(posedge rclk) begin
        rdata <= mem[raddr];
    end
endmodule

