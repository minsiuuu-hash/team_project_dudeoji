`timescale 1ns / 1ps

module fpga2_top (
    input  logic       clk,
    input  logic       reset,
    input  logic       start_btn,
    input  logic       restart_btn,
    input  logic [5:0] hit_btn,
    input  logic       uart_rx_i,
    output logic       uart_tx_o,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] vga_red,
    output logic [3:0] vga_green,
    output logic [3:0] vga_blue,
    output logic [5:0] led
);
    logic tick_ms;
    tick_gen U_tick (.clk(clk), .reset(reset), .tick_ms(tick_ms));

    logic [7:0] rx_data;
    logic rx_valid;
    uart_rx U_uart_rx (.clk(clk), .reset(reset), .rx(uart_rx_i), .rx_data(rx_data), .rx_valid(rx_valid));

    logic packet_event_valid;
    logic [7:0] packet_type;
    logic [7:0] packet_area;
    logic packet_ready;
    logic packet_error;
    uart_packet_rx U_packet_rx (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .rx_valid(rx_valid),
        .event_ready(packet_ready),
        .event_valid(packet_event_valid),
        .event_type(packet_type),
        .event_area(packet_area),
        .packet_error(packet_error)
    );

    logic [7:0] raw_buttons;
    logic [7:0] debounced_buttons;
    logic [7:0] button_pulse;
    assign raw_buttons = {restart_btn, start_btn, hit_btn};

    button_debounce #(.WIDTH(8)) U_debounce (.clk(clk), .reset(reset), .raw_btn(raw_buttons), .debounced(debounced_buttons));
    button_onepulse #(.WIDTH(8)) U_onepulse (.clk(clk), .reset(reset), .btn(debounced_buttons), .pulse(button_pulse));

    logic [5:0] hit_pulse;
    logic start_pulse;
    logic restart_pulse;
    assign hit_pulse = button_pulse[5:0];
    assign start_pulse = button_pulse[6];
    assign restart_pulse = button_pulse[7];

    logic hit_valid;
    logic [2:0] hit_area;
    always_comb begin
        hit_valid = |hit_pulse;
        if (hit_pulse[0]) hit_area = 3'd0;
        else if (hit_pulse[1]) hit_area = 3'd1;
        else if (hit_pulse[2]) hit_area = 3'd2;
        else if (hit_pulse[3]) hit_area = 3'd3;
        else if (hit_pulse[4]) hit_area = 3'd4;
        else hit_area = 3'd5;
    end

    logic [15:0] random;
    lfsr_random U_lfsr (.clk(clk), .reset(reset), .random(random));

    logic [2:0] game_state;
    logic stage_active;
    logic stage_load;
    logic game_reset_pulse;
    logic stage_done;
    logic [5:0] time_left;
    logic green_hit;
    logic score_underflow;
    logic [7:0] score;

    game_fsm U_fsm (
        .clk(clk),
        .reset(reset),
        .start_pulse(start_pulse),
        .restart_pulse(restart_pulse),
        .stage_done(stage_done),
        .green_hit(green_hit),
        .score_underflow(score_underflow),
        .score(score),
        .game_state(game_state),
        .stage_active(stage_active),
        .stage_load(stage_load),
        .game_reset_pulse(game_reset_pulse)
    );

    stage_timer U_stage_timer (
        .clk(clk),
        .reset(reset),
        .tick_ms(tick_ms),
        .stage_active(stage_active),
        .stage_load(stage_load),
        .stage_done(stage_done),
        .time_left(time_left)
    );

    logic [5:0] active_mask;
    logic [17:0] mole_type_flat;
    logic [5:0] hit_anim_mask;
    logic spawn_valid;
    logic [5:0] spawn_mask;
    logic [17:0] spawn_type_flat;

    mole_spawn_controller U_spawn (
        .clk(clk),
        .reset(reset),
        .tick_ms(tick_ms),
        .game_reset(game_reset_pulse),
        .game_state(game_state),
        .occupied(active_mask),
        .random(random),
        .special_valid(packet_event_valid),
        .special_type(packet_type),
        .special_area(packet_area),
        .special_ready(packet_ready),
        .spawn_valid(spawn_valid),
        .spawn_mask(spawn_mask),
        .spawn_type_flat(spawn_type_flat)
    );

    logic scored_hit_valid;
    logic [2:0] scored_mole_type;

    mole_state_manager U_mole_state (
        .clk(clk),
        .reset(reset),
        .tick_ms(tick_ms),
        .game_reset(game_reset_pulse),
        .game_state(game_state),
        .spawn_valid(spawn_valid),
        .spawn_mask(spawn_mask),
        .spawn_type_flat(spawn_type_flat),
        .hit_valid(hit_valid),
        .hit_area(hit_area),
        .active_mask(active_mask),
        .mole_type_flat(mole_type_flat),
        .hit_anim_mask(hit_anim_mask),
        .scored_hit_valid(scored_hit_valid),
        .scored_mole_type(scored_mole_type),
        .green_hit(green_hit)
    );

    score_controller U_score (
        .clk(clk),
        .reset(reset),
        .game_reset(game_reset_pulse),
        .hit_valid(scored_hit_valid),
        .hit_type(scored_mole_type),
        .score(score),
        .score_underflow(score_underflow)
    );

    logic pixel_ce;
    logic [9:0] x_pixel;
    logic [9:0] y_pixel;
    logic de;
    vga_controller U_vga (
        .clk(clk),
        .reset(reset),
        .pixel_ce(pixel_ce),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de(de)
    );

    logic [11:0] rgb;
    game_renderer U_renderer (
        .clk(clk),
        .de(de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .game_state(game_state),
        .score(score),
        .time_left(time_left),
        .mole_type_flat(mole_type_flat),
        .active_mask(active_mask),
        .hit_anim_mask(hit_anim_mask),
        .rgb(rgb)
    );

    assign {vga_red, vga_green, vga_blue} = rgb;
    assign led = active_mask;

    uart_tx U_future_tx (
        .clk(clk),
        .reset(reset),
        .tx_start(1'b0),
        .tx_data(8'd0),
        .tx(uart_tx_o),
        .busy()
    );
endmodule
