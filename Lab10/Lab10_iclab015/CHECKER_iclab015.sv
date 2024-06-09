module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//========================================================================================================================================================
// Declare Cover Group
//========================================================================================================================================================
covergroup cg1 @(posedge clk iff (inf.id_valid));
    coverpoint inf.D.d_id[0]{
        option.at_least = 1;
        option.auto_bin_max = 256;
    }
endgroup

covergroup cg2 @(posedge clk iff (inf.act_valid));
       	coverpoint inf.D.d_act[0] {
   		option.at_least = 10;
   		bins b[] = (Take, Deliver, Order, Cancel => Take, Deliver, Order, Cancel);
   	}
endgroup

covergroup cg3 @(negedge clk iff (inf.out_valid));
    coverpoint inf.complete{
        option.at_least = 200;
        option.auto_bin_max = 2;
    }
endgroup

covergroup cg4 @(negedge clk iff (inf.out_valid));
    coverpoint inf.err_msg{
        option.at_least = 20;
        bins b [] = {No_Food, D_man_busy, No_customers, Res_busy,Wrong_cancel, Wrong_res_ID, Wrong_food_ID};
    }
endgroup

cg1 cg1_inst = new();
cg2 cg2_inst = new();
cg3 cg3_inst = new();
cg4 cg4_inst = new();

//************************************ below assertion is to check your pattern ***************************************** 
//                                          Please finish and hand in it
// This is an example assertion given by TA, please write the required assertions below
//  assert_interval : assert property ( @(posedge clk)  inf.out_valid |=> inf.id_valid == 0 [*2])
//  else
//  begin
//  	//$display("Assertion X is violated");
//  	$fatal; 
//  end
wire #(0.5) rst_reg = inf.rst_n;

string NO_COLOR =   "\033[0m\n";
string RED =        "\033[;31m";
string PURPLE =     "\033[0;35m";
string GREEN =      "\033[1;32m";
string YELLOW =     "\033[1;33m";
string BLUE =       "\033[1;34m";


//========================================================================================================================================================
// Assertion 1 ( All outputs signals (including FD.sv and bridge.sv) should be zero after reset. )
//========================================================================================================================================================
wire reset_singal = (inf.out_valid || inf.err_msg || inf.complete || inf.out_info) || 
                    (inf.C_addr || inf.C_data_w || inf.C_in_valid || inf.C_r_wb || inf.C_out_valid || inf.C_data_r) ||
                    (inf.AR_VALID || inf.AR_ADDR || inf.R_READY || inf.AW_VALID || inf.AW_ADDR || inf.W_VALID || inf.W_DATA || inf.B_READY);
assert_1 : 
    assert property ( @(negedge rst_reg)  reset_singal === 0 )
    else begin
        $display("Assertion 1 is violated");
        //$display(RED,"\nAssertion 1 is violated");
        //$display(YELLOW, "All outputs signals (including FD.sv and bridge.sv) should be zero after reset.", NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 2 ( If action is completed, err_msg should be 4'b0. )
//========================================================================================================================================================
assert_2 : 
    assert property ( @(posedge clk)  (inf.out_valid === 1 && inf.complete === 1) |-> inf.err_msg === 4'd0 )
    else begin
        $display("Assertion 2 is violated");
        //$display(RED,"\nAssertion 2 is violated");
        //$display(YELLOW, "If action is completed, err_msg should be 4'b0.", NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 3 ( If action is not completed, out_info should be 64'b0. )
//========================================================================================================================================================
assert_3 : 
    assert property ( @(posedge clk)  (inf.out_valid === 1 && inf.complete === 0) |-> inf.out_info === 64'd0 )
    else begin
        $display("Assertion 3 is violated");
        //$display(RED,"\nAssertion 3 is violated");
        //$display(YELLOW, "If action is not completed, out_info should be 64'b0.", NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 4 ( The gap between each input valid is at least 1 cycle and at most 5 cycles. )
//========================================================================================================================================================
wire in_valid = (inf.act_valid || inf.id_valid || inf.res_valid || inf.cus_valid || inf.food_valid);
assert_4 : 
    assert property ( @(posedge clk)
        ((inf.act_valid && inf.D.d_act == Take)    |=> (in_valid === 0 ##[1:5] inf.id_valid ##[2:6] inf.cus_valid) or (in_valid === 0 ##[1:5] inf.cus_valid)) or
        ((inf.act_valid && inf.D.d_act == Deliver) |=> (in_valid === 0 ##[1:5] inf.id_valid)) or
        ((inf.act_valid && inf.D.d_act == Order)   |=> (in_valid === 0 ##[1:5] inf.res_valid ##[2:6] inf.food_valid) or (in_valid === 0 ##[1:5] inf.food_valid)) or
        ((inf.act_valid && inf.D.d_act == Cancel)  |=> (in_valid === 0 ##[1:5] inf.res_valid ##[2:6] inf.food_valid ##[2:6] inf.id_valid)) ) 
    else begin
        $display("Assertion 4 is violated");
        //$display(RED,"\nAssertion 4 is violated");
        //$display(YELLOW, "The gap between each input valid is at least 1 cycle and at most 5 cycles.", NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 5 ( All input valid signals won't overlap with each other. )
//========================================================================================================================================================
wire [2:0] in_valid_overlap = inf.act_valid + inf.id_valid + inf.res_valid + inf.cus_valid + inf.food_valid;
assert_5 : 
    assert property ( @(posedge clk)  in_valid_overlap <= 1 )
    else begin
        $display("Assertion 5 is violated");
        //$display(RED,"\nAssertion 5 is violated");
        //$display(YELLOW, "All input valid signals won't overlap with each other.", NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 6 ( Out_valid can only be high for exactly one cycle. )
//========================================================================================================================================================
assert_6 : 
    assert property ( @(posedge clk)  (inf.out_valid === 1) |=> (inf.out_valid === 0) )
    else begin
        $display("Assertion 6 is violated");
        //$display(RED,"\nAssertion 6 is violated");
        //$display(YELLOW, "Out_valid can only be high for exactly one cycle.", NO_COLOR);
                //$display(YELLOW, "%d", inf.out_valid, NO_COLOR);
        $fatal; 
    end

//========================================================================================================================================================
// Assertion 7 ( Next operation will be valid 2-10 cycles after out_valid fall. )
//========================================================================================================================================================
assert_7 : 
    assert property ( @(posedge clk)  (inf.out_valid === 1) |-> (in_valid === 0 ##1 in_valid === 0 ##[1:9] inf.act_valid) )
    else begin
        $display("Assertion 7 is violated");
        //$display(RED,"\nAssertion 7 is violated");
        //$display(YELLOW, "Next operation will be valid 2-10 cycles after out_valid fall.", NO_COLOR);
        $fatal;
    end

//========================================================================================================================================================
// Assertion 8 ( Latency should be less than 1200 cycles for each operation. )
//========================================================================================================================================================
assert_8 : 
    assert property ( @(posedge clk)  in_valid |-> (##[1:5] in_valid) or (##[1:1199] inf.out_valid) )
    else begin
        $display("Assertion 8 is violated");
        //$display(RED,"\nAssertion 8 is violated");
        //$display(YELLOW, "Latency should be less than 1200 cycles for each operation.", NO_COLOR);
        $fatal; 
    end


endmodule