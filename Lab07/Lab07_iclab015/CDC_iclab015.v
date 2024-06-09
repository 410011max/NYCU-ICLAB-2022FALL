`include "synchronizer.v"
`include "syn_XOR.v"

module CDC(
	// Input Port
	input clk1,
    input clk2,
    input clk3,
	input rst_n,
	input in_valid1,
	input in_valid2,
	input [3:0] user1,
	input [3:0] user2,

    // Output Port
    output reg out_valid1,
    output reg out_valid2,
	output reg equal,
	output reg exceed,
	output reg winner
); 
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
genvar i;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
//----clk1----
wire [4:0] card_in, card_in_temp;
reg [5:0] card[0:10];
reg [5:0] card_p1, card_p2;
wire [5:0] card_p2_new;
reg [3:0] counter;
reg out_valid1_flag1;
reg out_valid2_flag1;
reg [1:0] winner_reg;
wire [4:0] point, point_1, point_2;
reg [12:0] equal_div_in_reg, exceed_div_in_reg;
//----clk2----

//----clk3----
wire out_valid1_flag3;
wire out_valid2_flag3;
reg [6:0] equal_div_in_reg2, exceed_div_in_reg2;
reg [5:0] total_card_reg;
reg [2:0] counter_out1;
reg [1:0] counter_out2;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
//============================================
//   clk1 domain
//============================================
// total card table (number of card above n)
assign card_in_temp = (in_valid1)? user1 : (in_valid2)? user2 : 0;
assign card_in = (card_in_temp > 10)? 'd1 : card_in_temp;
generate
	for(i=0;i<=10;i=i+1)
		always @(posedge clk1 or negedge rst_n) begin
			if(!rst_n) begin
				card[i] <= (i == 0)? 'd52 : 'd40 - 4*i;
			end 
			else if(in_valid1 || in_valid2) begin
				if(card[0] == 3) card[i] <= (i == 0)? 'd52 : 'd40 - 4*i;
				else card[i] <= (i < card_in)? card[i] - 'd1 : card[i];
			end
		end
endgenerate

// counter
always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) counter <= 0;
	else counter <= (counter == 9)? 0 : (in_valid1 || in_valid2)? counter + 'd1 : counter;
end

// winner
assign card_p2_new = (card_in > 10)? card_p2 + 'd1 : card_p2 + card_in;
always@(posedge clk1 or negedge rst_n) begin
	if(!rst_n) begin
		card_p1 <= 0;
		card_p2 <= 0;
	end
	else begin
		if(counter < 9) begin
			card_p1 <= (!in_valid1)? card_p1 : (card_in > 10)? card_p1 + 'd1 : card_p1 + card_in;
			card_p2 <= (!in_valid2)? card_p2 : (card_in > 10)? card_p2 + 'd1 : card_p2 + card_in;
		end
		else begin
			card_p1 <= 0;
			card_p2 <= 0;
			if((card_p1 > 21 && card_p2_new > 21) || card_p1 == card_p2_new)
				winner_reg <= 'b00;
			else if((card_p1 > card_p2_new && (card_p1 <= 21)) || card_p2_new > 21)
				winner_reg <= 'b10;
			else
				winner_reg <= 'b11;
		end
	end
end

always @(posedge clk1 or negedge rst_n) begin
	if(!rst_n) out_valid2_flag1 <= 0;
	else out_valid2_flag1 <= (counter == 9);
end

// euqal & exceed
assign point_1 = (card_p1 > 21)? 0 : 'd21 - card_p1;
assign point_2 = (card_p2 > 21)? 0 : 'd21 - card_p2;
assign point = (counter <= 4)? point_1 : point_2;

always @(posedge clk1) begin
	equal_div_in_reg <= (point > 10 || point == 0)? 0 : (card[point - 1] - card[point]) * 100;
	exceed_div_in_reg <= (point > 10)? 0 : card[point] * 100;
	total_card_reg <= card[0];
end

always @(posedge clk1 or negedge rst_n) begin
	if(!rst_n) out_valid1_flag1 <= 0;
	else out_valid1_flag1 <= (counter == 2 || counter == 3 || counter == 7 || counter == 8);
end

//============================================
//   clk2 domain
//============================================

//============================================
//   clk3 domain
//============================================
// output 1 (equal & exceed)
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		counter_out1 <= 0;
		out_valid1 <= 0;
		equal <= 0;
		exceed <= 0;
	end 
	else begin
		counter_out1 <= (counter_out1 != 0)? counter_out1 + 'd1 : (out_valid1_flag3)? 'd1 : 'd0;
		out_valid1 <= (counter_out1 > 0);
		if(out_valid1_flag3) begin
			equal_div_in_reg2 <= equal_div_in_reg[12:6];
			exceed_div_in_reg2 <= exceed_div_in_reg[12:6];
		end
		else if(counter_out1 >= 1) begin
			equal <= (equal_div_in_reg2 >= total_card_reg)? 1 : 0;
			exceed <= (exceed_div_in_reg2 >= total_card_reg)? 1 : 0;
			equal_div_in_reg2 <= (equal_div_in_reg2 >= total_card_reg)? 
									((equal_div_in_reg2 - total_card_reg) << 1) + equal_div_in_reg[6 - counter_out1] : 
									{equal_div_in_reg2[5:0], equal_div_in_reg[6 - counter_out1]};
			exceed_div_in_reg2 <= (exceed_div_in_reg2 >= total_card_reg)? 
									((exceed_div_in_reg2 - total_card_reg) << 1) + exceed_div_in_reg[6 - counter_out1] : 
									{exceed_div_in_reg2[5:0], exceed_div_in_reg[6 - counter_out1]};
		end
		else begin
			equal <= 0;
			exceed <= 0;
		end
	end
end

// output 2 (winner)
always@(posedge clk3 or negedge rst_n) begin
	if(!rst_n) begin
		counter_out2 <= 0;
		out_valid2 <= 0;
		winner <= 0;
	end 
	else begin
		counter_out2 <= (counter_out2 != 0)? counter_out2 + 'd1 : (out_valid2_flag3)? 'd1 : 'd0;
		if(counter_out2 == 1) begin
			out_valid2 <= 1;
			winner <= winner_reg[1];
		end
		else if(counter_out2 == 2 && winner_reg != 2'b00) begin
			out_valid2 <= 1;
			winner <= winner_reg[0];
		end
		else begin
			out_valid2 <= 0;
			winner <= 0;
		end
	end
end

//---------------------------------------------------------------------
//   syn_XOR
//---------------------------------------------------------------------
syn_XOR u_1to3_1 (.IN(out_valid1_flag1),.OUT(out_valid1_flag3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));
syn_XOR u_1to3_2 (.IN(out_valid2_flag1),.OUT(out_valid2_flag3),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));

endmodule