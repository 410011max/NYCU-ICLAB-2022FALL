//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : UT_TOP.v
//   Module Name : UT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW_div.v"
//synopsys translate_on

module UT_TOP (
    // Input signals
    clk, rst_n, in_valid, in_time,
    // Output signals
    out_valid, out_display, out_day
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [30:0] in_time;
output reg out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;

// ===============================================================
// Parameter & Integer Declaration
// ===============================================================
genvar i;
integer j;
parameter INPUT  = 2'd0,
          CAL    = 2'd1,
          OUTPUT = 2'd2;

//================================================================
// Wire & Reg Declaration
//================================================================
reg [1:0] c_state, n_state;
reg [30:0] in_time_reg;
reg [3:0] counter;
reg [6:0] BCD_in;
wire [7:0] BCD_out;

// year
reg [8:0] year_day;
reg [10:0] year_4_day;
reg [4:0] year_4;
reg [6:0] year, year_1;

// month
reg [8:0] month_table[1:12];
reg [8:0] month_table_day;
reg [4:0] month_day;
reg [3:0] month;

// day
reg [14:0] total_day;
reg [16:0] day_time;
reg [4:0] day;

// hour, minute, second
reg [4:0] hour;
reg [16:0] hour_time;
reg [5:0] minute, second;

//================================================================
// DESIGN
//================================================================

// year
always @(posedge clk) begin
    total_day <= ((in_time_reg >> 7) / 675) + 'd4;
    year_4 <= (total_day - 'd4) / 1461;
    
    year <= (year_1 >= 30)? year_1 - 'd30 : year_1 + 'd70;

    year_day <= (year_4_day < 'd365)?  year_4_day :
                (year_4_day < 'd730)?  year_4_day - 'd365:
                (year_4_day < 'd1096)? year_4_day - 'd730 : year_4_day - 'd1096;
end

always @(*) begin
    year_4_day = (total_day - 'd4) - year_4*1461;
    year_1 = (year_4_day < 'd365)?  year_4 * 4 :
             (year_4_day < 'd730)?  year_4 * 4 + 1 :
             (year_4_day < 'd1096)? year_4 * 4 + 2 : year_4 * 4 + 3;
end

// month
always @(*) begin
    month_table[1]  = 'd0;
    month_table[2]  = 'd31;
    month_table[3]  = (year % 4 == 0)? 'd60 : 'd59;
    month_table[4]  = (year % 4 == 0)? 'd91 : 'd90;
    month_table[5]  = (year % 4 == 0)? 'd121 : 'd120;
    month_table[6]  = (year % 4 == 0)? 'd152 : 'd151;
    month_table[7]  = (year % 4 == 0)? 'd182 : 'd181;
    month_table[8]  = (year % 4 == 0)? 'd213 : 'd212;
    month_table[9]  = (year % 4 == 0)? 'd244 : 'd243;
    month_table[10] = (year % 4 == 0)? 'd274 : 'd273;
    month_table[11] = (year % 4 == 0)? 'd305 : 'd304;
    month_table[12] = (year % 4 == 0)? 'd335 : 'd334;
end

always @(posedge clk) begin
    for(j=1;j<=12;j=j+1)
        if(year_day >= month_table[j]) begin
            month <= j;
            month_table_day <= month_table[j];
        end
    month_day <= year_day - month_table_day;
end

// day
always @(posedge clk) begin
    for(j=1;j<=31;j=j+1) begin
        if(month_day >= (j-1)) begin
            day <= j;
        end
    end
    day_time <= in_time_reg - (total_day - 'd4)*86400;
end

// hour, minute, second
always @(posedge clk) begin
    hour <= (day_time >> 4) / 225;
    hour_time <= day_time - hour * 3600;
    minute <= (hour_time >> 2) / 15;
    second <= hour_time - minute * 60;
end

// counter
always @(posedge clk) begin
    counter <= (c_state == OUTPUT)? counter + 'd1 : 'd0;
end

// input
always @(posedge clk) begin
    in_time_reg <= (in_valid)? in_time : in_time_reg;
end

// next state logic
always @(*) begin
    case (c_state)
        INPUT:    n_state = (in_valid)? CAL : INPUT;
        CAL:      n_state = OUTPUT;
        OUTPUT:   n_state = (counter == 'd13)? INPUT : OUTPUT;
        default:  n_state = INPUT;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= INPUT;
    else c_state <= n_state;
end

//output
B2BCD_IP #(7, 2) u_BCD (.Binary_code(BCD_in), .BCD_code(BCD_out));

always @(*) begin
    case (counter)
        2:  BCD_in = year;
        3:  BCD_in = year;
        4:  BCD_in = month;
        5:  BCD_in = month;
        6:  BCD_in = day;
        7:  BCD_in = day;
        8:  BCD_in = hour;
        9:  BCD_in = hour;
        10: BCD_in = minute;
        11: BCD_in = minute;
        12: BCD_in = second;
        13: BCD_in = second;
        default: BCD_in = 'dx;
    endcase
end

wire [2:0] week_result;
DW_div #(15, 3, 0, 1) u_div1 (.a(total_day), .b(3'd7), .remainder(week_result));
//synopsys dc_script_begin
//set_implementation mlt u_div1
//synopsys dc_script_end

always @(*) begin
    // if(!rst_n) begin
    //     out_valid <= 'd0;
    //     out_display <= 'd0;
    //     out_day <= 'd0;
    // end
    // else begin
        if(c_state == OUTPUT) begin
            out_valid <= 'd1;
            if(counter == 'd0)        out_display <= (in_time_reg >= 946684800)? 'd2 : 'd1;
            else if(counter == 'd1)   out_display <= (in_time_reg >= 946684800)? 'd0 : 'd9;
            else                      out_display <= (counter[0])? BCD_out[3:0] : BCD_out[7:4];
            out_day <= week_result;
        end
        else begin
            out_valid <= 'd0;
            out_display <= 'd0;
            out_day <= 'd0;
        end
    // end
end

endmodule