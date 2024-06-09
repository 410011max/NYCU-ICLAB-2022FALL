// synopsys translate_off 
`ifdef RTL
`include "GATED_OR.v"
`else
`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SP(
	// Input signals
	input clk,
	input rst_n,
	input cg_en,
	input in_valid,
	input signed [8:0] in_data,
	input [2:0] in_mode,
	// Output signals
	output reg out_valid,
	output reg signed [9:0] out_data
);

//---------------------------------------------------------------------
//   Parameter
//---------------------------------------------------------------------
genvar i;
integer k;
localparam INPUT  = 0,
		   MODE   = 1,
		   IDLE   = 2,
		   OUTPUT = 3;
			  
//---------------------------------------------------------------------
//   Wire & Reg Declaration
//---------------------------------------------------------------------
reg [1:0] c_state, n_state;
reg [3:0] counter;
reg [2:0] in_mode_reg;
wire gary_mode;
wire signed [8:0] data_in;
reg signed [8:0] data_temp[0:8], data[0:8], data_mode[0:8];
reg signed [8:0] bin_data;
reg signed [8:0] max_temp, min_temp, max_reg, min_reg;
wire signed [8:0] midpoint, difference, mode_1_out[0:8], mode_2_out[0:8], mode_out[0:8];
wire signed [8:0] max[0:2], min[0:2], med[0:2];
wire signed [8:0] min_m, med_m, max_m;
wire signed [8:0] max_ans, min_ans, med_ans;

//---------------------------------------------------------------------
//   Clock Gating
//---------------------------------------------------------------------
wire gclk[0:8];
wire cg_input[0:8];
wire cg_gray = (gary_mode && in_valid);
wire cg_cal = (c_state == MODE || c_state == IDLE);
GATED_OR GATED_OR_1 (.CLOCK(clk), .SLEEP_CTRL(cg_en && !(c_state == INPUT)), .RST_N(rst_n), .CLOCK_GATED(gclk_input));
GATED_OR GATED_OR_2 (.CLOCK(clk), .SLEEP_CTRL(cg_en && !cg_cal), .RST_N(rst_n), .CLOCK_GATED(gclk_cal));
generate
	for(i=0;i<9;i=i+1) begin
		assign cg_input[i] = (c_state == INPUT && counter == i);
		GATED_OR GATED_OR_input (.CLOCK(clk), .SLEEP_CTRL(cg_en && !cg_input[i]), .RST_N(rst_n), .CLOCK_GATED(gclk[i]));
	end
endgenerate

//---------------------------------------------------------------------
//   Design
//---------------------------------------------------------------------

// in_mode
always @(posedge gclk_input or negedge rst_n) begin
	if(!rst_n) in_mode_reg <= 0;
	else in_mode_reg <= (in_valid && counter == 0)? in_mode : in_mode_reg;
end

// gray code
assign gary_mode = (in_valid && counter == 0)? in_mode[0] : in_mode_reg[0];
assign data_in = (gary_mode)? bin_data : in_data;
always @(*) begin
	if(cg_gray) begin
		bin_data[8] = in_data[8];
		bin_data[7] = in_data[7];
		bin_data[6] = bin_data[7] ^ in_data[6];
		bin_data[5] = bin_data[6] ^ in_data[5];
		bin_data[4] = bin_data[5] ^ in_data[4];
		bin_data[3] = bin_data[4] ^ in_data[3];
		bin_data[2] = bin_data[3] ^ in_data[2];
		bin_data[1] = bin_data[2] ^ in_data[1];
		bin_data[0] = bin_data[1] ^ in_data[0];
		bin_data = (bin_data[8])? ~bin_data[7:0] + 1 : bin_data;
	end
	else bin_data = 0;
end

// calculate max/med/min
generate
	for(i=0;i<3;i=i+1)
		FIND_MMM u_MMM (.data_1(data_mode[i*3]), .data_2(data_mode[i*3+1]), .data_3(data_mode[i*3+2]),
						.max(max[i]), .med(med[i]), .min(min[i]));
endgenerate
FIND_MMM u_max (.data_1(max[0]), .data_2(max[1]), .data_3(max[2]), .max(max_ans));
FIND_MMM u_min (.data_1(min[0]), .data_2(min[1]), .data_3(min[2]), .min(min_ans));
FIND_MMM u_med_1 (.data_1(max[0]), .data_2(max[1]), .data_3(max[2]), .min(min_m));
FIND_MMM u_med_2 (.data_1(med[0]), .data_2(med[1]), .data_3(med[2]), .med(med_m));
FIND_MMM u_med_3 (.data_1(min[0]), .data_2(min[1]), .data_3(min[2]), .max(max_m));
FIND_MMM u_med (.data_1(min_m), .data_2(med_m), .data_3(max_m), .med(med_ans));


// store data
always @(posedge gclk[0] or negedge rst_n) data_temp[0] <= (!rst_n)? 0 : (cg_input[0])? data_in : data_temp[0];
always @(posedge gclk[1] or negedge rst_n) data_temp[1] <= (!rst_n)? 0 : (cg_input[1])? data_in : data_temp[1];
always @(posedge gclk[2] or negedge rst_n) data_temp[2] <= (!rst_n)? 0 : (cg_input[2])? data_in : data_temp[2];
always @(posedge gclk[3] or negedge rst_n) data_temp[3] <= (!rst_n)? 0 : (cg_input[3])? data_in : data_temp[3];
always @(posedge gclk[4] or negedge rst_n) data_temp[4] <= (!rst_n)? 0 : (cg_input[4])? data_in : data_temp[4];
always @(posedge gclk[5] or negedge rst_n) data_temp[5] <= (!rst_n)? 0 : (cg_input[5])? data_in : data_temp[5];
always @(posedge gclk[6] or negedge rst_n) data_temp[6] <= (!rst_n)? 0 : (cg_input[6])? data_in : data_temp[6];
always @(posedge gclk[7] or negedge rst_n) data_temp[7] <= (!rst_n)? 0 : (cg_input[7])? data_in : data_temp[7];
// *****  synthesis BUG (gclk[8])  *****
always @(posedge gclk_input or negedge rst_n) data_temp[8] <= (!rst_n)? 0 : (cg_input[8])? data_in : data_temp[8]; 

// *****  synthesis BUG (can't use generate)  *****
always @(posedge gclk[8] or negedge rst_n) begin 
	if(!rst_n) begin
		for(k=0;k<9;k=k+1)
			data[k] <= 0;
	end
	else begin
		if(in_mode_reg[2:1] && cg_input[8]) begin
			for(k=0;k<8;k=k+1)
				data[k] <= data_temp[k];
			data[8] <= data_in;
		end
	end
end

// generate
// 	for(i=0;i<8;i=i+1)
// 		always @(posedge gclk[8] or negedge rst_n) begin
// 			if(!rst_n) data[i] <= 0;
// 			else if(in_mode_reg[2:1] && cg_input[8]) data[i] <= data_temp[i];
// 		end
// endgenerate
// always @(posedge gclk[8] or negedge rst_n) data[8] <= (!rst_n)? 0 : (cg_input[8])? data_in : data[8];


// max/min for mode_1 (+-)
always @(posedge gclk_input or negedge rst_n) begin
	if(!rst_n) begin
		max_temp <= -256;
		min_temp <= 255;
	end
	else begin
		if(c_state == INPUT) begin
			if(in_valid) begin
				max_temp <= (data_in > max_temp)? data_in : max_temp;
				min_temp <= (data_in < min_temp)? data_in : min_temp;
			end
			else begin
				max_temp <= -256;
				min_temp <= 255;
			end
		end
	end
end

// ***** synthesis BUG (gclk[8])  *****
always @(posedge gclk_input or negedge rst_n) begin
	if(!rst_n) begin
		max_reg <= -256;
		min_reg <= -255;
	end
	else begin
		if(in_mode_reg[1] && cg_input[8]) begin
			max_reg <= (data_in > max_temp)? data_in : max_temp;
			min_reg <= (data_in < min_temp)? data_in : min_temp;
		end
	end
end

// calculate mode 1 & 2
assign midpoint = (max_reg + min_reg) /2;
assign difference = (max_reg - min_reg) /2;
generate
	for(i=0;i<9;i=i+1) begin
		assign mode_1_out[i] = (!in_mode_reg[1])? data[i] : (data[i] == midpoint)? data[i] : (data[i] > midpoint)? data[i] - difference : data[i] + difference;
		assign mode_2_out[i] = (mode_1_out[(i+8)%9] + mode_1_out[i] + mode_1_out[(i+1)%9]) /3;
		assign mode_out[i] = (in_mode_reg[2])? mode_2_out[i] : mode_1_out[i]; 
	end
endgenerate

// *****  synthesis BUG (can't use generate)  *****
always @(posedge gclk_cal or negedge rst_n) begin
	if(!rst_n) begin
		for(k=0;k<9;k=k+1) 
			data_mode[k] <= 0;
	end
	else begin
		if(c_state == MODE)
			for(k=0;k<9;k=k+1) 
				data_mode[k] <= mode_out[k];
		else if(c_state == IDLE)
			for(k=0;k<9;k=k+1) 
				data_mode[k] <= data_temp[k];
	end
end

// generate
// 	for(i=0;i<9;i=i+1)
// 		always @(posedge gclk_cal or negedge rst_n) begin
// 			if(!rst_n) data_mode[i] <= 0;
// 			else begin 
//				if(c_state == MODE) data_mode[i] <= mode_out[i];
// 				else if(c_state == IDLE) data_mode[i] <= data_temp[i];
//			end
// 		end
// endgenerate

// counter
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) counter <= 0;
	else begin
		case (c_state)
			INPUT: counter <= (counter == 8)? 0 : (in_valid)? counter + 1 : 0;
			OUTPUT: counter <= (counter == 2)? 0 : counter + 1;
			default: counter <= 0;
		endcase
	end
end

// output
always @(*) begin
	// if(!rst_n) begin
	// 	out_valid <= 0;
	// 	out_data <= 0;
	// end
	// else begin
		out_valid <= (c_state == OUTPUT && counter < 3);
		if(c_state == OUTPUT)
			case (counter)
				0: out_data <= max_ans;
				1: out_data <= med_ans;
				2: out_data <= min_ans;
				default: out_data <= 0;
			endcase
		else out_data <= 0;
	// end
end

// FSM
always @(*) begin
	case (c_state)
		INPUT:   n_state = (counter < 8)? INPUT : (in_mode_reg[2:1])? MODE : IDLE;
		MODE:    n_state = OUTPUT;
		IDLE:    n_state = OUTPUT;
		OUTPUT:  n_state = (counter == 2)? INPUT : OUTPUT;
		default: n_state = INPUT;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= INPUT;
	else c_state <= n_state;
end

endmodule


module FIND_MMM(
	input signed [8:0] data_1,
	input signed [8:0] data_2,
	input signed [8:0] data_3,
	output reg signed [8:0] max,
	output reg signed [8:0] med,
	output reg signed [8:0] min
);

always @(*) begin
	if(data_1 >= data_2 && data_1 >= data_3) begin
		max <= data_1;
		med <= (data_2 >= data_3)? data_2 : data_3;
		min <= (data_2 >= data_3)? data_3 : data_2;
	end
	else if(data_2 >= data_3)begin
		max <= data_2;
		med <= (data_1 >= data_3)? data_1 : data_3;
		min <= (data_1 >= data_3)? data_3 : data_1;
	end
	else begin
		max <= data_3;
		med <= (data_1 >= data_2)? data_1 : data_2;
		min <= (data_1 >= data_2)? data_2 : data_1;
	end
end

endmodule