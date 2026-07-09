`timescale 1ns / 1ps

module frameBuffer (
    // write side
    input  logic                       wclk,
    input  logic                       we,
    input  logic [$clog2(320*240)-1:0] wAddr,
    input  logic [               15:0] wData,
    // read side
    input  logic                       rclk,
    input  logic [$clog2(320*240)-1:0] rAddr,
    output logic [               15:0] rData
);
    logic [15:0] mem[0:(320*240)-1];

    // write side
    always_ff @(posedge wclk) begin
        if (we) mem[wAddr] <= wData;
    end

    // read side
    always_ff @(posedge rclk) begin
        rData <= mem[rAddr];
    end
    // assign rData = mem[rAddr];
endmodule
