`timescale 1ns / 1ps

module text_renderer (
    input  logic [9:0] x,
    input  logic [9:0] y,
    input  logic [9:0] origin_x,
    input  logic [9:0] origin_y,
    input  logic [3:0] scale,
    input  logic [3:0] char_count,
    input  logic [3:0] word_id,
    input  logic [7:0] value,
    output logic       pixel_on
);
    function automatic logic [4:0] glyph(input logic [7:0] ch, input logic [2:0] row);
        begin
            glyph = 5'b00000;
            case (ch)
                "0": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10011;3:glyph=5'b10101;4:glyph=5'b11001;5:glyph=5'b10001;6:glyph=5'b01110; default:glyph=0; endcase
                "1": case (row) 0:glyph=5'b00100;1:glyph=5'b01100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00100;6:glyph=5'b01110; default:glyph=0; endcase
                "2": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b00001;3:glyph=5'b00010;4:glyph=5'b00100;5:glyph=5'b01000;6:glyph=5'b11111; default:glyph=0; endcase
                "3": case (row) 0:glyph=5'b11110;1:glyph=5'b00001;2:glyph=5'b00001;3:glyph=5'b01110;4:glyph=5'b00001;5:glyph=5'b00001;6:glyph=5'b11110; default:glyph=0; endcase
                "4": case (row) 0:glyph=5'b00010;1:glyph=5'b00110;2:glyph=5'b01010;3:glyph=5'b10010;4:glyph=5'b11111;5:glyph=5'b00010;6:glyph=5'b00010; default:glyph=0; endcase
                "5": case (row) 0:glyph=5'b11111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b11110;4:glyph=5'b00001;5:glyph=5'b00001;6:glyph=5'b11110; default:glyph=0; endcase
                "6": case (row) 0:glyph=5'b01110;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b11110;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b01110; default:glyph=0; endcase
                "7": case (row) 0:glyph=5'b11111;1:glyph=5'b00001;2:glyph=5'b00010;3:glyph=5'b00100;4:glyph=5'b01000;5:glyph=5'b01000;6:glyph=5'b01000; default:glyph=0; endcase
                "8": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b01110;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b01110; default:glyph=0; endcase
                "9": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b01111;4:glyph=5'b00001;5:glyph=5'b00001;6:glyph=5'b01110; default:glyph=0; endcase
                "A": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b11111;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b10001; default:glyph=0; endcase
                "C": case (row) 0:glyph=5'b01111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b10000;4:glyph=5'b10000;5:glyph=5'b10000;6:glyph=5'b01111; default:glyph=0; endcase
                "E": case (row) 0:glyph=5'b11111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b11110;4:glyph=5'b10000;5:glyph=5'b10000;6:glyph=5'b11111; default:glyph=0; endcase
                "G": case (row) 0:glyph=5'b01111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b10111;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b01111; default:glyph=0; endcase
                "H": case (row) 0:glyph=5'b10001;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b11111;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b10001; default:glyph=0; endcase
                "I": case (row) 0:glyph=5'b11111;1:glyph=5'b00100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00100;6:glyph=5'b11111; default:glyph=0; endcase
                "L": case (row) 0:glyph=5'b10000;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b10000;4:glyph=5'b10000;5:glyph=5'b10000;6:glyph=5'b11111; default:glyph=0; endcase
                "M": case (row) 0:glyph=5'b10001;1:glyph=5'b11011;2:glyph=5'b10101;3:glyph=5'b10101;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b10001; default:glyph=0; endcase
                "N": case (row) 0:glyph=5'b10001;1:glyph=5'b11001;2:glyph=5'b10101;3:glyph=5'b10011;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b10001; default:glyph=0; endcase
                "O": case (row) 0:glyph=5'b01110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b10001;4:glyph=5'b10001;5:glyph=5'b10001;6:glyph=5'b01110; default:glyph=0; endcase
                "R": case (row) 0:glyph=5'b11110;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b11110;4:glyph=5'b10100;5:glyph=5'b10010;6:glyph=5'b10001; default:glyph=0; endcase
                "S": case (row) 0:glyph=5'b01111;1:glyph=5'b10000;2:glyph=5'b10000;3:glyph=5'b01110;4:glyph=5'b00001;5:glyph=5'b00001;6:glyph=5'b11110; default:glyph=0; endcase
                "T": case (row) 0:glyph=5'b11111;1:glyph=5'b00100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00100;6:glyph=5'b00100; default:glyph=0; endcase
                "V": case (row) 0:glyph=5'b10001;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b10001;4:glyph=5'b10001;5:glyph=5'b01010;6:glyph=5'b00100; default:glyph=0; endcase
                "W": case (row) 0:glyph=5'b10001;1:glyph=5'b10001;2:glyph=5'b10001;3:glyph=5'b10101;4:glyph=5'b10101;5:glyph=5'b11011;6:glyph=5'b10001; default:glyph=0; endcase
                "!": case (row) 0:glyph=5'b00100;1:glyph=5'b00100;2:glyph=5'b00100;3:glyph=5'b00100;4:glyph=5'b00100;5:glyph=5'b00000;6:glyph=5'b00100; default:glyph=0; endcase
                default: glyph = 5'b00000;
            endcase
        end
    endfunction

    function automatic logic [7:0] word_char(input logic [3:0] wid, input int idx, input logic [7:0] val);
        int tens;
        int ones;
        begin
            tens = val / 10;
            ones = val - tens * 10;
            word_char = " ";
            case (wid)
                4'd0: case (idx) 0:word_char="M";1:word_char="O";2:word_char="L";3:word_char="E";4:word_char=" ";5:word_char="G";6:word_char="A";7:word_char="M";8:word_char="E"; default:word_char=" "; endcase
                4'd1: case (idx) 0:word_char="S";1:word_char="C";2:word_char="O";3:word_char="R";4:word_char="E"; default:word_char=" "; endcase
                4'd2: case (idx) 0:word_char="S";1:word_char="T";2:word_char="A";3:word_char="G";4:word_char="E"; default:word_char=" "; endcase
                4'd3: case (idx) 0:word_char="W";1:word_char="I";2:word_char="N"; default:word_char=" "; endcase
                4'd4: case (idx) 0:word_char="G";1:word_char="A";2:word_char="M";3:word_char="E";4:word_char=" ";5:word_char="O";6:word_char="V";7:word_char="E";8:word_char="R"; default:word_char=" "; endcase
                4'd5: case (idx) 0:word_char="H";1:word_char="I";2:word_char="T";3:word_char="!"; default:word_char=" "; endcase
                4'd6: word_char = (idx == 0) ? (8'd48 + tens[7:0]) : (8'd48 + ones[7:0]);
                4'd7: word_char = 8'd48 + val;
                default: word_char = " ";
            endcase
        end
    endfunction

    int rx;
    int ry;
    int cell_w;
    int idx;
    int gx;
    int gy;
    logic [7:0] ch;
    logic [4:0] line;

    always_comb begin
        rx = x - origin_x;
        ry = y - origin_y;
        cell_w = 6 * scale;
        idx = (cell_w == 0) ? 0 : rx / cell_w;
        gx = (scale == 0) ? 0 : (rx - idx * cell_w) / scale;
        gy = (scale == 0) ? 0 : ry / scale;
        ch = word_char(word_id, idx, value);
        line = glyph(ch, gy[2:0]);
        pixel_on = (rx >= 0) && (ry >= 0) && (idx >= 0) && (idx < char_count) &&
                   (gx >= 0) && (gx < 5) && (gy >= 0) && (gy < 7) && line[4-gx];
    end
endmodule
