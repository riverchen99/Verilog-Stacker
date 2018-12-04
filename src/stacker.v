module Stacker(
	master_clk,
	game_pulse,
	btn,
	rst,
	paused,
	state,
	block_pos,
	block_width,
	block_height,
	board);
	parameter MAX_HEIGHT = 10;
	parameter MAX_WIDTH = 9;
	input wire master_clk, game_pulse, btn, rst, paused;
	output reg [1:0] state = 0; // 0 in progress, 1 win, 2 lose
	output reg [3:0] block_pos = 0;
	output reg [1:0] block_width = 3;
	output reg [3:0] block_height = 0;
	reg dir = 1; // 1 for going right
	output reg [89:0] board = {90{1'b0}}; // 9 wide by 10 tall
	reg [8:0] tempRow = 111000000;
	reg [1:0] oneCount;
	reg [3:0] i;
	always @(posedge master_clk) begin
		if (~paused) begin
			if (rst) begin
				block_pos <= 0;
				block_width <= 3;
				block_height <= 0;
				board <= {90{1'b0}};
				tempRow <= 111000000;
				state <= 0;
				dir <= 1;
			end else if (btn && state == 0) begin
				if (block_height == 0) begin
					board[8:0] <= tempRow;
					oneCount = 3;
				end else begin
					// board[block_height*MAX_WIDTH+8 : block_height*MAX_WIDTH]
					board[(block_height)*MAX_WIDTH +: 9] <= board[(block_height-1)*MAX_WIDTH +: 9] & tempRow;
					oneCount = 0;
					for (i = 0; i < 9; i = i+1) begin
						oneCount = oneCount + (board[(block_height-1)*MAX_WIDTH+i] & tempRow[i]);
						//$display("%b %b \n",board[(block_height-1)*MAX_WIDTH+i], tempRow[i]);
					end
					block_width <= oneCount;
				end
	 
				if (oneCount == 0) begin
					state <= 2;
				end else if (block_height == 9) begin
					state <= 1;
					block_height <= block_height + 1;
				end else begin
					block_height <= block_height + 1;
				end
	 
				$display("%d\n",oneCount);
				block_pos <= 0;
				/*
				if (block_height == 5 && oneCount == 3) begin
					tempRow <= 110000000;
				end else if (block_height == 8 && oneCount == 2) begin
					tempRow <= 100000000;
				end else begin
					tempRow <= 111000000 << (3-oneCount);
				end
				*/
				tempRow <= 111000000 << (3-oneCount);
				$display("btn press");
				dir <= 1;
			end else if (game_pulse && state == 0) begin
				if (block_pos + block_width > MAX_WIDTH-1-1) begin
					dir <= 0;
				end else if (block_pos == 1) begin
					dir <= 1;
				end
				if (dir == 1) begin
					block_pos <= block_pos + 1;
					tempRow <= tempRow >> 1;
				end else begin
					block_pos <= block_pos - 1;
					tempRow <= tempRow << 1;
				end
				$display("clock without btn");
			end
			$display("height %d", block_height);
			$display("pos %d", block_pos);
			$display("temprow \n %b\n", tempRow);
			$display("board \n %b\n",board[(block_height-1)*MAX_WIDTH +: 9]);
		end
	end
endmodule