//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW02_mult.v" 
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW02_mult_2_stage.v"
//synopsys translate_on

module MMSA(
           // input signals
           input clk,
           input rst_n,
           input in_valid,
           input in_valid2,
           input [15:0] matrix,
           input [1:0] matrix_size,
           input [3:0] i_mat_idx,
           input [3:0] w_mat_idx,

           // output signals
           output reg out_valid,
           output reg signed [39:0] out_value
       );
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
genvar i, j;
integer k;
parameter INPUT_X = 'd0,
          INPUT_W = 'd1,
          CHOOSE  = 'd2,
          CAL     = 'd3,
          CAL_2   = 'd4,
          OUTPUT  = 'd5;

//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [2:0] n_state, c_state;
reg [3:0] id_x, id_w, id_out;
reg [2:0] size;
reg [4:0] real_size;
reg [7:0] real_size_2;
reg [8:0] counter;
reg [4:0] ans_counter;
reg signed [39:0] ans[0:30];

// SRAM
reg wen_input;
reg [15:0] wen_weight;
reg [7:0] addr_weight;
reg [11:0] addr_input;
wire signed [15:0] input_SRAM, weight_SRAM[0:15];

// mult
reg signed [15:0] mult_A[0:15], mult_B[0:15];
reg signed [31:0] mult_reg[0:15];
wire signed [31:0] mult_out[0:15];

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
// SRAM
RA1SH_L R_input (.Q(input_SRAM), .CLK(clk), .CEN(1'b0), .WEN(wen_input), .A(addr_input), .D(matrix), .OEN(1'b0));
generate
    for(i=0;i<16;i=i+1)
        RA1SH R_weight (.Q(weight_SRAM[i]), .CLK(clk), .CEN(1'b0), .WEN(wen_weight[i]), .A(addr_weight), .D(matrix), .OEN(1'b0));
endgenerate

// mult
generate
    for(i=0;i<16;i=i+1) begin
        // DW02_mult #(16, 16) M1(.A(mult_A[i]), .B(mult_B[i]), .TC(1'b1), .PRODUCT(mult_out[i]));
        DW02_mult_2_stage #(16, 16) M1(.A(mult_A[i]), .B(mult_B[i]), .TC(1'b1), .CLK(clk), .PRODUCT(mult_out[i]));
        
        always @(posedge clk) begin
            mult_A[i] <= input_SRAM;
            mult_B[i] <= weight_SRAM[i];
            mult_reg[i] <= (i <= real_size)? mult_out[i] : 'd0;
        end
    end
endgenerate

// weight SRAM
always @(*) begin
    addr_weight = 'dx;
    wen_weight = 16'b1111111111111111;

    if(c_state == INPUT_W) begin
        case (size)
            0: wen_weight[counter[0]]   = 1'd0;  // 2*2
            1: wen_weight[counter[1:0]] = 1'd0;  // 4*4
            2: wen_weight[counter[2:0]] = 1'd0;  // 8*8
            3: wen_weight[counter[3:0]] = 1'd0;  // 16*16
        endcase
        case (size)
            0: addr_weight = (counter >>> 1) + id_w * 16;  // 2*2
            1: addr_weight = (counter >>> 2) + id_w * 16;  // 4*4
            2: addr_weight = (counter >>> 3) + id_w * 16;  // 8*8
            3: addr_weight = (counter >>> 4) + id_w * 16;  // 16*16
        endcase
    end
    else begin
        case (size)
            0: addr_weight = counter[0]   + id_w * 16;  // 2*2
            1: addr_weight = counter[1:0] + id_w * 16;  // 4*4
            2: addr_weight = counter[2:0] + id_w * 16;  // 8*8
            3: addr_weight = counter[3:0] + id_w * 16;  // 16*16
        endcase
    end
end

// input SRAM
always @(*) begin
    wen_input = (c_state == INPUT_X)? 1'd0 : 1'd1;
    addr_input = (c_state == INPUT_X || c_state == CAL || c_state == CAL_2)? counter + id_x * 256 : 'dx;
end

// id
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        id_x <= 'd0;
        id_w <= 'd0;
        id_out <= 'd0;
    end
    else begin
        case (c_state)
            INPUT_X: begin
                id_out <= 'd0;
                id_x <= (in_valid && counter == real_size_2)? id_x + 'd1 : id_x;
            end
            INPUT_W: begin
                id_w <= (counter == real_size_2)? id_w + 'd1 : id_w;
            end
            CHOOSE: begin
                id_out <= (in_valid2)? id_out + 'd1 : id_out;
                id_x <= i_mat_idx;
                id_w <= w_mat_idx;
            end
            OUTPUT: begin
                if(counter == real_size*2 && id_out == 0) begin
                    id_x <= 'd0;
                    id_w <= 'd0;    
                end 
            end
        endcase
    end
end

// size
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        size <= 'd0;
    else 
        size <= (c_state == INPUT_X && in_valid && counter == 'd0 && id_x == 'd0)? matrix_size : size;
end
always @(posedge clk) begin
    case (size)
        0: real_size <= 'd1;  // 2*2
        1: real_size <= 'd3;  // 4*4
        2: real_size <= 'd7;  // 8*8
        3: real_size <= 'd15; // 16*16
    endcase
    case (size)
        0: real_size_2 <= 'd3;   // 2*2
        1: real_size_2 <= 'd15;  // 4*4
        2: real_size_2 <= 'd63;  // 8*8
        3: real_size_2 <= 'd255; // 16*16
    endcase
end

// counter
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 'd0;
    end
    else begin
        case (c_state)
            INPUT_X: counter <= (!in_valid || counter == real_size_2)? 'd0 : counter + 'd1;
            INPUT_W: counter <= (counter == real_size_2)? 'd0 : counter + 'd1;
            CAL:     counter <= counter + 'd1;
            CAL_2:   counter <= (counter == real_size_2 + 4)? 'd0 : counter + 'd1;
            OUTPUT:  counter <= (counter == real_size << 1)? 'd0 : counter + 'd1;
            default: counter <= 'd0;
        endcase
    end
end
always @(posedge clk) begin
    ans_counter <= (c_state != CAL_2) ? 'd0 : (ans_counter == real_size) ? 'd0 : ans_counter + 'd1;
end

// ans calculation
always @(posedge clk) begin
    if(c_state == CHOOSE) begin
        for(k=0;k<31;k=k+1)
            ans[k] <= 'd0;
    end
    if(c_state == CAL_2)begin
        if(ans_counter == real_size) begin
            for(k=0;k<30;k=k+1)
                ans[k] <= ans[k+1];
            ans[30] <= ans[0];
            
            for(k=0;k<16;k=k+1)
                ans[k] <= ans[k+1] + mult_reg[k];
        end
        else begin
            for(k=0;k<16;k=k+1)
                ans[k+1] <= ans[k+1] + mult_reg[k];
        end
    end
    if(c_state == OUTPUT) begin
        for(k=0;k<30;k=k+1)
            ans[k] <= ans[k+1];
        ans[30] <= ans[0];
    end
end

// next state logic
always @(*) begin
    case (c_state)
        INPUT_X: n_state = (counter == real_size_2 && id_x == 'd15)? INPUT_W : INPUT_X;
        INPUT_W: n_state = (counter == real_size_2 && id_w == 'd15)? CHOOSE : INPUT_W;
        CHOOSE:  n_state = (in_valid2)? CAL : CHOOSE;
        CAL:     n_state = (counter == 'd3)? CAL_2 : CAL;
        CAL_2:   n_state = (counter == real_size_2 + 4)? OUTPUT : CAL_2;
        OUTPUT:  n_state = (counter != real_size*2)? OUTPUT : (id_out == 'd0)? INPUT_X : CHOOSE;
        default: n_state = INPUT_X;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= INPUT_X;
    else
        c_state <= n_state;
end

// output
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 'd0;
        out_value <= 'd0;
    end
    else begin
        if(c_state == OUTPUT) begin
            out_valid <= 1'd1;
            out_value <= ans[31 - real_size];
        end
        else begin
            out_valid <= 'd0;
            out_value <= 'd0;
        end
    end
end

endmodule
