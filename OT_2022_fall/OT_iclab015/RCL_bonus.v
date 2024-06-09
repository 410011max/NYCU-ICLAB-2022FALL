module RCL(
    input clk,
    input rst_n,
    input in_valid,
    input [4:0] coef_Q,
    input [4:0] coef_L,
    output reg out_valid,
    output reg [1:0] out
);

reg end_sig;
reg [3:0] counter;
reg signed [4:0] a,b,c,m,n;
reg [4:0] k;
wire signed [5:0] k_signed = {1'b0, k};
wire signed [30:0] result_1, result_2;
wire [1:0] out_reg;


// calculate
assign result_1 = k_signed * (a*a + b*b);
assign result_2 = (a*m + b*n + c) * (a*m + b*n + c);
assign out_reg = (result_1 > result_2)? 'd2 : (result_1 == result_2)? 'd1 : 'd0;


// input
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		a <= 0; b <= 0; c <= 0;
		m <= 0; n <= 0; k <= 0;
		end_sig <= 1;
	end
	else begin
		a <= (counter == 'd0)? coef_L : a;
		b <= (counter == 'd1)? coef_L : b;
		c <= (counter == 'd2)? coef_L : c;
		m <= (counter == 'd0)? coef_Q : m;
		n <= (counter == 'd1)? coef_Q : n;
		k <= (counter == 'd2)? coef_Q : k;
		end_sig <= (in_valid)? 0 : 1;
	end
end

// counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) counter <= 'd0;
	else counter <= (counter == 'd2)? 'd0 : (in_valid)? counter + 'd1 : 'd0;
end

// output
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 0;
		out <= 0;
	end
	else begin
		if(end_sig) begin
			out_valid <= 0;
			out <= 0;		
		end
		else begin
			out_valid <= (counter == 'd0)? 1 : 0;
			out <= (counter == 'd0)? out_reg : 0;
		end
	end
end

endmodule
