`timescale 1ns / 1ps

module sprite_renderer #(
    parameter string NORMAL_FILE = "normal_96x96.mem",
    parameter string RED_FILE    = "red_96x96.mem",
    parameter string GREEN_FILE  = "green_96x96.mem",
    parameter string BLUE_FILE   = "blue_96x96.mem"
) (
    input  logic       clk,
    input  logic [2:0] mole_type,
    input  logic [6:0] sprite_x,   // 0-95
    input  logic [6:0] sprite_y,   // 0-95
    output logic [11:0] rgb,
    output logic        opaque
);
    localparam logic [2:0] MOLE_NORMAL = 3'd1;
    localparam logic [2:0] MOLE_RED    = 3'd2;
    localparam logic [2:0] MOLE_GREEN  = 3'd3;
    localparam logic [2:0] MOLE_BLUE   = 3'd4;

    localparam int ADDR_W = 14; // 96*96 = 9216, needs 14 bits

    logic [ADDR_W-1:0] addr;
    logic [11:0] normal_rgb;
    logic [11:0] red_rgb;
    logic [11:0] green_rgb;
    logic [11:0] blue_rgb;

    assign addr = ({7'd0, sprite_y} * 14'd96) + {7'd0, sprite_x};

    image_rom #(.ADDR_W(ADDR_W), .MEM_FILE(NORMAL_FILE)) U_normal (.clk(clk), .addr(addr), .rgb(normal_rgb));
    image_rom #(.ADDR_W(ADDR_W), .MEM_FILE(RED_FILE))    U_red    (.clk(clk), .addr(addr), .rgb(red_rgb));
    image_rom #(.ADDR_W(ADDR_W), .MEM_FILE(GREEN_FILE))  U_green  (.clk(clk), .addr(addr), .rgb(green_rgb));
    image_rom #(.ADDR_W(ADDR_W), .MEM_FILE(BLUE_FILE))   U_blue   (.clk(clk), .addr(addr), .rgb(blue_rgb));

    always_comb begin
        case (mole_type)
            MOLE_NORMAL: rgb = normal_rgb;
            MOLE_RED:    rgb = red_rgb;
            MOLE_GREEN:  rgb = green_rgb;
            MOLE_BLUE:   rgb = blue_rgb;
            default:     rgb = 12'h000;
        endcase
        opaque = (mole_type != 3'd0) && (rgb != 12'hF0F);
    end
endmodule
