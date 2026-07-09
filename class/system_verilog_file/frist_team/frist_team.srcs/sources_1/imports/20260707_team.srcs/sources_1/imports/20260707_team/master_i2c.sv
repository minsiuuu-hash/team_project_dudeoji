`timescale 1ns / 1ps

module OV7670_config_top #(

    parameter logic [7:0] CAM_WADDR = 8'h42
) (
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,
    output logic scl,
    inout  logic sda
);

    logic [ 7:0] rom_addr;
    logic [15:0] rom_dout;

    OV7670_config_rom u_rom (
        .clk (clk),
        .addr(rom_addr),
        .dout(rom_dout)
    );

    logic cmd_start, cmd_write, cmd_read, cmd_stop;
    logic [7:0] tx_data, rx_data;
    logic i2c_done, i2c_busy, ack_out;

    master_i2c u_i2c (
        .clk      (clk),
        .rst      (rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .ack_in   (1'b1),
        .rx_data  (rx_data),
        .done     (i2c_done),
        .ack_out  (ack_out),
        .busy     (i2c_busy),
        .scl      (scl),
        .sda      (sda)
    );

    // localparam int DELAY_CYCLES = (CLK_FREQ/1000)*DELAY_MS;
    // logic [$clog2(DELAY_CYCLES+1)-1:0] delay_cnt;

    logic en;
    logic o_tick;

    counter U_COUNTER (
        .*
        // input clk,
        // input rst,
        // input en,
        // output logic o_tick
    );

    typedef enum logic [3:0] {
        S_IDLE,
        S_FETCH,
        S_DECODE,
        S_START,
        S_START_W,
        S_WADDR,
        S_WADDR_W,
        S_REG,
        S_REG_W,
        S_DATA,
        S_DATA_W,
        S_STOP,
        S_STOP_W,
        S_DELAY,
        S_NEXT,
        S_DONE
    } state_e;

    state_e state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            rom_addr  <= 8'd0;
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            tx_data   <= 8'd0;
            // delay_cnt <= '0;
            done      <= 1'b0;
            en        <= 1'b0;
        end else begin
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    en   <= 1'b0;
                    if (start) begin
                        rom_addr <= 8'd0;
                        state    <= S_FETCH;
                    end
                end

                S_FETCH: state <= S_DECODE;

                S_DECODE: begin
                    if (rom_dout == 16'hFFFF) state <= S_DONE;
                    else if (rom_dout == 16'hFFF0) begin
                        // delay_cnt <= '0;
                        state <= S_DELAY;
                    end else state <= S_START;
                end

                S_START: begin
                    cmd_start <= 1'b1;
                    state <= S_START_W;
                end
                S_START_W: if (i2c_done) state <= S_WADDR;

                S_WADDR: begin
                    cmd_write <= 1'b1;
                    tx_data <= CAM_WADDR;
                    state <= S_WADDR_W;
                end
                S_WADDR_W: if (i2c_done) state <= S_REG;

                S_REG: begin
                    cmd_write <= 1'b1;
                    tx_data <= rom_dout[15:8];
                    state <= S_REG_W;
                end
                S_REG_W: if (i2c_done) state <= S_DATA;

                S_DATA: begin
                    cmd_write <= 1'b1;
                    tx_data <= rom_dout[7:0];
                    state <= S_DATA_W;
                end
                S_DATA_W: if (i2c_done) state <= S_STOP;

                S_STOP: begin
                    cmd_stop <= 1'b1;
                    state <= S_STOP_W;
                end
                S_STOP_W: if (i2c_done) state <= S_NEXT;

                S_DELAY: begin
                    en <= 1'b1;
                    if (o_tick) begin
                        state <= S_NEXT;
                        en <= 1'b0;
                    end
                end

                S_NEXT: begin
                    rom_addr <= rom_addr + 1'b1;
                    state    <= S_FETCH;
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_DONE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


module master_i2c (
    input logic clk,
    input logic rst,
    // command port
    input logic cmd_start,  // trigger start
    input logic cmd_write,
    input logic cmd_read,
    input logic cmd_stop,
    input  logic [7:0] tx_data,     // 외부에서 받는값 -> slave한테 쪼개서 줌
    input logic ack_in,  // 마스터가 받는거
    // internal output
    output logic [7:0] rx_data,     // slave 한테 받은값 내보냄 -> 외부한테
    output logic done,
    output logic ack_out,  // master가 주는거
    output logic busy,
    // external i2c port
    output logic scl,
    inout logic sda
);

    logic sda_o, sda_i;


    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;


    i2c_master u_12c_master (
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );
endmodule


module counter #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int DELAY_MS = 30
) (
    input clk,
    input rst,
    input en,
    output logic o_tick
);
    localparam [21:0] DELAY_CYCLES = (CLK_FREQ / 1000) * DELAY_MS;
    logic [$clog2((CLK_FREQ / 1000) * DELAY_MS)-1:0] delay_cnt;


    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            delay_cnt <= 0;
            o_tick <= 1'b0;
        end else if (en) begin
            if (delay_cnt == DELAY_CYCLES - 1) begin
                delay_cnt <= 0;
                o_tick <= 1'b1;
            end else begin
                delay_cnt <= delay_cnt + 1;
                o_tick <= 1'b0;
            end
        end
    end
endmodule







module i2c_master (
    input  logic       clk,
    input  logic       rst,
    // command port
    input  logic       cmd_start,  // trigger start
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic       cmd_stop,
    input  logic [7:0] tx_data,
    input  logic       ack_in,     // 마스터가 받는거
    // internal output
    output logic [7:0] rx_data,
    output logic       done,
    output logic       ack_out,    // master가 주는거
    output logic       busy,
    // external i2c port
    output logic       scl,
    output logic       sda_o,
    input  logic       sda_i
);


    typedef enum logic [2:0] {
        IDLE,
        START,
        WAIT_CMD,
        DATA,
        DATA_ACK,
        STOP
    } i2c_state_e;

    i2c_state_e       state;

    // tickgen
    logic       [7:0] div_cnt;
    logic             qtr_tick;

    // register
    logic scl_r, sda_r;
    logic [1:0] step;

    // register
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;
    logic is_read, ack_in_r;

    //connect
    assign scl   = scl_r;
    assign sda_o = sda_r;

    assign busy  = (state != IDLE);



    // tickgen
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            div_cnt  <= 0;
            qtr_tick <= 0;
        end else begin
            if (div_cnt == 250 - 1) begin  // scl : 100khz
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                qtr_tick <= 1'b0;
                div_cnt  <= div_cnt + 1;
            end
        end
    end

    // assign qtr_tick = (div_cnt == 250 - 1);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            scl_r        <= 1'b1;
            sda_r        <= 1'b1;
            // busy         <= 1'b0;
            step         <= 1'b0;
            done         <= 1'b0;
            tx_shift_reg <= 8'h0;
            rx_shift_reg <= 8'h0;
            bit_cnt      <= 3'd0;
            ack_in_r     <= 1'b1;  // nack 상태로 전송
            is_read      <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    busy  <= 1'b0;
                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                        // busy  <= 1'b1;
                    end
                end
                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                sda_r <= 1'b0;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                WAIT_CMD: begin
                    step <= 0;
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt <= 0;
                        is_read <= 1'b0;
                        state <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 0;
                        bit_cnt <= 0;
                        is_read <= 1'b1;
                        ack_in_r <= ack_in;
                        state <= DATA;
                    end else if (cmd_stop) begin
                        state <= STOP;
                    end else if (cmd_start) begin
                        state <= START;
                    end
                end
                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];  // msb, no read -> send
                                step <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if (is_read) begin
                                    rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                end  // read
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                if (!is_read) begin
                                    tx_shift_reg <= {
                                        tx_shift_reg[6:0], 1'b0
                                    };  // msb
                                end  // write
                                step <= 2'd0;

                                if (bit_cnt == 7) begin
                                    state <= DATA_ACK;

                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                end
                            end
                        endcase
                    end
                end
                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                if (is_read) begin
                                    sda_r <= ack_in_r;
                                end else begin
                                    sda_r <= 1'b1;  // sda input setting
                                end
                                step <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;

                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                if (!is_read) begin  // ack soo sin
                                    ack_out <= sda_i;
                                end
                                if (is_read) begin
                                    rx_data <= rx_shift_reg;
                                end

                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end
                STOP: begin

                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b0;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;

                            end
                            2'd2: begin
                                sda_r <= 1'b1;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end


                            default: begin
                                state <= IDLE;
                            end


                        endcase
                    end
                end
            endcase
        end
    end

endmodule

