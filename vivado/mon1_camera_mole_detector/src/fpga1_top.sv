`timescale 1ns / 1ps

module fpga1_top (
    input  logic       clk,
    input  logic       reset,

    output logic       cam_xclk,
    input  logic       cam_pclk,
    input  logic       cam_href,
    input  logic       cam_vsync,
    input  logic [7:0] cam_data,
    output logic       cam_scl,
    inout  logic       cam_sda,

    output logic       uart_tx,
    input  logic       uart_rx,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] vga_red,
    output logic [3:0] vga_green,
    output logic [3:0] vga_blue,
    output logic [5:0] led_area
);
    logic [1:0] xclk_div;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            xclk_div <= 2'd0;
        end else begin
            xclk_div <= xclk_div + 1'b1;
        end
    end

    assign cam_xclk = xclk_div[1];

    logic pixel_valid;
    logic [8:0] pixel_x;
    logic [7:0] pixel_y;
    logic [15:0] pixel_rgb565;
    logic frame_done_pclk;
    logic fb_we;
    logic [$clog2(320*240)-1:0] fb_waddr;
    logic [15:0] fb_wdata;

    ov7670_capture U_capture (
        .pclk(cam_pclk),
        .reset(reset),
        .href(cam_href),
        .vsync(cam_vsync),
        .pdata(cam_data),
        .pixel_valid(pixel_valid),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_rgb565(pixel_rgb565),
        .frame_done(frame_done_pclk),
        .fb_we(fb_we),
        .fb_waddr(fb_waddr),
        .fb_wdata(fb_wdata)
    );

    logic pixel_ce;
    logic de;
    logic [9:0] vga_x;
    logic [9:0] vga_y;

    vga_controller U_vga (
        .clk(clk),
        .reset(reset),
        .pixel_ce(pixel_ce),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .x_pixel(vga_x),
        .y_pixel(vga_y),
        .de(de)
    );

    logic [$clog2(320*240)-1:0] fb_raddr;
    logic [15:0] fb_rdata;

    frame_buffer U_frame_buffer (
        .wclk(cam_pclk),
        .we(fb_we),
        .waddr(fb_waddr),
        .wdata(fb_wdata),
        .rclk(clk),
        .raddr(fb_raddr),
        .rdata(fb_rdata)
    );

    logic [11:0] debug_rgb;

    logic [5:0] frame_red_pclk;
    logic [5:0] frame_green_pclk;
    logic [5:0] frame_blue_pclk;
    logic result_valid_pclk;
    logic hsv_valid;
    logic [9:0] hsv_x;
    logic [9:0] hsv_y;
    logic [7:0] hsv_h;
    logic [7:0] hsv_s;
    logic [7:0] hsv_v;
    logic [5:0] frame_done_pipe;

    HSV U_HSV (
        .clk(cam_pclk),
        .reset(reset),
        .DE_in(pixel_valid),
        .x_in({1'b0, pixel_x}),
        .y_in({2'b00, pixel_y}),
        .R(pixel_rgb565[15:12]),
        .G(pixel_rgb565[10:7]),
        .B(pixel_rgb565[4:1]),
        .DE_out(hsv_valid),
        .x_out(hsv_x),
        .y_out(hsv_y),
        .H(hsv_h),
        .S(hsv_s),
        .V(hsv_v)
    );

    always_ff @(posedge cam_pclk or posedge reset) begin
        if (reset) begin
            frame_done_pipe <= 6'd0;
        end else begin
            frame_done_pipe <= {frame_done_pipe[4:0], frame_done_pclk};
        end
    end

    area_color_detector U_detector (
        .pclk(cam_pclk),
        .reset(reset),
        .pixel_valid(hsv_valid),
        .pixel_x(hsv_x[8:0]),
        .pixel_y(hsv_y[7:0]),
        .H(hsv_h),
        .S(hsv_s),
        .V(hsv_v),
        .frame_done(frame_done_pipe[5]),
        .frame_red(frame_red_pclk),
        .frame_green(frame_green_pclk),
        .frame_blue(frame_blue_pclk),
        .frame_result_valid(result_valid_pclk)
    );

    logic result_toggle_pclk;
    logic result_valid_pclk_d;

    always_ff @(posedge cam_pclk or posedge reset) begin
        if (reset) begin
            result_toggle_pclk <= 1'b0;
            result_valid_pclk_d <= 1'b0;
        end else begin
            result_valid_pclk_d <= result_valid_pclk;
            if (result_valid_pclk && !result_valid_pclk_d) begin
                result_toggle_pclk <= ~result_toggle_pclk;
            end
        end
    end

    logic [2:0] result_sync;
    logic [5:0] frame_red_clk;
    logic [5:0] frame_green_clk;
    logic [5:0] frame_blue_clk;
    logic frame_valid_clk;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            result_sync     <= 3'd0;
            frame_red_clk   <= 6'd0;
            frame_green_clk <= 6'd0;
            frame_blue_clk  <= 6'd0;
            frame_valid_clk <= 1'b0;
        end else begin
            result_sync <= {result_sync[1:0], result_toggle_pclk};
            frame_valid_clk <= result_sync[2] ^ result_sync[1];
            if (result_sync[2] ^ result_sync[1]) begin
                frame_red_clk   <= frame_red_pclk;
                frame_green_clk <= frame_green_pclk;
                frame_blue_clk  <= frame_blue_pclk;
            end
        end
    end

    logic [5:0] stable_red;
    logic [5:0] stable_green;
    logic [5:0] stable_blue;

    color_event_filter U_filter (
        .clk(clk),
        .reset(reset),
        .frame_valid(frame_valid_clk),
        .frame_red(frame_red_clk),
        .frame_green(frame_green_clk),
        .frame_blue(frame_blue_clk),
        .stable_red(stable_red),
        .stable_green(stable_green),
        .stable_blue(stable_blue)
    );

    logic event_valid;
    logic [7:0] event_type;
    logic [7:0] event_area;
    logic tx_busy;
    logic [7:0] last_event_type;
    logic [2:0] last_event_area;

    special_mole_event_generator U_event_gen (
        .clk(clk),
        .reset(reset),
        .stable_red(stable_red),
        .stable_green(stable_green),
        .stable_blue(stable_blue),
        .tx_busy(tx_busy),
        .event_valid(event_valid),
        .event_type(event_type),
        .event_area(event_area)
    );

    uart_packet_tx U_packet_tx (
        .clk(clk),
        .reset(reset),
        .event_valid(event_valid),
        .mole_type(event_type),
        .area(event_area),
        .uart_tx_o(uart_tx),
        .busy(tx_busy)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            last_event_type <= 8'h00;
            last_event_area <= 3'd0;
        end else if (event_valid) begin
            last_event_type <= event_type;
            last_event_area <= event_area[2:0];
        end
    end

    assign led_area = {
        last_event_area,
        (last_event_type == 8'h03),
        (last_event_type == 8'h02),
        (last_event_type == 8'h01)
    };

    camera_area_debug_renderer U_debug_renderer (
        .de(de),
        .x_pixel(vga_x),
        .y_pixel(vga_y),
        .fb_rgb565(fb_rdata),
        .stable_red(stable_red),
        .stable_green(stable_green),
        .stable_blue(stable_blue),
        .fb_raddr(fb_raddr),
        .rgb(debug_rgb)
    );

    assign {vga_red, vga_green, vga_blue} = debug_rgb;

    logic cam_start;
    logic cam_done;
    logic cam_start_fired;

    OV7670_config_top #(
        .CAM_WADDR(8'h42)
    ) U_camera_config (
        .clk(clk),
        .rst(reset),
        .start(cam_start),
        .done(cam_done),
        .scl(cam_scl),
        .sda(cam_sda)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cam_start       <= 1'b0;
            cam_start_fired <= 1'b0;
        end else begin
            cam_start <= 1'b0;
            if (!cam_start_fired) begin
                cam_start       <= 1'b1;
                cam_start_fired <= 1'b1;
            end
        end
    end

    logic [7:0] unused_rx_data;
    logic       unused_rx_valid;

    uart_rx U_future_rx (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .rx_data(unused_rx_data),
        .rx_valid(unused_rx_valid)
    );
endmodule
