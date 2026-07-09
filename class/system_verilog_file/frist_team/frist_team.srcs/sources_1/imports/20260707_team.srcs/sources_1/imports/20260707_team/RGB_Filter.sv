`timescale 1ns / 1ps

module RGB_Filter (
    input  logic [11:0] rgb_data,
    input  logic [ 2:0] sw,
    output logic [11:0] colors
);


    logic [3:0] red, green, blue;

    assign red   = rgb_data[11:8];
    assign green = rgb_data[7:4];
    assign blue  = rgb_data[3:0];

    always_comb begin
        case (sw)
            3'b000: begin
                colors = rgb_data;
            end
            3'b100: begin
                colors = {red, 4'd0, 4'd0};
            end
            3'b110: begin
                colors = {red, green, 4'b0};
            end
            3'b010: begin
                colors = {4'd0, green, 4'd0};
            end
            3'b011: begin
                colors = {4'b0, green, blue};
            end
            3'b001: begin
                colors = {4'd0, 4'd0, blue};
            end
            3'b101: begin
                colors = {blue, red};
            end
            3'b111: begin
                colors = {red, green, blue};
            end
            default: colors = rgb_data;
        endcase


    end


endmodule
