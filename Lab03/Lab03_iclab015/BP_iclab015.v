module BP(
           // input signal
           input clk,
           input rst_n,
           input in_valid,
           input [2:0] guy,
           input [1:0] in0,
           input [1:0] in1,
           input [1:0] in2,
           input [1:0] in3,
           input [1:0] in4,
           input [1:0] in5,
           input [1:0] in6,
           input [1:0] in7,

           // output signal
           output reg out_valid,
           output reg [1:0] out
       );

//==============================================//
//             Parameter and Integer            //
//==============================================//
genvar i;
parameter IDLE   = 2'd0,
          WAIT   = 2'd1,
          CAL    = 2'd2,
          OUTPUT = 2'd3;

//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [1:0] n_state, c_state;

//==============================================//
//       register declaration (Sequential)      //
//==============================================//
reg [5:0] counter;
reg [2:0] obs_pos_reg [0:4];
reg [1:0] obs_type_reg [0:4];
reg [1:0] out_reg [0:57];
reg [2:0] guy_pos;

//==============================================//
//      register declaration (Combinational)    //
//==============================================//
reg [2:0] obs_pos;
reg [1:0] obs_type;
reg [2:0] next_obs;

//==============================================//
//               wire declaration               //
//==============================================//
wire [1:0] out_move;

//==============================================//
//             Current State Block              //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= IDLE;
    else
        c_state <= n_state;
end

//==============================================//
//              Next State Block                //
//==============================================//
always @(*) begin
    case (c_state)
        IDLE:
            n_state = (in_valid) ? WAIT : IDLE;
        WAIT:
            n_state = (counter == 6'd5) ? CAL : WAIT;
        CAL:
            n_state = (counter == 6'd63) ? OUTPUT : CAL;
        OUTPUT:
            n_state = (counter == 6'd62) ? IDLE : OUTPUT;
        default:
            n_state = IDLE;
    endcase
end
//==============================================//
//                  Input Block                 //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        guy_pos <= 3'd0;
    else begin
        case (c_state)
            IDLE:
                guy_pos <= guy;
            WAIT:
                guy_pos <= guy_pos;
            default:
                guy_pos <=  (obs_type_reg[4] == 1'd1 || out_move == 2'd0) ? guy_pos :
                    (out_move == 2'd1) ? guy_pos + 1 : guy_pos - 1;
        endcase
    end
end

always @(*) begin
    if(!in_valid) begin  // out of input cycle
        obs_pos = 3'd3;
        obs_type = 2'd2;
    end
    else begin
        if(in0 == 2'd0) begin  // full of flat ground
            obs_pos = 3'd3;
            obs_type = 2'd2;
        end
        else begin  // nearset obstacles
            if(in0 != 2'b11) begin
                obs_pos = 3'd0;
                obs_type = (in0 == 2'b01);
            end
            else if(in1 != 2'b11) begin
                obs_pos = 3'd1;
                obs_type = (in1 == 2'b01);
            end
            else if(in2 != 2'b11) begin
                obs_pos = 3'd2;
                obs_type = (in2 == 2'b01);
            end
            else if(in3 != 2'b11) begin
                obs_pos = 3'd3;
                obs_type = (in3 == 2'b01);
            end
            else if(in4 != 2'b11) begin
                obs_pos = 3'd4;
                obs_type = (in4 == 2'b01);
            end
            else if(in5 != 2'b11) begin
                obs_pos = 3'd5;
                obs_type = (in5 == 2'b01);
            end
            else if(in6 != 2'b11) begin
                obs_pos = 3'd6;
                obs_type = (in6 == 2'b01);
            end
            else begin
                obs_pos = 3'd7;
                obs_type = (in7 == 2'b01);
            end
        end
    end
end

generate // no reset for just store data
    for(i=0;i<4;i=i+1)
        always @(posedge clk) begin
            obs_pos_reg[i+1] <= obs_pos_reg[i];
            obs_type_reg[i+1] <= obs_type_reg[i];
        end
endgenerate
always @(posedge clk) begin
    obs_pos_reg[0] <= obs_pos;
    obs_type_reg[0] <= obs_type;
end

//==============================================//
//       Calculation Block (Combinational)      //
//==============================================//
always @(*) begin
    if(obs_type_reg[4] < 2'd2)  // obstacle in 1st cycle
        next_obs = obs_pos_reg[4];
    else if(obs_type_reg[3] < 2'd2)  // obstacle in 2nd cycle
        next_obs = obs_pos_reg[3];
    else if(obs_type_reg[2] < 2'd2)  // obstacle in 3rd cycle
        next_obs = obs_pos_reg[2];
    else if(obs_type_reg[1] < 2'd2)  // obstacle in 4th cycle
        next_obs = obs_pos_reg[1];
    else if(obs_type_reg[0] < 2'd2)  // obstacle in 5th cycle
        next_obs = obs_pos_reg[0];
    else
        next_obs = 3;
end
assign out_move = (guy_pos == next_obs) ? 2'd0 : (guy_pos < next_obs) ? 2'd1 : 2'd2;

//==============================================//
//        Calculation Block (Sequential)        //
//==============================================//
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        counter <= 6'd0;
    else
        counter <= (c_state == IDLE) ? 6'd1 : counter + 6'd1;
end

//==============================================//
//                Output Block                  //
//==============================================//

generate // no reset for just store data
    for(i=0;i<57;i=i+1)
        always @(posedge clk) begin
            out_reg[i+1] <= out_reg[i];
        end
endgenerate
always @(posedge clk) begin
    out_reg[0] <= (obs_type_reg[4] == 1'd1) ? 2'd3 : out_move;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <= 1'd0;
        out <= 2'd0;
    end
    else begin
        if(c_state == OUTPUT) begin
            out_valid <= 1'd1;
            out <= out_reg[57];
        end
        else begin
            out_valid <= 1'd0;
            out <= 2'd0;
        end
    end
end

endmodule
