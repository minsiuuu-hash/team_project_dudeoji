`timescale 1ns / 1ps

module special_mole_event_generator #(
    parameter int CLK_HZ = 100_000_000,
    parameter int COOLDOWN_MS = 500
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [5:0] stable_red,
    input  logic [5:0] stable_green,
    input  logic [5:0] stable_blue,
    input  logic       tx_busy,
    output logic       event_valid,
    output logic [7:0] event_type,
    output logic [7:0] event_area
);
    localparam int COOLDOWN_CYCLES = (CLK_HZ / 1000) * COOLDOWN_MS;

    logic [31:0] cooldown [0:17];
    logic [4:0]  selected_idx;
    logic [7:0]  selected_type;
    logic [7:0]  selected_area;
    logic        found;

    function automatic int cd_index(input int color, input int area);
        begin
            cd_index = color * 6 + area;
        end
    endfunction

    always_comb begin
        found        = 1'b0;
        selected_idx = 5'd0;
        selected_type = 8'h00;
        selected_area = 8'h00;

        for (int area = 0; area < 6; area++) begin
            if (!found && stable_green[area] && cooldown[cd_index(0, area)] == 0) begin
                found        = 1'b1;
                selected_idx = cd_index(0, area);
                selected_type = 8'h02;
                selected_area = area[7:0];
            end
        end
        for (int area = 0; area < 6; area++) begin
            if (!found && stable_red[area] && cooldown[cd_index(1, area)] == 0) begin
                found        = 1'b1;
                selected_idx = cd_index(1, area);
                selected_type = 8'h01;
                selected_area = area[7:0];
            end
        end
        for (int area = 0; area < 6; area++) begin
            if (!found && stable_blue[area] && cooldown[cd_index(2, area)] == 0) begin
                found        = 1'b1;
                selected_idx = cd_index(2, area);
                selected_type = 8'h03;
                selected_area = area[7:0];
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            event_valid <= 1'b0;
            event_type  <= 8'h00;
            event_area  <= 8'h00;
            for (int i = 0; i < 18; i++) begin
                cooldown[i] <= 32'd0;
            end
        end else begin
            event_valid <= 1'b0;
            for (int i = 0; i < 18; i++) begin
                if (cooldown[i] != 0) begin
                    cooldown[i] <= cooldown[i] - 1'b1;
                end
            end

            if (found && !tx_busy && !event_valid) begin
                event_valid <= 1'b1;
                event_type  <= selected_type;
                event_area  <= selected_area;
                cooldown[selected_idx] <= COOLDOWN_CYCLES[31:0];
            end
        end
    end
endmodule
