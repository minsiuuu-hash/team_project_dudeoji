`timescale 1ns / 1ps

module tb_ov7670_capture_y;
    localparam int H_RES = 4;
    localparam int V_RES = 8;

    logic pclk = 1'b0;
    logic reset = 1'b1;
    logic href = 1'b0;
    logic vsync = 1'b0;
    logic [7:0] pdata = 8'd0;
    logic pixel_valid;
    logic [$clog2(H_RES)-1:0] pixel_x;
    logic [$clog2(V_RES)-1:0] pixel_y;
    logic [15:0] pixel_rgb565;
    logic frame_done;
    logic fb_we;
    logic [$clog2(H_RES*V_RES)-1:0] fb_waddr;
    logic [15:0] fb_wdata;

    always #5 pclk = ~pclk;

    ov7670_capture #(.H_RES(H_RES), .V_RES(V_RES)) dut (.*);

    task automatic send_pixel(input int expected_y);
        @(negedge pclk);
        href = 1'b1;
        pdata = 8'h12;
        @(negedge pclk);
        pdata = 8'h34;
        @(posedge pclk);
        #1;
        if (!pixel_valid || pixel_y !== expected_y)
            $fatal(1, "pixel Y: expected %0d, got %0d", expected_y, pixel_y);
    endtask

    task automatic end_line(input int expected_y);
        @(negedge pclk);
        href = 1'b0;
        @(posedge pclk);
        #1;
        if (pixel_y !== expected_y)
            $fatal(1, "HREF falling edge: expected Y=%0d, got %0d", expected_y, pixel_y);
        repeat (2) @(posedge pclk);
        #1;
        if (pixel_y !== expected_y)
            $fatal(1, "Y changed during blanking: expected %0d, got %0d", expected_y, pixel_y);
    endtask

    initial begin
        repeat (2) @(negedge pclk);
        reset = 1'b0;

        for (int row = 0; row < 3; row++) begin
            for (int col = 0; col < H_RES; col++)
                send_pixel(row);
            if (pixel_y !== row)
                $fatal(1, "Y advanced on the last pixel of row %0d", row);
            end_line(row + 1);
        end

        @(negedge pclk);
        vsync = 1'b1;
        @(posedge pclk);
        #1;
        if (pixel_y !== 0 || !frame_done)
            $fatal(1, "VSYNC did not reset Y");
        @(negedge pclk);
        vsync = 1'b0;

        send_pixel(0);
        end_line(1);
        send_pixel(1);

        $display("PASS: capture Y advances once per HREF falling edge");
        $finish;
    end
endmodule
