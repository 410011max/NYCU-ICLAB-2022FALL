module RCL(
    input clk,
    input rst_n,
    input in_valid,
    input [4:0] coef_Q,
    input [4:0] coef_L,
    output reg out_valid,
    output reg [1:0] out
);

parameter INPUT   = 'd0,
		  INPUT_2 = 'd1,
	  	  CAL     = 'd2,
	  	  OUTPUT  = 'd3;

reg [3:0] c_state, n_state;
reg [3:0] counter;
reg signed [4:0] a,b,c,m,n;
reg [4:0] k;
wire signed [30:0] result_1, result_2;
reg [1:0] out_reg;
wire signed [5:0] k_signed = {1'b0, k};

// calculate
assign result_1 = k_signed * (a*a + b*b);
assign result_2 = (a*m + b*n + c) * (a*m + b*n + c);

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) out_reg <= 0;
	else out_reg <= (result_1 > result_2)? 'd2 : (result_1 == result_2)? 'd1 : 'd0;
end

// input
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		a <= 0; b <= 0; c <= 0;
		m <= 0; n <= 0; k <= 0;
	end
	else begin
		case(c_state)
			INPUT: begin
				a <= (counter == 'd0)? coef_L : a;
				b <= (counter == 'd1)? coef_L : b;
				c <= (counter == 'd2)? coef_L : c;
				m <= (counter == 'd0)? coef_Q : m;
				n <= (counter == 'd1)? coef_Q : n;
				k <= (counter == 'd2)? coef_Q : k;
			end
			OUTPUT: begin
				a <= 0; b <= 0; c <= 0;
				m <= 0; n <= 0; k <= 0;
			end
		endcase
	end
end

// counter
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		counter <= 'd0;
	end
	else begin
		case(c_state)
			INPUT:   counter <= (counter == 'd2)? 'd0 : (in_valid)? counter + 'd1 : 'd0;
			CAL:     counter <= (counter == 'd0)? 'd0 : counter + 'd1;
			OUTPUT:  counter <= 'd0;
		endcase
	end
end

// next state logic
always@(*) begin
	case(c_state)
		INPUT:   n_state = (counter == 'd2)? CAL : INPUT;
		CAL:     n_state = (counter == 'd0)? OUTPUT : CAL;
 		OUTPUT:  n_state = INPUT;
		default: n_state = INPUT;
	endcase
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= INPUT;
	else c_state <= n_state;
end

// output
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		out_valid <= 0;
		out <= 0;
	end
	else begin
		out_valid <= (c_state == OUTPUT)? 1 : 0;
		out <= (c_state == OUTPUT)? out_reg : 0;
	end
end

endmodule
