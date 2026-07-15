`timescale 1ns / 1ps

module image_rom #(
    parameter int ADDR_W = 12,
    parameter string MEM_FILE = ""
) (
    input  logic              clk,
    input  logic [ADDR_W-1:0] addr,
    output logic [11:0]       rgb
);
    (* ram_style = "block" *) logic [11:0] mem [0:(1<<ADDR_W)-1];

    initial begin
        if (MEM_FILE != "") begin
            $readmemh(MEM_FILE, mem);
        end
    end

    always_ff @(posedge clk) begin
        rgb <= mem[addr];
    end
endmodule

