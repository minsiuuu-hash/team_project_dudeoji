module greyScaleFilter (
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb   // Removed the unused 'sw' port
);

    logic [11:0] grey;

    // Luminance approximation: Y = 0.299*R + 0.587*G + 0.114*B (scaled by 256)
    assign grey = (((i_rgb[11:8] << 6) + (i_rgb[11:8] << 3) + (i_rgb[11:8] << 2)) 
                 + ((i_rgb[7:4] << 7) + (i_rgb[7:4] << 4) + (i_rgb[7:4] << 3)) 
                 + ((i_rgb[7:4] << 1) + (i_rgb[3:0] << 4) + (i_rgb[3:0] << 3) + (i_rgb[3:0] << 1)));

    // Replicate the intensity (upper 4 bits) across all channels for true grayscale
    assign o_rgb = {grey[11:8], grey[11:8], grey[11:8]};

endmodule