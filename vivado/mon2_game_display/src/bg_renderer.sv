`timescale 1ns / 1ps
//
// bg_renderer_v2.sv
//
// FIXES from your version:
//   1. `addr` was declared as only 12 bits (logic [11:0]), but 320*240 =
//      76800 pixels needs 17 bits (2^17 = 131072). With 12 bits, addr
//      silently wrapped around every 4096 pixels - only the top-left
//      sliver of the image was ever addressed.
//   2. `logic [11:0] addr = (ly<<8)+(ly<<6)+lx;` at module scope is an
//      INITIAL VALUE, not a continuous assignment - it's evaluated once
//      at time 0 (when lx=ly=0) and never updates again as lx/ly change.
//      That's why the whole screen showed a single frozen pixel
//      (rom[0], happened to be sky-blue). Fixed with a proper
//      `assign` statement below.
//
module bg_renderer #(
    parameter BG_FILE = "background_320x240.mem"
) (
    input  logic        clk,
    input  logic [ 9:0] lx,
    input  logic [ 9:0] ly,
    output logic [11:0] rgb
);
    // 320 x 240 = 76,800 pixels -> needs 17 address bits (2^17 = 131072)
    localparam int SIZE = 320 * 240;
    localparam int ADDR_W = 17;

    (* rom_style = "block" *) logic [11:0] rom[0:SIZE-1];

    initial begin
        $readmemh(BG_FILE, rom);
    end

    logic [ADDR_W-1:0] addr;

    // proper continuous assignment - re-evaluates every time lx/ly change,
    // and widened correctly so it doesn't wrap around
    assign addr = (ly << 8) + (ly << 6) + lx;
    // assign addr = ({7'd0, ly} * 17'd320) + {7'd0, lx};

    assign rgb  = (lx < 320 && ly < 240) ? rom[addr] : 12'h000;
endmodule





// module bg_renderer #(
//     parameter BG_FILE = "background_320x240.mem"
// ) (
//     input logic clk,
//     input logic [9:0] lx,
//     input logic [9:0] ly,
//     output logic [11:0] rgb
// );
//     // 320 x 240 = 76,800
//     localparam SIZE = 320 * 240;
//     // (* rom_style = "block" *)
//     logic [11:0] rom[0:SIZE-1];

//     initial begin
//         $readmemh(BG_FILE, rom);
//     end

//     logic [11:0] addr = (ly << 8) + (ly << 6) + lx;

//     assign rgb = (lx < 320 && ly < 240) ? rom[addr] : 12'h000;
//     // assign rgb = (lx < 320 && ly < 240) ? rom[ly*320+lx] : 12'h000;

//     // always_ff @(posedge clk) begin
//     //     if (lx < 320 && ly < 240) rgb <= rom[ly*320+lx];
//     //     else rgb <= 12'h000;
//     // end
// endmodule
