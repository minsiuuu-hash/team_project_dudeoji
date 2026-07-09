`timescale 1ns / 1ps

module tb_MoleGameController;
    localparam int AREA_COUNT = 9;
    localparam int SCORE_WIDTH = 16;
    localparam logic [1:0] COLOR_RED = 2'd1;
    localparam logic [1:0] COLOR_BLUE = 2'd2;
    localparam logic [1:0] COLOR_GREEN = 2'd3;

    logic clk;
    logic reset;
    logic enable;
    logic spawn_tick;
    logic hit_valid;
    logic [$clog2(AREA_COUNT)-1:0] hit_area;
    logic [AREA_COUNT-1:0] camera_exist;
    logic [AREA_COUNT*2-1:0] camera_color;
    logic [AREA_COUNT-1:0] random_exist;
    logic [AREA_COUNT-1:0] final_exist;
    logic [AREA_COUNT*3-1:0] final_type;
    logic [SCORE_WIDTH-1:0] score;
    logic game_over;
    logic hit_scored;
    logic hit_gameover;

    MoleGameController #(
        .AREA_COUNT(AREA_COUNT),
        .SCORE_WIDTH(SCORE_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .spawn_tick(spawn_tick),
        .hit_valid(hit_valid),
        .hit_area(hit_area),
        .camera_exist(camera_exist),
        .camera_color(camera_color),
        .random_exist(random_exist),
        .final_exist(final_exist),
        .final_type(final_type),
        .score(score),
        .game_over(game_over),
        .hit_scored(hit_scored),
        .hit_gameover(hit_gameover)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic hit(input logic [$clog2(AREA_COUNT)-1:0] area);
        begin
            @(negedge clk);
            hit_area = area;
            hit_valid = 1'b1;
            @(negedge clk);
            hit_valid = 1'b0;
        end
    endtask

    function automatic logic [$clog2(AREA_COUNT)-1:0] first_active(input logic [AREA_COUNT-1:0] value);
        first_active = '0;
        for (int i = 0; i < AREA_COUNT; i++) begin
            if (value[i]) first_active = i[$clog2(AREA_COUNT)-1:0];
        end
    endfunction

    initial begin
        reset = 1'b1;
        enable = 1'b1;
        spawn_tick = 1'b0;
        hit_valid = 1'b0;
        hit_area = '0;
        camera_exist = '0;
        camera_color = '0;

        repeat (3) @(negedge clk);
        reset = 1'b0;

        @(negedge clk);
        spawn_tick = 1'b1;
        @(negedge clk);
        spawn_tick = 1'b0;
        hit(first_active(random_exist));
        @(posedge clk);
        if (score != 16'd1) $fatal(1, "basic mole score failed: %0d", score);

        camera_exist[2] = 1'b1;
        camera_color[2*2 +: 2] = COLOR_RED;
        hit(2);
        @(posedge clk);
        if (score != 16'd4) $fatal(1, "red mole score failed: %0d", score);

        hit(2);
        @(posedge clk);
        if (score != 16'd4) $fatal(1, "camera repeat mask failed: %0d", score);

        camera_exist = '0;
        @(negedge clk);
        camera_exist[4] = 1'b1;
        camera_color[4*2 +: 2] = COLOR_BLUE;
        hit(4);
        @(posedge clk);
        if (score != 16'd9) $fatal(1, "blue mole score failed: %0d", score);

        camera_exist = '0;
        @(negedge clk);
        camera_exist[5] = 1'b1;
        camera_color[5*2 +: 2] = COLOR_GREEN;
        hit(5);
        @(posedge clk);
        if (!game_over || !hit_gameover) $fatal(1, "green mole game over failed");

        $display("tb_MoleGameController PASS");
        $finish;
    end
endmodule
