module NN(
           // Input signals
           input clk,
           input rst_n,
           input in_valid_u,
           input in_valid_w,
           input in_valid_v,
           input in_valid_x,
           input [31:0] weight_u,
           input [31:0] weight_w,
           input [31:0] weight_v,
           input [31:0] data_x,
           // Output signals
           output reg out_valid,
           output reg [31:0] out
       );

//---------------------------------------------------------------------
//   Parameter
//---------------------------------------------------------------------
parameter INPUT = 3'd0,
          CAL_1 = 3'd1,
          CAL_2 = 3'd2,
          CAL_3 = 3'd3,
          OUTPUT = 3'd4;

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 2;
parameter inst_arch_type = 1;
parameter inst_faithful_round = 0;

//---------------------------------------------------------------------
//   Wire & Reg Declaration
//---------------------------------------------------------------------
reg [2:0] c_state, n_state;
reg [3:0] counter;
reg [1:0] counter2;
reg [31:0] reg_x[0:8], reg_u[0:8], reg_w[0:8], reg_v[0:8];
reg [31:0] reg_h[0:8], reg_ux[0:2];

//---------------------------------------------------------------------
//   DesignWare reg & wire
//---------------------------------------------------------------------
reg  [31:0] dp3_a, dp3_b, dp3_c, dp3_d, dp3_e, dp3_f;
wire [31:0] dp3_out;

reg  [31:0] add_a, add_b, add_exp_a;
wire [31:0] add_out, add_exp_out;

reg  [31:0] exp_in;
wire [31:0] exp_out;

wire [31:0] recip_in;
wire [31:0] recip_out;

wire [31:0] mult_out[0:2];

//---------------------------------------------------------------------
//   DesignWare
//---------------------------------------------------------------------
// DW_fp_dp3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type)
//           D1 (.a(dp3_a), .b(dp3_b), .c(dp3_c), .d(dp3_d), .e(dp3_e), .f(dp3_f), .rnd(3'b000), .z(dp3_out));

DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
           M1 (.a(dp3_a), .b(dp3_b), .rnd(3'b000), .z(mult_out[0]));
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
           M2 (.a(dp3_c), .b(dp3_d), .rnd(3'b000), .z(mult_out[1]));
DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
           M3 (.a(dp3_e), .b(dp3_f), .rnd(3'b000), .z(mult_out[2]));
DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) 
           S1 (.a(mult_out[0]), .b(mult_out[1]), .c(mult_out[2]), .rnd(3'b000), .z(dp3_out));


DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
          A1 (.a(add_a), .b(add_b), .rnd(3'b000), .z(add_out));

DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch) 
          E1 (.a(exp_in), .z(exp_out));
DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
          A2 (.a(add_exp_a), .b({1'b0, 8'b01111111, 23'b0}), .rnd(3'b000), .z(add_exp_out));
DW_fp_recip #(inst_sig_width, inst_exp_width, inst_ieee_compliance,inst_faithful_round)
            R1 (.a(recip_in), .rnd(3'b000), .z(recip_out));

// Sigmoid
always @(posedge clk) begin
    exp_in <= {~add_out[31], add_out[30:0]};
    add_exp_a <= exp_out;
end
assign recip_in = add_exp_out;

//---------------------------------------------------------------------
//   Calculation
//---------------------------------------------------------------------

// Input
always @(posedge clk) begin
    if(c_state == INPUT) begin 
        // x10->x11->x12->x20->x21->x22->x30->x31->x32
        // u00->u01->u02->u10->u11->u12->u20->u21->u22
        reg_x[counter] <= data_x;
        reg_u[counter] <= weight_u;
        reg_v[counter] <= weight_v;
        reg_w[counter] <= weight_w;
    end
	else if(c_state == CAL_1) begin // calcute start from input 7
        reg_u[0] <= reg_u[3]; reg_u[3] <= reg_u[6]; reg_u[6] <= reg_u[0];
		reg_u[1] <= reg_u[4]; reg_u[4] <= reg_u[7]; reg_u[7] <= reg_u[1];
		reg_u[2] <= reg_u[5]; reg_u[5] <= reg_u[8]; reg_u[8] <= reg_u[2];
        if(counter == 'd0) begin
            reg_x[7] <= data_x;
            reg_u[4] <= weight_u;
            reg_v[7] <= weight_v;
            reg_w[7] <= weight_w;
        end
        else if(counter == 'd1) begin
            reg_x[8] <= data_x;
            reg_u[2] <= weight_u;
            reg_v[8] <= weight_v;
            reg_w[8] <= weight_w;
        end
    end 
    else begin
		reg_u[0] <= reg_u[3]; reg_u[3] <= reg_u[6]; reg_u[6] <= reg_u[0];
		reg_u[1] <= reg_u[4]; reg_u[4] <= reg_u[7]; reg_u[7] <= reg_u[1];
		reg_u[2] <= reg_u[5]; reg_u[5] <= reg_u[8]; reg_u[8] <= reg_u[2];

		reg_w[0] <= reg_w[3]; reg_w[3] <= reg_w[6]; reg_w[6] <= reg_w[0];
		reg_w[1] <= reg_w[4]; reg_w[4] <= reg_w[7]; reg_w[7] <= reg_w[1];
		reg_w[2] <= reg_w[5]; reg_w[5] <= reg_w[8]; reg_w[8] <= reg_w[2];
		
		reg_v[0] <= reg_v[3]; reg_v[3] <= reg_v[6]; reg_v[6] <= reg_v[0];
		reg_v[1] <= reg_v[4]; reg_v[4] <= reg_v[7]; reg_v[7] <= reg_v[1];
		reg_v[2] <= reg_v[5]; reg_v[5] <= reg_v[8]; reg_v[8] <= reg_v[2];
	end
end

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 'd0;
		counter2 <= 'd0;
    end
    else begin
        case (c_state)
            INPUT:  counter <= (in_valid_x && counter != 'd6) ? counter + 'd1 : 'd0; 
            CAL_1:  counter <= (counter == 'd2) ? 'd0 : counter + 'd1;
            CAL_2:  counter <= (counter == 'd5) ? 'd0 : counter + 'd1;
            CAL_3:  counter <= (counter == 'd5) ? 'd0 : counter + 'd1;
            OUTPUT: counter <= (counter == 'd8) ? 'd0 : counter + 'd1;
        endcase
		if(c_state == OUTPUT)
			counter2 <= (counter2 == 'd2) ? 'd0 : counter2 + 'd1;
    end
end

// calculate for dp3
always @(*) begin
    dp3_a = 'dx; dp3_b = 'dx;
    dp3_c = 'dx; dp3_d = 'dx;
    dp3_e = 'dx; dp3_f = 'dx;

    case (c_state)
        CAL_1: begin
            dp3_a = reg_u[0]; dp3_b = reg_x[0];
			dp3_c = reg_u[1]; dp3_d = reg_x[1];
			dp3_e = reg_u[2]; dp3_f = reg_x[2];
        end
        CAL_2: begin
			if(counter <= 'd2) begin
				dp3_a = reg_u[0]; dp3_b = reg_x[3];
				dp3_c = reg_u[1]; dp3_d = reg_x[4];
				dp3_e = reg_u[2]; dp3_f = reg_x[5];
			end
			else begin
				dp3_a = reg_w[0]; dp3_b = reg_h[0];
				dp3_c = reg_w[1]; dp3_d = reg_h[1];
				dp3_e = reg_w[2]; dp3_f = reg_h[2];
			end
        end
        CAL_3: begin
			if(counter <= 'd2) begin
				dp3_a = reg_u[0]; dp3_b = reg_x[6];
				dp3_c = reg_u[1]; dp3_d = reg_x[7];
				dp3_e = reg_u[2]; dp3_f = reg_x[8];
			end
			else begin
				dp3_a = reg_w[0]; dp3_b = reg_h[3];
				dp3_c = reg_w[1]; dp3_d = reg_h[4];
				dp3_e = reg_w[2]; dp3_f = reg_h[5];
			end
        end
        OUTPUT: begin
			dp3_a = reg_v[0]; dp3_b = reg_h[0];
			dp3_c = reg_v[1]; dp3_d = reg_h[1];
			dp3_e = reg_v[2]; dp3_f = reg_h[2];
        end
    endcase
end

// calculate for add
always @(posedge clk) begin
    add_a <= 'dx;
    add_b <= 'dx;
    
    if(c_state == CAL_1) begin
        add_a <= dp3_out;
        add_b <= 'd0; 
    end
    else if(c_state == CAL_2 || c_state == CAL_3) begin
        case (counter)
            0: reg_ux[0] <= dp3_out;
            1: reg_ux[1] <= dp3_out;
            2: reg_ux[2] <= dp3_out;
            3: begin
                add_a <= reg_ux[0];
                add_b <= dp3_out;     
            end 
            4: begin
                add_a <= reg_ux[1];
                add_b <= dp3_out;     
            end 
            5: begin
                add_a <= reg_ux[2];
                add_b <= dp3_out;     
            end
        endcase
    end
end

// save calculate result for h
always @(posedge clk) begin
    case (c_state)
        CAL_2: begin
            if(counter == 'd0)
                reg_h[0] <= recip_out;
            else if(counter == 'd1)
                reg_h[1] <= recip_out;
            else if(counter == 'd2)
                reg_h[2] <= recip_out;
        end
        CAL_3: begin
            if(counter == 'd0)
                reg_h[3] <= recip_out;
            else if(counter == 'd1)
                reg_h[4] <= recip_out;
            else if(counter == 'd2)
                reg_h[5] <= recip_out;
        end
        OUTPUT: begin
			if(counter2 == 'd2) begin
				reg_h[0] <= reg_h[3]; reg_h[3] <= reg_h[6]; reg_h[6] <= reg_h[0];
				reg_h[1] <= reg_h[4]; reg_h[4] <= reg_h[7]; reg_h[7] <= reg_h[1];
				reg_h[2] <= reg_h[5]; reg_h[5] <= reg_h[8]; reg_h[8] <= reg_h[2];
			end	
            if(counter == 'd0)
                reg_h[6] <= recip_out;
            else if(counter == 'd1)
                reg_h[7] <= recip_out;
            else if(counter == 'd2)
                reg_h[5] <= recip_out; // change to fix shift register
        end
    endcase
end

// Next state logic
always @(*) begin
    case (c_state)
        INPUT:   n_state = (counter == 'd6) ? CAL_1 : INPUT;
        CAL_1:   n_state = (counter == 'd2) ? CAL_2 : CAL_1;
        CAL_2:   n_state = (counter == 'd5) ? CAL_3 : CAL_2;
        CAL_3:   n_state = (counter == 'd5) ? OUTPUT : CAL_3;
        OUTPUT:  n_state = (counter == 'd8) ? INPUT : OUTPUT;
        default: n_state = INPUT;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= INPUT;
    else
        c_state <= n_state;
end

//---------------------------------------------------------------------
//   Output
//---------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 'd0;
        out <= 'd0;
    end
    else begin
        if(c_state == OUTPUT) begin
            out_valid <= 1'd1;
            out <= (dp3_out[31] == 'd0) ? dp3_out : 'd0;
        end
        else begin
            out_valid <= 'd0;
            out <= 'd0;
        end
    end
end

endmodule