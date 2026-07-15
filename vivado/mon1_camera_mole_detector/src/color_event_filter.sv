`timescale 1ns / 1ps

module color_event_filter (
    input  logic       clk,
    input  logic       reset,
    input  logic       frame_valid,
    input  logic [5:0] frame_red,
    input  logic [5:0] frame_green,
    input  logic [5:0] frame_blue,
    output logic [5:0] stable_red,
    output logic [5:0] stable_green,
    output logic [5:0] stable_blue
);
    logic [1:0] red_cnt   [0:5];
    logic [1:0] green_cnt [0:5];
    logic [1:0] blue_cnt  [0:5];

    function automatic logic [1:0] next_count(input logic present, input logic [1:0] count);
        begin
            if (!present) begin
                next_count = 2'd0;
            end else if (count == 2'd3) begin
                next_count = 2'd3;
            end else begin
                next_count = count + 1'b1;
            end
        end
    endfunction

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            stable_red   <= 6'd0;
            stable_green <= 6'd0;
            stable_blue  <= 6'd0;
            for (int i = 0; i < 6; i++) begin
                red_cnt[i]   <= 2'd0;
                green_cnt[i] <= 2'd0;
                blue_cnt[i]  <= 2'd0;
            end
        end else if (frame_valid) begin
            for (int i = 0; i < 6; i++) begin
                red_cnt[i]   <= next_count(frame_red[i], red_cnt[i]);
                green_cnt[i] <= next_count(frame_green[i], green_cnt[i]);
                blue_cnt[i]  <= next_count(frame_blue[i], blue_cnt[i]);

                stable_red[i]   <= frame_red[i]   && (red_cnt[i]   >= 2'd2);
                stable_green[i] <= frame_green[i] && (green_cnt[i] >= 2'd2);
                stable_blue[i]  <= frame_blue[i]  && (blue_cnt[i]  >= 2'd2);
            end
        end
    end
endmodule

