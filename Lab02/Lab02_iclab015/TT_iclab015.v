module TT(
           //Input Port
           input         clk,
           input         rst_n,
           input         in_valid,
           input  [3:0]  source,
           input  [3:0]  destination,

           //Output Port
           output reg          out_valid,
           output wire  [3:0]  cost
       );


//==============================================//
//             Parameter and Integer            //
//==============================================//
genvar i, j;
parameter FIRST  = 2'd0,
          INPUT  = 2'd1,
          FIND   = 2'd2,
          OUTPUT = 2'd3;

//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [1:0] c_state, n_state;

//==============================================//
//             register declaration             //
//==============================================//
reg [3:0] cnt, dst;
reg [15:0] adj_matrix[0:15];
reg [15:0] arrival;

//==============================================//
//               wire declaration               //
//==============================================//
wire [15:0] adj_vector[0:15];
wire [15:0] temp[0:15];
wire [15:0] next_arrival;
wire arr_dst, not_found;

//==============================================//
//             Current State Block              //
//==============================================//
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= FIRST; /* initial state */
    else
        c_state <= n_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always@(*) begin
    case(c_state)
        FIRST:
            n_state = (in_valid) ? INPUT : FIRST;
        INPUT: begin
            if(in_valid)  // 輸入中
                n_state = INPUT;
            else if(arr_dst || not_found)  // 一步抵達 或 找不到
                n_state = OUTPUT;
            else  // 尋找路徑
                n_state = FIND;
        end
        FIND:
            n_state = (arr_dst || not_found) ? FIRST : FIND;
        default:
            n_state = FIRST;
    endcase
end

//==============================================//
//                  Input Block                 //
//==============================================//
generate  // 儲存 adjacency matrix
    for(i=0; i<16; i=i+1) begin: matrix_row
        for(j=i; j<16; j=j+1) begin: matrix_col
            always @(posedge clk) begin
                if(i == j)  // 自己連自己
                    adj_matrix[i][j] <= 1'd1;
                else begin
                    case (c_state)
                        FIRST: begin
                            adj_matrix[i][j] <= 0;
                        end
                        INPUT: begin
                            if(in_valid) begin
                                if(source == i && destination == j)  // 只存半張表
                                    adj_matrix[i][j] <= 1'd1;
                                if(destination == i && source == j)
                                    adj_matrix[i][j] <= 1'd1;
                            end
                        end
                    endcase
                end
            end
        end
    end
endgenerate

generate  // 半張表轉整張表
    for (i=0; i<16; i=i+1) begin: vector_row
        for (j=0; j<16; j=j+1) begin: vector_col
            assign adj_vector[i][j] = (i < j) ? adj_matrix[i][j] : adj_matrix[j][i];
        end
    end
endgenerate

//==============================================//
//       Calculation Block (Combinational)      //
//==============================================//
generate  // 下一步可以抵達的點
    for (i=0; i<16; i=i+1) begin: temp_row
        assign temp[i] = (arrival[i] == 1'd1) ? adj_vector[i] : 16'd0;
    end
endgenerate

assign next_arrival = arrival | temp[0] | temp[1] | temp[2] | temp[3] | temp[4]
       | temp[5] | temp[6] | temp[7] | temp[8] | temp[9] | temp[10]
       | temp[11] | temp[12] | temp[13] | temp[14] | temp[15];

assign arr_dst = (next_arrival[dst] == 1'd1);
assign not_found = (arrival == next_arrival);

//==============================================//
//        Calculation Block (Sequential)        //
//==============================================//
always @(posedge clk) begin  // 儲存目標終點
    dst <= (c_state == FIRST) ? destination : dst;
end

always @(posedge clk) begin  // 計算 cost
    case (c_state)
        FIRST:
            cnt <= 4'd0;
        INPUT: begin
            if(arr_dst)  // 一步抵達
                cnt <= 4'd1;
            else if(not_found)  // 找不到
                cnt <= 4'd0;
            else
                cnt <= 4'd2;
        end
        default:
            cnt <= cnt + 4'd1;
    endcase
end

always @(posedge clk) begin  // 儲存已抵達的點
    case (c_state)
        FIRST: begin
            arrival <= 16'd0;
            arrival[source] <= 1'd1;
        end
        INPUT:
            arrival <= (!in_valid) ? next_arrival : arrival;
        FIND:
            arrival <= next_arrival;
    endcase
end

//==============================================//
//                Output Block                  //
//==============================================//
assign cost = (c_state == FIRST) ? 4'd0 : (arr_dst) ? cnt : 4'd0;

always @(*) begin
    case (c_state)
        INPUT:
            out_valid = 1'd0;
        FIND: begin
            if(not_found)   // 找不到
                out_valid = 1'd1;
            else
                out_valid = (arr_dst) ? 1'd1 : 1'd0;  // 抵達終點
        end
        OUTPUT:
            out_valid = 1'd1;
        default:
            out_valid = 1'd0;
    endcase
end

endmodule
