module nexys3(
	input wire clk,             // board clock: 100 MHz on Arty/Basys3/Nexys
	input wire btnS,
	input wire btnU,
	input wire btnR,
	input wire btnL,
	input wire btnD,
	input wire [1:0] sw,
	input wire external_btn,
	output wire [6:0] seg,
	output wire [3:0] an,
	output reg [7:0] led,
	output wire Hsync,       // horizontal sync output
	output wire Vsync,       // vertical sync output
	output reg [3:0] vgaRed,     // 4-bit VGA red output
	output reg [3:0] vgaGreen,     // 4-bit VGA green output
	output reg [3:0] vgaBlue      // 4-bit VGA blue output
	);

	reg [1:0]   arst_ff;
	assign arst_i = btnS; // center button rst
	assign rst = arst_ff[0];
	always @ (posedge clk or posedge arst_i) begin
		if (arst_i)
			arst_ff <= 2'b11;
		else
			arst_ff <= {1'b0, arst_ff[1]};
	end

	reg [16:0]  clk_dv;
	reg         clk_en;
	reg         clk_en_d;
	wire [17:0] clk_dv_inc;
	assign clk_dv_inc = clk_dv + 1;
	always @ (posedge clk) begin
		if (rst) begin
			clk_dv   <= 0;
			clk_en   <= 1'b0;
			clk_en_d <= 1'b0;
		end else begin
			clk_dv   <= clk_dv_inc[16:0];
			clk_en   <= clk_dv_inc[17];
			clk_en_d <= clk_en;
		end
	end

	reg [2:0] step_d_r, step_d_l, step_d_hs, step_d_d, step_d_u;
	always @ (posedge clk) begin
		if (rst) begin
			step_d_r[2:0] <= 0;
			step_d_l[2:0] <= 0;
			step_d_hs[2:0] <= 0;
			step_d_d[2:0] <= 0;
			step_d_u[2:0] <= 0;
		end else if (clk_en) begin
			step_d_r[2:0]  <= {external_btn, step_d_r[2:1]};
			step_d_l[2:0]  <= {btnL, step_d_l[2:1]};
			step_d_hs[2:0] <= {btnR, step_d_hs[2:1]};
			step_d_d[2:0] <= {btnD, step_d_d[2:1]};
			step_d_u[2:0] <= {btnU, step_d_u[2:1]};
		end
	end

	// Detecting posedge of btnS
	wire is_btnR_posedge = ~ step_d_r[0] & step_d_r[1];
	wire is_btnL_posedge = ~ step_d_l[0] & step_d_l[1];
	wire is_btnHS_posedge = ~ step_d_hs[0] & step_d_hs[1];
	wire is_btnD_posedge = ~ step_d_d[0] & step_d_d[1];
	wire is_btnU_posedge = ~ step_d_u[0] & step_d_u[1];
	reg prev_posedge_r, btnR_pulse;
	reg prev_posedge_l, btnL_pulse;
	reg prev_posedge_hs, btnHS_pulse;
	reg prev_posedge_d, btnD_pulse;
	reg prev_posedge_u, btnU_pulse;
	always @ (posedge clk) begin
		prev_posedge_r <= is_btnR_posedge;
		prev_posedge_l <= is_btnL_posedge;
		prev_posedge_hs <= is_btnHS_posedge;
		prev_posedge_d <= is_btnD_posedge;
		prev_posedge_u <= is_btnU_posedge;
		btnR_pulse <= ~prev_posedge_r & is_btnR_posedge;
		btnL_pulse <= ~prev_posedge_l & is_btnL_posedge;
		btnHS_pulse <= ~prev_posedge_hs & is_btnHS_posedge;
		btnD_pulse <= ~prev_posedge_d & is_btnD_posedge;
		btnU_pulse <= ~prev_posedge_u & is_btnU_posedge;
	end
	reg displayHS = 0;
	always @ (clk) begin
		if (rst) begin
			displayHS <= 0;
		end else if (btnHS_pulse) begin
			displayHS <= ~displayHS;
		end
	end
	
	reg paused = 0;
	always @(clk) begin
		if (btnD_pulse) begin
			paused <= ~paused;
		end
	end

	wire [1:0] state_L, state_R;
	wire [3:0] block_pos_L, block_pos_R;
	wire [1:0] block_width_L, block_width_R;
	wire [3:0] block_height_L, block_height_R;
	wire [89:0] board_L, board_R;

	wire game_pulse_L, game_pulse_R;
	ClockDivider cd_L(
	.clk(clk),
	.rst(rst),
	.height(block_height_L),
	.game_pulse(game_pulse_L));
	ClockDivider cd_R(
	.clk(clk),
	.rst(rst),
	.height(block_height_R),
	.game_pulse(game_pulse_R));

	Stacker gameL(
	.master_clk(clk),
	.game_pulse(game_pulse_L),
	.btn(btnL_pulse),
	.rst(rst),
	.paused(paused),
	.state(state_L),
	.block_pos(block_pos_L),
	.block_width(block_width_L),
	.block_height(block_height_L),
	.board(board_L));
	Stacker gameR(
	.master_clk(clk),
	.game_pulse(game_pulse_R),
	.btn(btnR_pulse),
	.rst(rst),
	.paused(paused),
	.state(state_R),
	.block_pos(block_pos_R),
	.block_width(block_width_R),
	.block_height(block_height_R),
	.board(board_R));

	always @(clk) begin
		if (sw[1]) begin
			led[1:0] = state_R;
			led[3:2] = state_L;
			led[4] = displayHS;
			led[7:5] = 0;
		end else if (sw[0]) begin
			led[7:4] = block_height_L;
			led[3:0] = block_pos_L;
		end else begin
			led[7:4] = block_height_R;
			led[3:0] = block_pos_R;
		end
	end

	reg [3:0] hs = 0;
	reg [3:0] tempMax;
	always @(clk) begin
		if (btnU_pulse) begin
			hs <= 0;
		end else begin
			tempMax = block_height_L > block_height_R ? block_height_L : block_height_R;
			if (tempMax > hs) begin
				hs <= tempMax;
			end
		end
	end
	reg [31:0] scoreClockCount = 0;
	reg scoreClock;
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			scoreClockCount <= 0;
			scoreClock <= 0;
		end else if (scoreClockCount == 200000 - 1) begin
			scoreClockCount <= 0;
			scoreClock <= ~scoreClock;
		end else begin
			scoreClockCount <= scoreClockCount + 1;
			scoreClock <= scoreClock;
		end
	end
	ScoreDisplay sd(
	.rst(rst), 
	.clk(scoreClock), 
	.pA_score(block_height_L), 
	.pB_score(block_height_R), 
	.highscore(hs), 
	.highscore_disp(displayHS), 
	.seg(seg), 
	.an(an));

	reg [15:0] cnt;
	reg pix_stb; 
	always @(posedge clk)
	{pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000
	
	wire [9:0] x;  // current pixel x position: 10-bit value: 0-1023
	wire [9:0] y;  // current pixel y position:  9-bit value: 0-511
	//wire active;   // high during active pixel drawing
	 vga640x480 display(
	.dclk(pix_stb),			//pixel clock: 25MHz
	.clr(rst),			//asynchronous reset
	.hsync(Hsync),		//horizontal sync out
	.vsync(Vsync),		//vertical sync out
	.hc(x),
	.vc(y));

	parameter hbp = 144; 	// end of horizontal back porch
	parameter hfp = 784; 	// beginning of horizontal front porch
	parameter vbp = 35; 	// end of vertical back porch
	parameter vfp = 515; 	// beginning of vertical front porch
	
	reg [8:0] boardX, boardY;
	reg [11:0] color;
	reg [1:0] draw_state;
	reg [3:0] draw_block_pos;
	reg [1:0] draw_block_width;
	reg [3:0] draw_block_height;
	reg [89:0] draw_board;
	always @(*) begin
		if (y >= vbp && y < vfp && x >= hbp && x < hfp) begin
			boardX = (x-hbp) < 325 ? (x-hbp)/35 : (x-hbp-325)/35;
			boardY = 9 - (y - vbp)/35;
			color = (x-hbp) < 325 ? 12'b111100000000 : 12'b000000001111;
			draw_state = (x-hbp) < 325 ? state_L : state_R;
			draw_block_pos = (x-hbp) < 325 ? block_pos_L : block_pos_R;
			draw_block_width = (x-hbp) < 325 ? block_width_L : block_width_R;
			draw_block_height = (x-hbp) < 325 ? block_height_L : block_height_R;
			draw_board = (x-hbp) < 325 ? board_L : board_R;
			if (x - hbp >= 315 && x - hbp < 325) begin // line in between
				{vgaRed, vgaGreen, vgaBlue} = 12'b0;
			end else if (boardX < 9 && boardY < 10) begin
				if (draw_state == 1) begin // fill the screen with color (win)
					{vgaRed, vgaGreen, vgaBlue} = color;
				end else if (draw_state == 2) begin // fill the screen with black (lose)
					{vgaRed, vgaGreen, vgaBlue} = 12'b0;
				end else if (
					((boardX >= draw_block_pos && boardX < draw_block_pos + draw_block_width && boardY == draw_block_height) ||
					(draw_board[boardY * 9 + (8 - boardX)] == 1))
					) begin // draw block/board
					{vgaRed, vgaGreen, vgaBlue} = color;
				end else begin // draw background
					if (paused) begin
						{vgaRed, vgaGreen, vgaBlue} = 12'b011101110111;
					end else begin
						{vgaRed, vgaGreen, vgaBlue} = 12'b111111111111;
					end
				end
			end
		end else begin
			{vgaRed, vgaGreen, vgaBlue} = 12'b0;
		end
	end
endmodule