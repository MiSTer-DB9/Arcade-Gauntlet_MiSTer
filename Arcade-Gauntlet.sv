//============================================================================
//  Arcade: Gauntlet
//
//  Port to MiSTer
//  Copyright (C) 2020 d18c7db
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	output  USER_OSD,
	output  [1:0] USER_MODE,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////
wire [15:0] joydb_1,joydb_2;
wire        joydb_1ena,joydb_2ena;
joydbmix joydbmix
(
  .CLK_JOY(CLK_50M),
  .JOY_FLAG(status[63:61]),
  .USER_IN(USER_IN),
  .USER_OUT(USER_OUT),
  .USER_MODE(USER_MODE),
  .USER_OSD(USER_OSD),
  .joydb_1ena(joydb_1ena),
  .joydb_2ena(joydb_2ena),
  .joydb_1(joydb_1),
  .joydb_2(joydb_2)
);
wire [31:0]   joystick_0 = joydb_1ena ? {joydb_1[10],joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[7:0]} : joystick_0_USB;
wire [31:0]   joystick_1 = joydb_2ena ? {joydb_1[10],joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[7:0]} : joydb_1ena ? joystick_0_USB : joystick_1_USB;
wire [31:0]   joystick_2 = joydb_1ena ? joystick_0_USB : joydb_2ena ? joystick_1_USB : joystick_2_USB;
wire [31:0]   joystick_3 = joydb_1ena ? joystick_1_USB : joydb_2ena ? joystick_2_USB : joystick_3_USB;

assign ADC_BUS  = 'Z;
//assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

integer      slap_type = 104; // Slapstic type depends on game: 104=Gauntlet, 106=Gauntlet II, 107=2-Player Gauntlet, 118=Vindicators Part II
wire         gauntlet_4p = (slap_type == 104 || slap_type == 106);
wire         clk_7M;
wire         clk_14M;
wire         clk_sys;
wire         clk_video;
reg          ce_pix;
wire         pll_locked;
wire         HBlank, VBlank;
wire         HSync, VSync;
//reg  [ 7:0] sw[8];
wire [  3:0] r,g,b, gvid_I, gvid_R, gvid_G, gvid_B;
wire [ 15:0] aud_l, aud_r;
wire [127:0] status;
wire [  1:0] buttons;
wire         forced_scandoubler;
wire         direct_video;
wire         ioctl_download;
wire         ioctl_wr;
wire         ioctl_wait;
wire [ 15:0] ioctl_index;
wire [ 26:0] ioctl_addr;
wire [  7:0] ioctl_dout;

assign AUDIO_S = 1'b1; // signed samples
assign AUDIO_L = aud_l;
assign AUDIO_R = aud_r;
assign AUDIO_MIX = 0;

assign LED_USER  = ioctl_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

wire [31:0] joystick_0_USB, joystick_1_USB, joystick_2_USB, joystick_3_USB;
wire [31:0] joystick_0_mux, joystick_1_mux, joystick_2_mux, joystick_3_mux;

wire [10:0] ps2_key;

wire [21:0] gamma_bus;

reg [7:0]   p1 = 8'h0;
reg [7:0]   p2 = 8'h0;
reg [7:0]   p3 = 8'h0;
reg [7:0]   p4 = 8'h0;

reg         m_coin1   = 1'b0;
reg         m_coin2   = 1'b0;
reg         m_coin3   = 1'b0;
reg         m_coin4   = 1'b0;

//assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[1:0];
wire [2:0] fx = status[4:2];
wire m_service = ~status[5];
wire reset = RESET | status[6] | buttons[1]| ioctl_download;

wire [1:0] joy_warrior  = status[11:10];
wire [1:0] joy_valkyrie = status[13:12];
wire [1:0] joy_wizard   = status[15:14];
wire [1:0] joy_elf      = status[17:16];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"A.GAUNTLET;;",
	"-;",
	"O01,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O24,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"oUV,UserIO Joystick,Off,DB15,DB9;",
	"oT,UserIO Players,1 Player,2 Players;",
	"-;",
	"h2OAB,Warrior,Joystick 1,Joystick 2,Joystick 3,Joystick 4;",
	"h2OCD,Valkyrie,Joystick 2,Joystick 3,Joystick 4,Joystick 1;",
	"h2OEF,Wizard,Joystick 3,Joystick 4,Joystick 1,Joystick 2;",
	"h2OGH,Elf,Joystick 4,Joystick 1,Joystick 2,Joystick 3;",
	"-;",
	"DIP;",
	"-;",
	"O5,Service,Off,On;",
	"R6,Reset;",
	"J1,Button1,Button2,Button3,Button4,Coin,VStart;",
	"jn,A,B,X,Y,R,Start;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////
pll pll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(clk_7M),    //  7.15909 MHz
	.outclk_1(clk_14M),   // 14.31818 MHz
	.outclk_2(clk_video), // 57.27272 MHz
	.outclk_3(clk_sys),   // 93.06817 MHz
	.outclk_4(SDRAM_CLK), // 93.06817 MHz
	.locked(pll_locked)
);

always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==1)) slap_type <= ioctl_dout;

// keyboard controls - map keycodes to actions
wire pressed = ps2_key[9];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];

	if(old_state != ps2_key[10]) begin
		if (slap_type == 118) // select controller mapping
		casex(ps2_key[8:0])
			// Vindicators tank controls
			'h023: p1[7]        <= pressed; // P1 R BACK  (D).
			'h01B: p1[6]        <= pressed; // P1 L BACK  (S).
			'h024: p1[5]        <= pressed; // P1 R FORW  (E).
			'h01D: p1[4]        <= pressed; // P1 L FORW  (W).
			'h02D: p1[3]        <= pressed; // P1 R THUMB (R)
			'h015: p1[2]        <= pressed; // P1 L THUMB (Q)
			'h02B: p1[1]        <= pressed; // P1 R TRIG  (F).
			'h01C: p1[0]        <= pressed; // P1 L TRIG  (A).

			'h042: p2[7]        <= pressed; // P2 R BACK  (K).
			'h03B: p2[6]        <= pressed; // P2 L BACK  (J).
			'h043: p2[5]        <= pressed; // P2 R FORW  (I).
			'h03C: p2[4]        <= pressed; // P2 L FORW  (U).
			'h044: p2[3]        <= pressed; // P2 R THUMB (O)
			'h035: p2[2]        <= pressed; // P2 L THUMB (Y)
			'h04B: p2[1]        <= pressed; // P2 R TRIG  (L).
			'h033: p2[0]        <= pressed; // P2 L TRIG  (H).

			'h016: p3[0]        <= pressed; // P1 START   (1).
			'h01E: p3[1]        <= pressed; // P2 START   (2)

			'h02E: m_coin1      <= pressed; // P1 COIN    (5)
			'h036: m_coin2      <= pressed; // P2 COIN    (6)
//			'h03D: m_coin3      <= pressed; // P3 COIN    (7)
//			'h03E: m_coin4      <= pressed; // P4 COIN    (8)
		endcase
		else
		casex(ps2_key[8:0])
			// Gauntlet I and II - Default MAME Controls Assignment
			'h175: p1[7]        <= pressed; // up    (up_arrow)
			'h172: p1[6]        <= pressed; // down  (down_arrow)
			'h16B: p1[5]        <= pressed; // left  (left_arrow)
			'h174: p1[4]        <= pressed; // right (right_arrow)
			'h014: p1[1]        <= pressed; // fire  (left ctrl)
			'h011: p1[0]        <= pressed; // magic (left alt)

			'h02D: p2[7]        <= pressed; // up    (R)
			'h02B: p2[6]        <= pressed; // down  (F)
			'h023: p2[5]        <= pressed; // left  (D)
			'h034: p2[4]        <= pressed; // right (G)
			'h01C: p2[1]        <= pressed; // fire  (A)
			'h01B: p2[0]        <= pressed; // magic (S)

			'h043: p3[7]        <= pressed; // up    (I)
			'h042: p3[6]        <= pressed; // down  (K)
			'h03B: p3[5]        <= pressed; // left  (J)
			'h04B: p3[4]        <= pressed; // right (L)
			'h114: p3[1]        <= pressed; // fire  (right ctrl)
			'h059: p3[0]        <= pressed; // magic (right shift)

			'h075: p4[7]        <= pressed; // up    (numpad 8)
			'h072: p4[6]        <= pressed; // down  (numpad 2)
			'h06B: p4[5]        <= pressed; // left  (numpad 4)
			'h074: p4[4]        <= pressed; // right (numpad 6)
			'h070: p4[1]        <= pressed; // fire  (numpad 0)
			'h071: p4[0]        <= pressed; // magic (numpad .)

			'h02E: m_coin1      <= pressed; // coin1 (5)
			'h036: m_coin2      <= pressed; // coin2 (6)
			'h03D: m_coin3      <= pressed; // coin3 (7)
			'h03E: m_coin4      <= pressed; // coin4 (8)
		endcase
	end
end

/// from ultratank

reg JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk;
reg JoyY_Fw,JoyY_Bk,JoyZ_Fw,JoyZ_Bk;
always @(posedge clk_sys) begin 
	case ({joystick_0[3],joystick_0[2],joystick_0[1],joystick_0[0]}) // Up,Down,Left,Right
		4'b1010: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up_Left
		4'b1000: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up
		4'b1001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end //Up_Right
		4'b0001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Right
		4'b0101: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=0; end //Down_Right
		4'b0100: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=1; end //Down
		4'b0110: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Down_Left
		4'b0010: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=1; JoyX_Bk=0; end //Left
		default: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end
	endcase
	case ({joystick_1[3],joystick_1[2],joystick_1[1],joystick_1[0]}) // Up,Down,Left,Right
		4'b1010: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=1; JoyZ_Bk=0; end //Up_Left
		4'b1000: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=1; JoyZ_Bk=0; end //Up
		4'b1001: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=0; end //Up_Right
		4'b0001: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=1; end //Right
		4'b0101: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=0; JoyZ_Bk=0; end //Down_Right
		4'b0100: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=0; JoyZ_Bk=1; end //Down
		4'b0110: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=1; end //Down_Left
		4'b0010: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=1; JoyZ_Bk=0; end //Left
		default: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=0; end
	endcase
end

always_comb begin
	if (gauntlet_4p) begin
		case (joy_warrior)
			2'b00   : joystick_0_mux = joystick_0;
			2'b01   : joystick_0_mux = joystick_1;
			2'b10   : joystick_0_mux = joystick_2;
			2'b11   : joystick_0_mux = joystick_3;
		endcase
		case (joy_valkyrie)
			2'b00   : joystick_1_mux = joystick_1;
			2'b01   : joystick_1_mux = joystick_2;
			2'b10   : joystick_1_mux = joystick_3;
			2'b11   : joystick_1_mux = joystick_0;
		endcase
		case (joy_wizard)
			2'b00   : joystick_2_mux = joystick_2;
			2'b01   : joystick_2_mux = joystick_3;
			2'b10   : joystick_2_mux = joystick_0;
			2'b11   : joystick_2_mux = joystick_1;
		endcase
		case (joy_elf)
			2'b00   : joystick_3_mux = joystick_3;
			2'b01   : joystick_3_mux = joystick_0;
			2'b10   : joystick_3_mux = joystick_1;
			2'b11   : joystick_3_mux = joystick_2;
		endcase
	end
	else
	begin
		joystick_0_mux = joystick_0;
		joystick_1_mux = joystick_1;
		joystick_2_mux = joystick_2;
		joystick_3_mux = joystick_3;
	end
end

wire [7:0] I_P1 = (slap_type == 118) ?
				  ~(p1 | {JoyX_Bk,JoyW_Bk,JoyX_Fw,JoyW_Fw,joystick_0_mux[7:4]})
				: ~(p1 | {joystick_0_mux[3:0], joystick_0_mux[7:4]});
wire [7:0] I_P2 = (slap_type == 118) ? 
				  ~(p2 | {JoyZ_Bk,JoyY_Bk,JoyZ_Fw,JoyY_Fw,joystick_1_mux[7:4]})
				: ~(p2 | {joystick_1_mux[3:0], joystick_1_mux[7:4]});
wire [7:0] I_P3 = (slap_type == 118) ?
				  ~(p3 | { 6'b0,joystick_1_mux[9],joystick_0_mux[9]})
				: ~(p3 | {joystick_2_mux[3:0], joystick_2_mux[7:4]});
wire [7:0] I_P4 = (slap_type == 118) ?
				  ~(p4)
				: ~(p4 | {joystick_3_mux[3:0], joystick_3_mux[7:4]});

///////////////////////////////////////////////////
always @(posedge clk_video) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(.WIDTH(320), .DW(12)) arcade_video
(
	.*,
	.RGB_in({r,g,b}),
	.HBlank(~HBlank),
	.VBlank(~VBlank),
	.HSync (~HSync),
	.VSync (~VSync)
);

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({gauntlet_4p,(slap_type == 118),direct_video}),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	
	.joy_raw(joydb_1[5:0]),
	
	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joystick_2(joystick_2_USB),
	.joystick_3(joystick_3_USB),
	.ps2_key(ps2_key)
);

// convert input video from 16bit IRGB to 12 bit RGB
RGBI RCONV (.ADDR({gvid_I,gvid_R}), .DATA(r));
RGBI GCONV (.ADDR({gvid_I,gvid_G}), .DATA(g));
RGBI BCONV (.ADDR({gvid_I,gvid_B}), .DATA(b));

// ###################################################
// # This section loads the ROM files through HPS_IO #
// ###################################################

wire gp_wr, mp_wr_9A_9B, mp_wr_10A_10B, mp_wr_7A_7B, mp_wr_6A_6B, mp_wr_5A_5B, mp_wr_3A_3B, ap_wr_16R, ap_wr_16S, cp_wr_6P;

wire [15:0] ap_addr;
wire [ 7:0] ap_data, ap_data_16R, ap_data_16S;

wire [17:0] gp_addr;
wire [31:0] gp_data;

wire [18:0] mp_addr;
wire [15:0] mp_data, mp_data_9A_9B, mp_data_10A_10B, mp_data_7A_7B, mp_data_6A_6B, mp_data_5A_5B, mp_data_3A_3B;

wire [13:0] cp_addr;
wire [ 7:0] cp_data;

wire [ 7:0] r4_addr;
wire [ 3:0] r4_data, r4_data_G1, r4_data_G2, r4_data_V2;

// ioctl_addr 000000..01FFFF = video ROMs 2L  2A  1L  1A  (4*32KB)
// ioctl_addr 020000..03FFFF = video ROMs 2MN 2B  1MN 1B  (4*32KB)
// ioctl_addr 040000..05FFFF = video ROMs 2P  2C  1P  1C  (4*32KB)
// ioctl_addr 060000..07FFFF = video ROMs 2R  2D  1R  1D  (4*32KB)
// ioctl_addr 080000..09FFFF = video ROMs 2ST 2EF 1ST 1EF (4*32KB)
// ioctl_addr 0A0000..0BFFFF = video ROMs 2U  2J  1U  1J  (4*32KB)
assign gp_wr         = (ioctl_wr && !ioctl_index && ioctl_addr[24:18] < 7'h03 && ioctl_addr[1:0]==2'b11) ? 1'b1 : 1'b0;
// ioctl_addr 0C0000..0CFFFF = CPU ROMS 9A 9B (2*32KB)
assign mp_wr_9A_9B   = (ioctl_wr && !ioctl_index && ioctl_addr[24:16]== 9'h0C && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 0D0000..0DFFFF = NO ROM (2*32KB filler)
// ioctl_addr 0E0000..0EFFFF = NO ROM (2*32KB filler)
// ioctl_addr 0F0000..0F7FFF = CPU ROMS 10A 10B (2*16KB)
assign mp_wr_10A_10B = (ioctl_wr && !ioctl_index && ioctl_addr[24:15]==10'h1E && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 0F8000..0FFFFF = NO ROMS (2*16K filler)
// ioctl_addr 100000..10FFFF = CPU ROMS 7A 7B (2*32KB)
assign mp_wr_7A_7B   = (ioctl_wr && !ioctl_index && ioctl_addr[24:16]== 9'h10 && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 110000..11FFFF = CPU ROMS 6A 6B (2*32KB)
assign mp_wr_6A_6B   = (ioctl_wr && !ioctl_index && ioctl_addr[24:16]== 9'h11 && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 120000..12FFFF = CPU ROMS 5A 5B (2*32KB)
assign mp_wr_5A_5B   = (ioctl_wr && !ioctl_index && ioctl_addr[24:16]== 9'h12 && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 130000..13FFFF = CPU ROMS 3A 3B (2*32KB)
assign mp_wr_3A_3B   = (ioctl_wr && !ioctl_index && ioctl_addr[24:16]== 9'h13 && ioctl_addr[0]==1'b1) ? 1'b1 : 1'b0;
// ioctl_addr 140000..147FFF = AUDIO ROM 16S (32KB)
assign ap_wr_16S     = (ioctl_wr && !ioctl_index && ioctl_addr[24:15]==10'h28 ) ? 1'b1 : 1'b0;
// ioctl_addr 148000..14BFFF = AUDIO ROM 16R (16KB)
assign ap_wr_16R     = (ioctl_wr && !ioctl_index && ioctl_addr[24:14]==11'h52 ) ? 1'b1 : 1'b0;
// ioctl_addr 14C000..14FFFF = CHAR ROM 6P (16KB)
assign cp_wr_6P      = (ioctl_wr && !ioctl_index && ioctl_addr[24:14]==11'h53 ) ? 1'b1 : 1'b0;

assign mp_data =
	mp_addr[18:15] == 4'b0000  ? mp_data_9A_9B :
	mp_addr[18:14] == 5'b00110 ? mp_data_10A_10B :
	mp_addr[18:15] == 4'b0100  ? mp_data_7A_7B :
	mp_addr[18:15] == 4'b0101  ? mp_data_6A_6B :
	mp_addr[18:15] == 4'b0110  ? mp_data_5A_5B :
	mp_addr[18:15] == 4'b0111  ? mp_data_3A_3B :
	{ 16'h0 };

assign ap_data = ap_addr[15] ? ap_data_16S : ap_data_16R;

/*************************************************************/
wire [22:0] sdram_addr;
reg  [31:0] sdram_data=0;
reg         sdram_we=0;
wire        sdram_ready;
wire        ap_en;
wire        gp_en;
wire        mp_en;

// the order in which the files are listed in the .mra file determines the order in which they appear here on the HPS bus
// some files are interleaved as DWORD, some are interleaved as WORD and some are not interleaved and appear as BYTEs
// acc_bytes collects previous bytes so that when a WORD or DWORD is complete it is written to the RAM as appropriate
reg [23:0] acc_bytes = 0;
always @(posedge clk_sys)
	if (ioctl_wr && (!ioctl_index) && ioctl_download )
		acc_bytes<={acc_bytes[15:0],ioctl_dout}; // accumulate previous bytes

always @(posedge clk_sys)
begin
	sdram_we <= 1'b0;
	if (ioctl_wr && (!ioctl_index) && ioctl_download && ioctl_addr[1] && ioctl_addr[0])
	begin
		sdram_data <= {acc_bytes,ioctl_dout};
		sdram_we <= 1'b1;
	end
end

assign sdram_addr = ioctl_download?ioctl_addr[24:2]:{5'd0,gp_addr};
assign ioctl_wait = ~(pll_locked && sdram_ready);

sdram #(.fCK_Mhz(93.06817)) sdram
(
	.I_RST(~pll_locked),
	.I_CLK(clk_sys),

	// controller interface
	.I_ADDR(sdram_addr),
	.I_DATA(sdram_data),
	.I_WE(sdram_we),
	.O_RDY(sdram_ready),
	.O_DATA(gp_data),

	// SDRAM interface
	.SDRAM_DQ(SDRAM_DQ),
	.SDRAM_A(SDRAM_A),
	.SDRAM_BA(SDRAM_BA),
	.SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH),
	.SDRAM_CLK(),
	.SDRAM_CKE(SDRAM_CKE),
	.SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS),
	.SDRAM_nCAS(SDRAM_nCAS),
	.SDRAM_nWE(SDRAM_nWE)
);

/*************************************************************/
	// 256 M10K blocks
//	dpram #(16,32) gp_ram
//	(.clock_a(clk_sys    ), .enable_a(), .wren_a(gp_wr        ), .address_a(ioctl_addr[17:2]), .data_a({acc_bytes[23:0],ioctl_dout}), .q_a(               ),
//	 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   gp_addr[15:0]), .data_b(                            ), .q_b(gp_data        ));

// 64 M10K blocks
dpram #(15,16) mp_ram_9A_9B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_9A_9B  ), .address_a(ioctl_addr[15:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[14:0]), .data_b(                            ), .q_b(mp_data_9A_9B   ));

// 32 M10K blocks
dpram #(14,16) mp_ram_10A_10B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_10A_10B), .address_a(ioctl_addr[14:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[13:0]), .data_b(                            ), .q_b(mp_data_10A_10B));

// 64 M10K blocks
dpram #(15,16) mp_ram_7A_7B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_7A_7B  ), .address_a(ioctl_addr[15:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[14:0]), .data_b(                            ), .q_b(mp_data_7A_7B  ));

// 64 M10K blocks
dpram #(15,16) mp_ram_6A_6B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_6A_6B  ), .address_a(ioctl_addr[15:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[14:0]), .data_b(                            ), .q_b(mp_data_6A_6B  ));

// 64 M10K blocks
dpram #(15,16) mp_ram_5A_5B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_5A_5B  ), .address_a(ioctl_addr[15:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[14:0]), .data_b(                            ), .q_b(mp_data_5A_5B  ));

// 64 M10K blocks
dpram #(15,16) mp_ram_3A_3B
(.clock_a(clk_sys    ), .enable_a(), .wren_a(mp_wr_3A_3B  ), .address_a(ioctl_addr[15:1]), .data_a({acc_bytes[ 7:0],ioctl_dout}), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   mp_addr[14:0]), .data_b(                            ), .q_b(mp_data_3A_3B  ));

// 32 M10K blocks
dpram #(15, 8) ap_ram_16S
(.clock_a(clk_sys    ), .enable_a(), .wren_a(ap_wr_16S    ), .address_a(ioctl_addr[14:0]), .data_a(                 ioctl_dout ), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   ap_addr[14:0]), .data_b(                            ), .q_b(ap_data_16S    ));

// 16 M10K blocks
dpram #(14, 8) ap_ram_16R
(.clock_a(clk_sys    ), .enable_a(), .wren_a(ap_wr_16R    ), .address_a(ioctl_addr[13:0]), .data_a(                 ioctl_dout ), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   ap_addr[13:0]), .data_b(                            ), .q_b(ap_data_16R    ));

// 16 M10K blocks
dpram  #(14,8) cp_ram_6P
(.clock_a(clk_sys    ), .enable_a(), .wren_a(cp_wr_6P     ), .address_a(ioctl_addr[13:0]), .data_a(                 ioctl_dout ), .q_a(               ),
 .clock_b(clk_sys    ), .enable_b(), .wren_b(             ), .address_b(   cp_addr[13:0]), .data_b(                            ), .q_b(cp_data        ));

// total game dpram uses 416 of 553 M10K blocks
PROM_4R_G1 PROM_4R_G1(.CLK(clk_sys), .ADDR(r4_addr), .DATA(r4_data_G1) );
PROM_4R_G2 PROM_4R_G2(.CLK(clk_sys), .ADDR(r4_addr), .DATA(r4_data_G2) );
PROM_4R_V2 PROM_4R_V2(.CLK(clk_sys), .ADDR(r4_addr), .DATA(r4_data_V2) );

assign r4_data = (slap_type == 118)?r4_data_V2:(slap_type == 106)?r4_data_G2:r4_data_G1;

FPGA_GAUNTLET gauntlet
(
	.I_CLK_7M    (clk_7M),
	.I_CLK_14M   (clk_14M),

	.I_RESET     (reset),

	.I_P1        (I_P1),
	.I_P2        (I_P2),
	.I_P3        (I_P3),
	.I_P4        (I_P4),
	
	.I_SYS       ({m_service, ~(m_coin1 | joystick_0_mux[8]), ~(m_coin2 | joystick_1_mux[8]), ~(m_coin3 | joystick_2_mux[8]), ~(m_coin4 | joystick_3_mux[8])}),
	.I_SLAP_TYPE (slap_type),

	.O_LEDS      (),

	.O_AUDIO_L   (aud_l),
	.O_AUDIO_R   (aud_r),

	.O_VIDEO_I   (gvid_I),
	.O_VIDEO_R   (gvid_R),
	.O_VIDEO_G   (gvid_G),
	.O_VIDEO_B   (gvid_B),
	.O_HSYNC     (HSync),
	.O_VSYNC     (VSync),
	.O_CSYNC     (),
	.O_HBLANK    (HBlank),
	.O_VBLANK    (VBlank),

	.O_GP_EN     (gp_en),
	.O_GP_ADDR   (gp_addr),
	.I_GP_DATA   (gp_data),

	.O_CP_ADDR   (cp_addr),
	.I_CP_DATA   (cp_data),

	.O_MP_EN     (mp_en),
	.O_MP_ADDR   (mp_addr),
	.I_MP_DATA   (mp_data),

	.O_4R_ADDR   (r4_addr),
	.I_4R_DATA   (r4_data),

	.O_AP_EN     (ap_en),
	.O_AP_ADDR   (ap_addr),
	.I_AP_DATA   (ap_data)
);
endmodule
