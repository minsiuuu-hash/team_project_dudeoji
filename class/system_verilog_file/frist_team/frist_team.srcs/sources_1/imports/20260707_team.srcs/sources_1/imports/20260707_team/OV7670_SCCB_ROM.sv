`timescale 1ns / 1ps

// main()의 전체 호출 순서를 그대로 옮긴 ROM.
//   OV7670_Init(&hi2c1);            // 레지스터 write 없음 (핸들 저장만)
//   OV7670_ResetSW();               // reset+delay, Config(defaults), SetResolution(QVGA), SetColorFormat(RGB565)
//   OV7670_SetResolution(QVGA);     // (중복) RES_QVGA + SetFrameControl(168,24,12,492)
//   OV7670_SetColorFormat(RGB565);  // (중복) COM7/COM15
//   OV7670_AutoExposureMode(1);     // COM8 |= 0x01
//   OV7670_SetBrightness(120);      // BRIGHT = 255-120 = 0x87
//   OV7670_AutoGainMode(1);         // COM8 |= 0x04
//
// read-modify-write는 해당 시점 레지스터값을 미리 계산해 write-only로 대체.
// FFFF is end of ROM, FFF0 is delay.

module OV7670_config_rom (
    input  logic        clk,
    input  logic [ 7:0] addr,
    output logic [15:0] dout
);
    always_ff @(posedge clk) begin
        case (addr)
            // ============ ResetSW: reset + delay ============
            8'd0:   dout <= 16'h12_80;  // COM7, reset
            8'd1:   dout <= 16'hFF_F0;  // HAL_Delay(30)

            // ============ ResetSW: Config(defaults[]) ============
            8'd2:   dout <= 16'h3A_04;  // TSLB
            8'd3:   dout <= 16'h13_E7;  // COM8, AGC/AWB/AEC on
            8'd4:   dout <= 16'h6F_9F;  // AWBCTR0
            8'd5:   dout <= 16'hB0_84;  // RSVD
            8'd6:   dout <= 16'h70_3A;  // SCALING_XSC
            8'd7:   dout <= 16'h71_35;  // SCALING_YSC
            8'd8:   dout <= 16'h72_11;  // SCALING_DCWCTR
            8'd9:   dout <= 16'h73_F0;  // SCALING_PCLK_DIV
            8'd10:  dout <= 16'h7A_20;  // Gamma
            8'd11:  dout <= 16'h7B_10;
            8'd12:  dout <= 16'h7C_1E;
            8'd13:  dout <= 16'h7D_35;
            8'd14:  dout <= 16'h7E_5A;
            8'd15:  dout <= 16'h7F_69;
            8'd16:  dout <= 16'h80_76;
            8'd17:  dout <= 16'h81_80;
            8'd18:  dout <= 16'h82_88;
            8'd19:  dout <= 16'h83_8F;
            8'd20:  dout <= 16'h84_96;
            8'd21:  dout <= 16'h85_A3;
            8'd22:  dout <= 16'h86_AF;
            8'd23:  dout <= 16'h87_C4;
            8'd24:  dout <= 16'h88_D7;
            8'd25:  dout <= 16'h89_E8;
            8'd26:  dout <= 16'h00_00;  // GAIN
            8'd27:  dout <= 16'h10_00;  // AECH
            8'd28:  dout <= 16'h0D_40;  // COM4
            8'd29:  dout <= 16'h14_18;  // COM9
            8'd30:  dout <= 16'hA5_05;  // BD50MAX
            8'd31:  dout <= 16'hAB_07;  // BD60MAX
            8'd32:  dout <= 16'h24_95;  // AEW
            8'd33:  dout <= 16'h25_33;  // AEB
            8'd34:  dout <= 16'h26_E3;  // VPT
            8'd35:  dout <= 16'h9F_78;  // HAECC1
            8'd36:  dout <= 16'hA0_68;  // HAECC2
            8'd37:  dout <= 16'hA1_03;  // RSVD
            8'd38:  dout <= 16'hA6_D8;  // HAECC3
            8'd39:  dout <= 16'hA7_D8;  // HAECC4
            8'd40:  dout <= 16'hA8_F0;  // HAECC5
            8'd41:  dout <= 16'hA9_90;  // HAECC6
            8'd42:  dout <= 16'hAA_94;  // HAECC7

            // ============ ResetSW: SetResolution(QVGA) ============
            8'd43:  dout <= 16'h12_11;  // COM7, QVGA
            8'd44:  dout <= 16'h0C_04;  // COM3, DCW enable
            8'd45:  dout <= 16'h3E_19;  // COM14
            8'd46:  dout <= 16'h70_3A;  // SCALING_XSC
            8'd47:  dout <= 16'h71_35;  // SCALING_YSC
            8'd48:  dout <= 16'h72_11;  // SCALING_DCWCTR
            8'd49:  dout <= 16'h73_F1;  // SCALING_PCLK_DIV
            8'd50:  dout <= 16'hA2_02;  // SCALING_PCLK_DELAY
            // SetFrameControl(168,24,12,492)
            8'd51:  dout <= 16'h17_15;  // HSTART
            8'd52:  dout <= 16'h18_03;  // HSTOP
            8'd53:  dout <= 16'h32_00;  // HREF
            8'd54:  dout <= 16'h19_03;  // VSTART
            8'd55:  dout <= 16'h1A_7B;  // VSTOP
            8'd56:  dout <= 16'h03_00;  // VREF

            // ============ ResetSW: SetColorFormat(RGB565) ============
            // COM7: 0x11 & 0b11111010 | 0x04 = 0x14
            // COM15: 0x00 & 0b00001111 | 0x10 = 0x10
            8'd57:  dout <= 16'h12_14;  // COM7, RGB + QVGA
            8'd58:  dout <= 16'h40_10;  // COM15, RGB565

            // ============ main: SetResolution(QVGA) 중복 호출 ============
            8'd59:  dout <= 16'h12_11;  // COM7, QVGA  (COM7이 0x14 -> 다시 0x11)
            8'd60:  dout <= 16'h0C_04;  // COM3
            8'd61:  dout <= 16'h3E_19;  // COM14
            8'd62:  dout <= 16'h70_3A;  // SCALING_XSC
            8'd63:  dout <= 16'h71_35;  // SCALING_YSC
            8'd64:  dout <= 16'h72_11;  // SCALING_DCWCTR
            8'd65:  dout <= 16'h73_F1;  // SCALING_PCLK_DIV
            8'd66:  dout <= 16'hA2_02;  // SCALING_PCLK_DELAY
            8'd67:  dout <= 16'h17_15;  // HSTART
            8'd68:  dout <= 16'h18_03;  // HSTOP
            8'd69:  dout <= 16'h32_00;  // HREF
            8'd70:  dout <= 16'h19_03;  // VSTART
            8'd71:  dout <= 16'h1A_7B;  // VSTOP
            8'd72:  dout <= 16'h03_00;  // VREF

            // ============ main: SetColorFormat(RGB565) 중복 호출 ============
            // COM7: 0x11 & 0b11111010 | 0x04 = 0x14
            // COM15: 0x10 & 0b00001111 | 0x10 = 0x10
            8'd73:  dout <= 16'h12_14;  // COM7, RGB + QVGA
            8'd74:  dout <= 16'h40_10;  // COM15, RGB565

            // ============ main: AutoExposureMode(1) ============
            // COM8: 0xE7 | 0x01 = 0xE7 (변화 없음)
            8'd75:  dout <= 16'h13_E7;  // COM8, AEC enable

            // ============ main: SetBrightness(120) ============
            // 120 < 127 -> 255-120 = 0x87
            8'd76:  dout <= 16'h55_87;  // BRIGHT

            // ============ main: AutoGainMode(1) ============
            // COM8: 0xE7 | 0x04 = 0xE7 (변화 없음)
            8'd77:  dout <= 16'h13_E7;  // COM8, AGC enable

            default: dout <= 16'hFF_FF;  // End of ROM
        endcase
    end
endmodule