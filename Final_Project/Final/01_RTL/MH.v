//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_minmax.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW01_addsub.v"
//synopsys translate_on

module MH(
        input           	clk,
		input           	clk2,
		input           	rst_n,
		input           	in_valid,
		input           	op_valid,
		input 		[31:0] 	pic_data,
		input 		[7:0]  	se_data,
		input 		[2:0]  	op,
		output reg	 		out_valid,
		output reg	[31:0]	out_data
);

//---------------------------------------------------------------------
//   Parameter
//---------------------------------------------------------------------
genvar i, j, k;
integer l;
localparam 	INPUT      = 0,
		   	OUTPUT_ED  = 1,
			OUTPUT_OC  = 2,
			OUTPUT_HIS = 3;

localparam 	Erosion   = 3'b010,
			Dilation  = 3'b011,
			Histogram = 3'b000,
			Opening   = 3'b110,
			Closing   = 3'b111;

//---------------------------------------------------------------------
//   Wire & Reg Declaration
//---------------------------------------------------------------------
reg [1:0] c_state, n_state;
reg [8:0] counter;
reg [2:0] op_reg;
reg [7:0] se_reg[0:15];
wire [7:0] se_reg_wire[0:3][0:3];
reg [7:0] pic_reg[0:3][0:31];

// SRAM
reg wen_SRAM;
reg [7:0] addr_SRAM;
wire [31:0] Q_SRAM; 
reg [31:0] D_SRAM;

//---------------------------------------------------------------------
//   Design
//---------------------------------------------------------------------
// Erosion & Dilation
reg [7:0] addsub_input[0:3][0:6];
wire [7:0] SUM_result[0:3][0:3][0:3];
wire Carry_out[0:3][0:3][0:3];
wire [7:0] op_result[0:3][0:3][0:3];
reg [127:0] op_flatten[0:3];
wire [7:0] minmax_value[0:3];

generate
	for(i=0;i<4;i=i+1) begin
		for(j=0;j<7;j=j+1) 
			always @(*) begin
				if(j < 4 || (c_state == INPUT && counter[2:0] < 7) || (c_state != INPUT && counter[2:0] > 0))
					addsub_input[i][j] = pic_reg[i][j];
				else 
					addsub_input[i][j] = 0; 
			end 
		for(j=0;j<4;j=j+1) 
			for(k=0;k<4;k=k+1) begin
				DW01_addsub #(8) u_addsub ( .A(addsub_input[j][i+k]), .B(se_reg_wire[j][k]), .CI(1'b0), 
											.ADD_SUB(!op_reg[0]), .SUM(SUM_result[i][j][k]), .CO(Carry_out[i][j][k]));
				assign op_result[i][j][k] = (!Carry_out[i][j][k])? SUM_result[i][j][k] : (op_reg[0])? 255 : 0;
			end
		always @(posedge clk)
			op_flatten[i] = {op_result[i][0][0], op_result[i][0][1], op_result[i][0][2], op_result[i][0][3],
							op_result[i][1][0], op_result[i][1][1], op_result[i][1][2], op_result[i][1][3],
							op_result[i][2][0], op_result[i][2][1], op_result[i][2][2], op_result[i][2][3],
							op_result[i][3][0], op_result[i][3][1], op_result[i][3][2], op_result[i][3][3]};
		DW_minmax #(8, 16) u_minmax (.a(op_flatten[i]), .tc(1'b0), .min_max(op_reg[0]), .value(minmax_value[i]));
	end
endgenerate

// Histogram equalizaiton
reg [31:0] pic_reg_buffer;
wire [3:0] one_hot_encode[0:255];
wire [2:0] one_hot_total[0:255];
reg [9:0] cdf_table[0:255];

always @(posedge clk) pic_reg_buffer <= {pic_reg[0][3], pic_reg[0][2], pic_reg[0][1], pic_reg[0][0]};

generate
	for(i=0;i<256;i=i+1) begin
		for(j=0;j<4;j=j+1) assign one_hot_encode[i][j] = (i >= pic_reg_buffer[j*8+7 -: 8])? 1 : 0;
		assign one_hot_total[i] = one_hot_encode[i][0] + one_hot_encode[i][1]  + one_hot_encode[i][2]  + one_hot_encode[i][3];
		always @(posedge clk or negedge rst_n) begin
			if(!rst_n) cdf_table[i] <= 0;
			else if(c_state == INPUT && counter > 31 + 1) 
				cdf_table[i] <= cdf_table[i] + one_hot_total[i];
			else if(c_state == INPUT) 
				cdf_table[i] <= 0;
		end
	end
endgenerate

// cdf table
wire [7:0] min_value;
reg [7:0] cdf_min_no;
reg [9:0] cdf_min;

DW_minmax #(8, 4) u_minmax_hist (.a(pic_reg_buffer), .tc(1'b0), .min_max(1'b0), .value(min_value));

always @(posedge clk) begin
	if(c_state == INPUT && counter <= 31 + 1)
		cdf_min_no <= 255; 
	else if(c_state == INPUT) 
		cdf_min_no <= (min_value < cdf_min_no)? min_value : cdf_min_no;

	cdf_min <= (c_state == OUTPUT_HIS && counter == 0)? cdf_table[cdf_min_no] : cdf_min;
end

// div
reg [9:0] divisor;
reg [9:0] div_reg_buffer[0:3];
reg [17:0] div_reg[0:3][0:7];
reg [7:0] div_result[0:3][0:7];

always @(posedge clk) divisor <= (1024 - cdf_min);

generate
	for(i=0;i<4;i=i+1) begin
		always @(posedge clk) begin
			div_reg_buffer[i] <= cdf_table[Q_SRAM[i*8+7 -: 8]];
			div_reg[i][0] <= ((div_reg_buffer[i] - cdf_min) << 8) - (div_reg_buffer[i] - cdf_min);  // (cdf(v) - cdf_min) * 255
			div_result[i][0] <= (div_reg[i][0][17:7] >= divisor);		
		end
		for(j=1;j<=7;j=j+1)
			always @(posedge clk) begin
				div_reg[i][j] <= (div_reg[i][j-1][17:7] >= divisor)? (div_reg[i][j-1] - (divisor << 7)) << 1 : div_reg[i][j-1] << 1;
				div_result[i][j] <= (div_result[i][j-1] << 1) + (div_reg[i][j][17:7] >= divisor);
			end
	end
endgenerate

// SRAM
RA1SH u_SRAM (.Q(Q_SRAM), .CLK(clk), .CEN(1'b0), .WEN(wen_SRAM), .A(addr_SRAM), .D(D_SRAM), .OEN(1'b0));
always @(*) begin
	wen_SRAM = (c_state != INPUT);
	addr_SRAM = (c_state == INPUT)? (counter - 32 - 1) : counter;
	D_SRAM = (op_reg == Histogram)? pic_reg_buffer : {minmax_value[3],  minmax_value[2],  minmax_value[1],  minmax_value[0]};
end

// input
always @(posedge clk) begin
	if(c_state == INPUT) op_reg <= (op_valid)? op : op_reg;
	else if(c_state == OUTPUT_OC && counter == 0) op_reg[0] <= ~op_reg[0];
end

// se_reg
always @(posedge clk) begin
	if(in_valid && counter < 16) begin
		for(l=0;l<15;l=l+1) se_reg[l] <= se_reg[l+1];
		se_reg[15] <= se_data;
	end
end
generate
	for(i=0;i<4;i=i+1)
		for(j=0;j<4;j=j+1)
			assign se_reg_wire[i][j] = (!op_reg[0])? se_reg[i*4 + j] : se_reg[15 - i*4 - j];
endgenerate

// pic_reg
generate
	for(i=0;i<4;i=i+1)
		for(j=0;j<28;j=j+1)  // shift to left
			always @(posedge clk) pic_reg[i][j] <= pic_reg[i][j+4];

	for(i=0;i<3;i=i+1)
		for(j=0;j<4;j=j+1)  // shift the leftest to rightest and shift up
			always @(posedge clk) pic_reg[i][28+j] <= pic_reg[i+1][j];

	for(i=0;i<4;i=i+1)  // new data input
		always @(posedge clk) 
			pic_reg[3][28+i] <= (c_state == OUTPUT_OC && counter <= 256)? Q_SRAM[i*8+7 -: 8] : (in_valid)? pic_data[i*8+7 -: 8] : 0;
endgenerate

// Output
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 0;
		out_data <= 0;
	end
	else begin
		case (c_state)
			OUTPUT_ED: begin
				out_valid <= (counter > 0);
				out_data <= (counter > 0)? Q_SRAM : 0;
			end
			OUTPUT_OC: begin
				out_valid <= (counter > 31 + 1 + 1);
				out_data <= (counter > 31 + 1 + 1)? {minmax_value[3],  minmax_value[2],  minmax_value[1],  minmax_value[0]} : 0;
			end
			OUTPUT_HIS: begin
				out_valid <= (counter >= 10 + 1);
				out_data <= (counter >= 10 + 1)? {div_result[3][7], div_result[2][7], div_result[1][7], div_result[0][7]} : 0;
			end 
			default: begin
				out_valid <= 0;
				out_data <= 0;
			end 
		endcase
	end
end

// counter
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) counter <= 0;
	else begin
		case (c_state)
			INPUT:      counter <= (in_valid)? counter + 1 : (counter == 255 + 32 + 1)? 0 : (counter > 255)? counter + 1 : 0;
			OUTPUT_ED:  counter <= (counter == 255 + 1)? 0 : counter + 1;
			OUTPUT_OC:  counter <= (counter == 255 + 32 + 1 + 1)? 0 : counter + 1;
			OUTPUT_HIS: counter <= (counter == 255 + 10 + 1)? 0 : counter + 1;
		endcase
	end
end

// FSM
always @(*) begin
	case (c_state)
		INPUT:      n_state = (counter < 255 + 32 + 1)? INPUT : (op_reg == Histogram)? OUTPUT_HIS : 
					  									  		(op_reg == Opening || op_reg == Closing)? OUTPUT_OC : OUTPUT_ED;
		OUTPUT_ED:  n_state = (counter == 255 + 1)?  INPUT : OUTPUT_ED;
		OUTPUT_OC:  n_state = (counter == 255 + 32 + 1 + 1)? INPUT : OUTPUT_OC;
		OUTPUT_HIS: n_state = (counter == 255 + 10 + 1)?  INPUT : OUTPUT_HIS;
		default:    n_state = INPUT;
	endcase	
end

always @(posedge clk or negedge rst_n) begin
	c_state <= (!rst_n)? INPUT : n_state;
end

endmodule