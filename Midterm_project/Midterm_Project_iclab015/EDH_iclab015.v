//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW01_addsub.v"
//synopsys translate_on

module EDH(
           // input signal
		   input clk,
           input rst_n,
           input in_valid,
           input [1:0] op,
           input [3:0] pic_no,
           input [5:0] se_no,

		   // output signal
           output reg busy,

           // axi write address channel
           output wire [3:0] 		awid_m_inf,    // fixed
		   output wire [2:0] 		awsize_m_inf,  // fixed
           output wire [1:0] 		awburst_m_inf, // fixed
           output reg [31:0] 		awaddr_m_inf,
           output wire [7:0] 		awlen_m_inf,
           output reg 				awvalid_m_inf,
           input 					awready_m_inf, 
           // axi write data channel
           output reg [127:0] 		wdata_m_inf,
           output reg				wlast_m_inf,
           output reg				wvalid_m_inf,
           input 					wready_m_inf,
           // axi write response channel
           input [3:0] 	bid_m_inf,
           input [1:0] 				bresp_m_inf,
           input 					bvalid_m_inf,
           output reg				bready_m_inf,
           // ----------------------------------------
           // axi read address channel
           output wire [3:0] 		arid_m_inf,    // fixed
		   output wire [2:0] 		arsize_m_inf,  // fixed
           output wire [1:0] 		arburst_m_inf, // fixed
           output reg [31:0] 		araddr_m_inf,
           output wire [7:0] 		arlen_m_inf,
           output reg 				arvalid_m_inf,
           input 					arready_m_inf,
           // axi read data channel
           input [3:0] 				rid_m_inf,   // fixed
		   input [1:0] 				rresp_m_inf, // fixed
           input [127:0] 			rdata_m_inf,
           input 					rlast_m_inf, 
           input 					rvalid_m_inf,
           output reg				rready_m_inf
       );

//---------------------------------------------------------------------
//   Parameter
//---------------------------------------------------------------------
genvar i, j, k;
localparam INPUT     = 0,
		   INPUT_se  = 1,
		   DRAM_se   = 2,
		   INPUT_pic = 3,
		   DRAM_pic  = 4,
		   INPUT_his = 5,
		   DRAM_his  = 6,
		   CAL_cdfm  = 7,
		   CAL_his   = 8,
		   OUTPUT_A  = 9,
		   OUTPUT_D  = 10;

//---------------------------------------------------------------------
//   Wire & Reg Declaration
//---------------------------------------------------------------------
reg [3:0] c_state, n_state;
reg [8:0] counter;
reg [1:0] op_reg;
reg [3:0] pic_no_reg;
reg [5:0] se_no_reg;
reg [7:0] se_reg[0:3][0:3];
reg [7:0] pic_reg[0:3][0:66];

//---------------------------------------------------------------------
//   Design
//---------------------------------------------------------------------
// axi read channel signal
assign arid_m_inf = 4'd0; 		// fixed id to 0 
assign arburst_m_inf = 2'd1;	// fixed to INCR mode
assign arsize_m_inf = 3'b100;	// fixed size = 3'b100 (16 Bytes)
assign arlen_m_inf = (c_state == INPUT || c_state == DRAM_se)? 8'd0 : 8'd255;    // Read 1 or 256 data

// axi write channel signal
assign awid_m_inf = 4'd0;		// fixed id to 0 
assign awburst_m_inf = 2'd1;	// fixed to INCR mode
assign awsize_m_inf = 3'b100;	// fixed size = 3'b100 (16 Bytes)
assign awlen_m_inf = 8'd255;	// Write continuous 256 data


// signal for Read & Write of DRAM
reg rvalid_buffer, rvalid_buffer2;
reg rlast_buffer, rlast_buffer2;
reg wlast_buffer;

always @(posedge clk) begin
	rvalid_buffer <= rvalid_m_inf;
	rvalid_buffer2 <= rvalid_buffer;
	rlast_buffer <= rlast_m_inf;
	rlast_buffer2 <= rlast_buffer;
	wlast_buffer <= wlast_m_inf;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		counter <= 0;
		arvalid_m_inf <= 0;
		awvalid_m_inf <= 0;
		rready_m_inf <= 0;
		wvalid_m_inf <= 0;
		wlast_m_inf <= 0;
	end
	else begin
		case (c_state)
			INPUT: begin
				counter <= 0;
			end 
			INPUT_se: begin
				arvalid_m_inf <= 1;
				araddr_m_inf <= 'h30000 + (se_no_reg << 4); // se_no
				counter <= 0;
			end
			DRAM_se: begin
				arvalid_m_inf <= (arready_m_inf)? 0 : arvalid_m_inf;
				rready_m_inf <= (rlast_m_inf)? 0 : 1;
				counter <= counter + 'd1;
			end
			INPUT_pic: begin
				arvalid_m_inf <= 1;
				araddr_m_inf <= 'h40000 + (pic_no_reg << 12); // pic_no
				counter <= 0;
			end
			DRAM_pic: begin
				arvalid_m_inf <= (arready_m_inf)? 0 : arvalid_m_inf;
				rready_m_inf <= (rlast_m_inf)? 0 : 1;
				counter <= (counter == 273)? 0 : (rvalid_m_inf)? counter + 'd1 : (counter >= 255)? counter + 'd1 : counter;
			end
			INPUT_his: begin
				arvalid_m_inf <= 1;
				araddr_m_inf <= 'h40000 + (pic_no_reg << 12); // pic_no
				counter <= 0;
			end
			DRAM_his: begin
				arvalid_m_inf <= (arready_m_inf)? 0 : arvalid_m_inf;
				rready_m_inf <= (rlast_m_inf)? 0 : 1;
				counter <= (rlast_buffer2)? 0 : (rvalid_buffer)? counter + 'd1 : counter;
			end
			CAL_his: begin
				counter <= (counter == 266)? 0 : counter + 'd1;
			end
			OUTPUT_A: begin
				awvalid_m_inf <= 1;
				awaddr_m_inf <= 'h40000 + (pic_no_reg << 12); // pic_no
			end
			OUTPUT_D: begin
				awvalid_m_inf <= (awready_m_inf)? 0 : awvalid_m_inf;
				wvalid_m_inf <= (wready_m_inf && counter <= 2)? 0 : (wlast_buffer)? 0 : 1;
				wlast_m_inf <= (counter == 257)? 1 : 0;
				counter <= (wlast_buffer)? 0 : (wready_m_inf)? counter + 'd1 : counter;
			end
		endcase
	end
end

// Erosion & Dilation
wire [7:0] SUM_result[0:15][0:3][0:3];
wire Carry_out[0:15][0:3][0:3];
wire [7:0] op_result[0:15][0:3][0:3];
reg [31:0] op_flatten[0:4][0:15];
wire [7:0] minmax_value[0:15][0:3];
reg [31:0] minmax_value_flatten[0:15];
wire [7:0] minmax_value_final[0:15];
wire [7:0] addsub_input[0:3][0:18];

generate
	for(i=0;i<4;i=i+1)
		for(j=0;j<19;j=j+1) 
			assign addsub_input[i][j] = (counter[1:0] < 3)? pic_reg[i][j] : (j < 16)? pic_reg[i][j] : 0; 
endgenerate

generate
	for(k=0;k<16;k=k+1) begin
		for(i=0;i<4;i=i+1) 
			for(j=0;j<4;j=j+1) begin
				DW01_addsub #(8) u_addsub ( .A(addsub_input[i][k+j]), .B(se_reg[i][j]), .CI(1'b0), 
											.ADD_SUB(!op_reg[0]), .SUM(SUM_result[k][i][j]), .CO(Carry_out[k][i][j]));
				assign op_result[k][i][j] = (!Carry_out[k][i][j])? SUM_result[k][i][j] : (op_reg[0])? 255 : 0;
			end
		always @(posedge clk) begin
			op_flatten[0][k] <= {op_result[k][0][0], op_result[k][0][1], op_result[k][0][2], op_result[k][0][3]};
			op_flatten[1][k] <= {op_result[k][1][0], op_result[k][1][1], op_result[k][1][2], op_result[k][1][3]};
			op_flatten[2][k] <= {op_result[k][2][0], op_result[k][2][1], op_result[k][2][2], op_result[k][2][3]};
			op_flatten[3][k] <= {op_result[k][3][0], op_result[k][3][1], op_result[k][3][2], op_result[k][3][3]};
		end
		// DW_minmax #(8, 16) u_minmax (.a(op_flatten[k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[k]));
		DW_minmax #(8, 4) u_minmax_1 (.a(op_flatten[0][k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[k][0]));
		DW_minmax #(8, 4) u_minmax_2 (.a(op_flatten[1][k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[k][1]));
		DW_minmax #(8, 4) u_minmax_3 (.a(op_flatten[2][k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[k][2]));
		DW_minmax #(8, 4) u_minmax_4 (.a(op_flatten[3][k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[k][3]));
		always @(posedge clk) 
			minmax_value_flatten[k] <= {minmax_value[k][0], minmax_value[k][1], minmax_value[k][2], minmax_value[k][3]};
		DW_minmax #(8, 4) u_minmax_5 (.a(minmax_value_flatten[k]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value_final[k]));
	end
endgenerate

// Hsitogram equalizaiton
reg [127:0] rdata_buffer;
wire [15:0] one_hot_encode[0:255];
reg [4:0] one_hot_pratial[0:3][0:255];
wire [4:0] one_hot_total[0:255];
reg [12:0] cdf_table[0:255];

always @(posedge clk)  begin
	rdata_buffer <= rdata_m_inf;
end

generate
	for(i=0;i<256;i=i+1) begin
		for(j=0;j<16;j=j+1)
			assign one_hot_encode[i][j] = (i >= rdata_buffer[j*8+7 -: 8])? 1'b1 : 1'b0;
		always @(posedge clk) begin
			one_hot_pratial[0][i] <= one_hot_encode[i][0]  + one_hot_encode[i][1]  + one_hot_encode[i][2]  + one_hot_encode[i][3];
			one_hot_pratial[1][i] <= one_hot_encode[i][4]  + one_hot_encode[i][5]  + one_hot_encode[i][6]  + one_hot_encode[i][7];
			one_hot_pratial[2][i] <= one_hot_encode[i][8]  + one_hot_encode[i][9]  + one_hot_encode[i][10] + one_hot_encode[i][11];
			one_hot_pratial[3][i] <= one_hot_encode[i][12] + one_hot_encode[i][13] + one_hot_encode[i][14] + one_hot_encode[i][15];
		end
		assign one_hot_total[i] = one_hot_pratial[0][i] + one_hot_pratial[1][i] + one_hot_pratial[2][i] + one_hot_pratial[3][i];
	end
endgenerate
	
reg [7:0] cdf_min_no;
reg [12:0] cdf_min;
wire [7:0] min_value[0:3],  min_value_final;
reg [31:0] min_value_flatten;

DW_minmax #(8, 4) u_minmax_hist_1 (.a(rdata_buffer[127:96]), .tc(1'b0), .min_max(1'b0), .value(min_value[0]));
DW_minmax #(8, 4) u_minmax_hist_2 (.a(rdata_buffer[95:64]), .tc(1'b0), .min_max(1'b0), .value(min_value[1]));
DW_minmax #(8, 4) u_minmax_hist_3 (.a(rdata_buffer[63:32]), .tc(1'b0), .min_max(1'b0), .value(min_value[2]));
DW_minmax #(8, 4) u_minmax_hist_4 (.a(rdata_buffer[31:0]), .tc(1'b0), .min_max(1'b0), .value(min_value[3]));
always @(posedge clk) min_value_flatten <= {min_value[0], min_value[1], min_value[2], min_value[3]};
DW_minmax #(8, 4) u_minmax_hist_5 (.a(min_value_flatten), .tc(1'b0), .min_max(1'b0), .value(min_value_final));

// div
reg [19:0] div_in1_temp;
reg [19:0] div_in1;
reg [11:0] div_in2;
reg [19:0] div_reg[0:7];
reg [7:0] div_result[0:7];

always @(posedge clk) begin
	div_in1_temp <= cdf_table[counter];
	div_in1 <= ((div_in1_temp - cdf_min) << 8) - (div_in1_temp - cdf_min);  // (cdf(v) - cdf_min) * 255
	div_in2 <= (4096 - cdf_min);
	div_reg[0] <= div_in1;
	div_result[0] <= (div_reg[0][19:7] >= div_in2);
end
generate
	for(i=1;i<=7;i=i+1)
		always @(posedge clk) begin
			div_reg[i] <= (div_reg[i-1][19:7] >= div_in2)? (div_reg[i-1] - (div_in2 << 7)) << 1 : div_reg[i-1] << 1;
			div_result[i] <= (div_result[i-1] << 1) + (div_reg[i][19:7] >= div_in2);
		end
endgenerate

// cdf table
always @(posedge clk) begin
	if(c_state == INPUT) cdf_min_no <= 255;
	else if(c_state == DRAM_his && rvalid_buffer2) 
		cdf_min_no <= (min_value_final < cdf_min_no)? min_value_final : cdf_min_no;
	cdf_min <= (c_state == CAL_cdfm)? cdf_table[cdf_min_no] : cdf_min;
end

generate
	for(i=0;i<256;i=i+1) 
		always @(posedge clk or negedge rst_n) begin
			if(!rst_n)
				cdf_table[i] <= 0;
			else if(c_state == INPUT) 
				cdf_table[i] <= 0;
			else if(c_state == DRAM_his && rvalid_buffer2)
				cdf_table[i] <= cdf_table[i] + one_hot_total[i];
			else if(c_state == CAL_his && counter >= 9 && i == (counter - 11)) 
				cdf_table[i] <= div_result[7];
		end
endgenerate

// SRAM & output
reg wen_SRAM;
reg [7:0] addr_SRAM;
wire [127:0] Q_SRAM; 
reg [127:0] D_SRAM;

RA1SH_128 u_SRAM (.Q(Q_SRAM), .CLK(clk), .CEN(1'b0), .WEN(wen_SRAM), .A(addr_SRAM), .D(D_SRAM), .OEN(1'b0));

reg [127:0] Q_SRAM_buffer;
always @(posedge clk) begin
	Q_SRAM_buffer <= Q_SRAM;
end

wire [7:0] new_data[0:15];
generate
	for(i=0;i<16;i=i+1)
		assign new_data[i] = cdf_table[Q_SRAM_buffer[127 - i*8 -: 8]];
endgenerate

always @(posedge clk) begin
	case (c_state)
		DRAM_pic: begin
			wen_SRAM <= 0;
			addr_SRAM <= counter - 'd18;
			D_SRAM <= {minmax_value_final[15], minmax_value_final[14], minmax_value_final[13], minmax_value_final[12],
						minmax_value_final[11], minmax_value_final[10], minmax_value_final[9],  minmax_value_final[8],
						minmax_value_final[7],  minmax_value_final[6],  minmax_value_final[5],  minmax_value_final[4],
						minmax_value_final[3],  minmax_value_final[2],  minmax_value_final[1],  minmax_value_final[0]};
		end
		DRAM_his: begin
			wen_SRAM <= (rlast_buffer2)? 1 : 0;
			addr_SRAM <= counter;
			D_SRAM <= rdata_buffer;
		end
		OUTPUT_D: begin
			wen_SRAM <= 1;
			addr_SRAM <= (wready_m_inf)? counter + 'd1 : counter;
			if(op_reg < 2)
				wdata_m_inf <= Q_SRAM_buffer;
			else
				wdata_m_inf <= {new_data[0], new_data[1], new_data[2], new_data[3], 
							   new_data[4], new_data[5], new_data[6], new_data[7], 
							   new_data[8], new_data[9], new_data[10], new_data[11], 
							   new_data[12], new_data[13], new_data[14], new_data[15]};
		end
		default: begin
			wen_SRAM <= 1;
			addr_SRAM <= 0;
		end
	endcase
end


// FSM
always @(*) begin
	case (c_state)
		INPUT:     n_state = (!in_valid)? INPUT : (op == 2)? INPUT_his : INPUT_se;
		INPUT_se:  n_state = DRAM_se;
		DRAM_se:   n_state = (rlast_m_inf)? INPUT_pic : DRAM_se;
		INPUT_pic: n_state = DRAM_pic;
		DRAM_pic:  n_state = (counter == 273)? OUTPUT_A : DRAM_pic;
		INPUT_his: n_state = DRAM_his;
		DRAM_his:  n_state = (rlast_buffer2)? CAL_cdfm : DRAM_his;
		CAL_cdfm:  n_state = CAL_his;
		CAL_his:   n_state = (counter == 266)? OUTPUT_A : CAL_his;
		OUTPUT_A:  n_state = OUTPUT_D;
		OUTPUT_D:  n_state = (wlast_buffer)? INPUT : OUTPUT_D;
		default:   n_state = INPUT;
	endcase	
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= INPUT;
	else c_state <= n_state;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) busy <= 0;
	else busy <= (c_state == INPUT)? 0 : 1;
end

// input
always @(posedge clk) begin
	se_no_reg <= (c_state == INPUT)? se_no : se_no_reg;
	pic_no_reg <= (c_state == INPUT)? pic_no : pic_no_reg;
	op_reg <= (c_state == INPUT)? op : op_reg;
end

// se_reg
generate
	for(i=0;i<4;i=i+1)
		for(j=0;j<4;j=j+1)
			always @(posedge clk) if(c_state == DRAM_se)
				se_reg[i][j] <= (op_reg[0])? rdata_m_inf[127 - i*32 - j*8 -: 8] : rdata_m_inf[i*32 + j*8 +: 8];
endgenerate

// pic_reg
generate
	for(i=0;i<4;i=i+1)
		for(j=0;j<48;j=j+1)  // shift to left
			always @(posedge clk) if(c_state == DRAM_pic) pic_reg[i][j] <= pic_reg[i][j+16];
	for(i=0;i<3;i=i+1)
		for(j=0;j<16;j=j+1)  // shift the leftest to rightest and shift up
			always @(posedge clk) if(c_state == DRAM_pic) pic_reg[i][48+j] <= pic_reg[i+1][j];
	for(j=0;j<16;j=j+1)  // new data input
		always @(posedge clk) if(c_state == DRAM_pic) pic_reg[3][48+j] <= (counter <= 'd255)? rdata_m_inf[j*8+7 -: 8] : 0;
endgenerate

endmodule