`define PAT_NUM 400

`include "../00_TESTBED/pseudo_DRAM.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
// import usertype::*;

//================================================================
// Random Constraint
//================================================================
class random_data;
    rand Action action;
    rand Delivery_man_id man_id;
    rand Ctm_Info ctm_info;
    rand Restaurant_id res_id;
    rand food_ID_servings food;

	constraint limit {
        action dist{Take:=1, Deliver:=1, Order:=1, Cancel:=1};
		man_id inside{[0:255]};
        ctm_info.ctm_status dist{Normal:=1, VIP:=1};
        ctm_info.res_ID inside{[0:255]};
        ctm_info.food_ID inside{[1:3]};
        ctm_info.ser_food inside{[1:15]};
        res_id inside{[0:255]};
        food.d_food_ID inside{[1:3]};
        food.d_ser_food inside{[1:15]};
	}
endclass

//================================================================
// Declaration
//================================================================
int patcount, latency, total_latency, total_cycle;
random_data random_input = new();
Action 				action;
Delivery_man_id 	man_id;
Ctm_Info 			ctm_info;
Restaurant_id 		res_id;
food_ID_servings 	food;
D_man_Info 			golden_man_info;
res_info 			golden_res_info;
logic 				golden_complete;
Error_Msg 			golden_err_msg;
logic[63:0] 		golden_out_info;

bit last;
logic take[1:3];
logic [7:0] food_1, food_2, food_3;
logic [8:0] food_total;
logic [2:0] cancel_1, cancel_2;

string action_str;
string err_msg_str;

//================================================================
// Initial DRAM
//================================================================
logic [7:0] dram['h10000 : 'h10000 + 256 * 8 - 1];
res_info 	dram_res[0:255];
D_man_Info 	dram_man[0:255];

initial begin
	$readmemh("../00_TESTBED/DRAM/dram.dat", dram);
	for (int i = 0; i < 256; i++) begin
		dram_res[i] = {dram['h10000 + i * 8 + 0], dram['h10000 + i * 8 + 1], dram['h10000 + i * 8 + 2], dram['h10000 + i * 8 + 3]};
		dram_man[i] = {dram['h10000 + i * 8 + 4], dram['h10000 + i * 8 + 5], dram['h10000 + i * 8 + 6], dram['h10000 + i * 8 + 7]};
	end
end

//================================================================
// Main Pattern
//================================================================
initial begin
    // reset
    inf.rst_n = 1;
    #1
    inf.rst_n = 0;
    inf.D = 'dx; inf.id_valid = 0; inf.act_valid = 0; 
    inf.res_valid = 0; inf.cus_valid = 0; inf.food_valid = 0;
    #20
    inf.rst_n = 1;

    total_latency = 0;
	man_id = -1;
	ctm_info.ctm_status = Normal;
	ctm_info.res_ID = 2;
	ctm_info.food_ID = FOOD1;
	ctm_info.ser_food = 1;
    res_id = 0;
    food.d_food_ID = FOOD1;
	food.d_ser_food = 1;

    for(patcount=1; patcount <= `PAT_NUM; patcount = patcount+1) begin
        input_task;
        golden_task;
        check_ans_task;
    end
    YOU_PASS_task;
end

initial begin
	total_cycle = 0;
	latency = 0;
	forever begin
		total_cycle = total_cycle + 1;
		if(inf.out_valid) latency = 0;
		else latency = latency + 1;
		@(negedge clk);
	end
end

//================================================================
// Task
//================================================================
task input_task;
	// last = ($urandom_range(0, 4) > 3 && action !== 'dx);
	// random_input.randomize();
	
    // action = (last)? action : random_input.action;
    // man_id = (last)? man_id : random_input.man_id;
    // ctm_info = random_input.ctm_info;
    // res_id = (last)? res_id : random_input.res_id;
    // food = random_input.food;

	if(patcount == 264) last = 0;
	else if(patcount >= 399) last = 0;
	else if(patcount >= 151) last = 1;
	else last = 0;

	if(patcount <= 20) begin // Deliver + Take
		action = (patcount % 2 == 1)? Deliver : Take;
		man_id = man_id + 1;
	end
	else if(patcount <= 40) begin // Deliver + Cancel
		action = (patcount % 2 == 1)? Deliver : Cancel;
		man_id = man_id + 1;
	end
	else if(patcount <= 60) begin // Deliver + Order
		action = (patcount % 2 == 1)? Deliver : Order;
		if(patcount % 2 == 1) // Deliver
			man_id = man_id + 1;
	end
	else if(patcount <= 80) begin // Cancel + Take
		action = (patcount % 2 == 1)? Cancel : Take;
		man_id = man_id + 1;
	end
	else if(patcount <= 100) begin // Cancel + Order
		action = (patcount % 2 == 1)? Cancel : Order;
		if(patcount % 2 == 1) // Cancel
			man_id = man_id + 1;
	end
	else if(patcount <= 110) begin // Cancel
		action = Cancel;
		man_id = man_id + 1;
	end
	else if(patcount <= 130) begin // Cancel
		action = Cancel;
		res_id = 1;
		food.d_food_ID = FOOD2;
		man_id = man_id + 1;
	end
	else if(patcount <= 150) begin // Order + Take
		res_id = 2;
		action = (patcount % 2 == 1)? Order : Take;
		if(patcount % 2 == 0) // Take
			man_id = man_id + 1;
	end
	else if(patcount <= 220) begin // Take
		action = Take;
	end
	else if(patcount <= 264) begin // Order
		action = Order;
		res_id = 2;
		food.d_food_ID = FOOD1;
	end
	else if(patcount <= 398) begin // Deliver
		action = Deliver;
		man_id = man_id + 1;
	end
	else if(patcount <= 399) begin // cancel 2
		action = Cancel;
		man_id = man_id + 1;
		res_id = 1;
		food.d_food_ID = FOOD1;
		food.d_ser_food = 0;
	end
	else if(patcount <= 400) begin // take VIP
		action = Take;
		man_id = man_id + 1;
		ctm_info.ctm_status = VIP;
		ctm_info.res_ID = 1;
		ctm_info.food_ID = FOOD1;
		ctm_info.ser_food = 1;
	end


	repeat(1) @(negedge clk);
	inf.act_valid = 1; inf.D.d_act = action; @(negedge clk); inf.D = 'dx; inf.act_valid = 0; // action

	if(action == Take) begin
		// $display("Take   man: %d  res: %d", man_id, ctm_info.res_ID);
		if(!last) begin
			repeat(1) @(negedge clk); // gap
			inf.id_valid = 1; inf.D.d_id = man_id; @(negedge clk); inf.D = 'dx; inf.id_valid = 0; // man_id
		end
		repeat(1) @(negedge clk); // gap
		inf.cus_valid = 1; inf.D.d_ctm_info = ctm_info; @(negedge clk); inf.D = 'dx; inf.cus_valid = 0; // ctm_info
	end
	else if(action == Deliver) begin
		// $display("Deliver   man: %d", man_id);
		repeat(1) @(negedge clk); // gap
		inf.id_valid = 1; inf.D.d_id = man_id; @(negedge clk); inf.D = 'dx; inf.id_valid = 0; // man_id
	end
	else if(action == Order) begin
		// $display("Order   res: %d  food: %d", res_id, food);
		if(!last) begin
			repeat(1) @(negedge clk); // gap
			inf.res_valid = 1; inf.D.d_res_id = res_id; @(negedge clk); inf.D = 'dx; inf.res_valid = 0; // res_id
		end
		repeat(1) @(negedge clk); // gap
		inf.food_valid = 1; inf.D.d_food_ID_ser = food; @(negedge clk); inf.D = 'dx; inf.food_valid = 0; // food
	end
	else if(action == Cancel) begin
		// $display("Cancel   res: %d  food: %d  man: %d", res_id, food, man_id);
		repeat(1) @(negedge clk); // gap
		inf.res_valid = 1; inf.D.d_res_id = res_id; @(negedge clk); inf.D = 'dx; inf.res_valid = 0; // res_id
		repeat(1) @(negedge clk); // gap
		inf.food_valid = 1; inf.D.d_food_ID_ser = food; @(negedge clk); inf.D = 'dx; inf.food_valid = 0; // food
		repeat(1) @(negedge clk); // gap
		inf.id_valid = 1; inf.D.d_id = man_id; @(negedge clk); inf.D = 'dx; inf.id_valid = 0; // man_id
	end
endtask

task golden_task;
	golden_err_msg = 0;
	golden_res_info = (action == Take)? dram_res[ctm_info.res_ID] : dram_res[res_id];
	golden_man_info = dram_man[man_id];
	// $display("res: %32b", golden_res_info);
	// $display("man: %32b", golden_man_info);
	// $display("ctm: %16b", ctm_info);

	case (action)
		Take: begin
			// Calcuclate
			take[1] = (ctm_info.food_ID == FOOD1) && (golden_res_info.ser_FOOD1 >= ctm_info.ser_food);
			take[2] = (ctm_info.food_ID == FOOD2) && (golden_res_info.ser_FOOD2 >= ctm_info.ser_food);
			take[3] = (ctm_info.food_ID == FOOD3) && (golden_res_info.ser_FOOD3 >= ctm_info.ser_food);
			food_1 = golden_res_info.ser_FOOD1 - ctm_info.ser_food;
			food_2 = golden_res_info.ser_FOOD2 - ctm_info.ser_food;
			food_3 = golden_res_info.ser_FOOD3 - ctm_info.ser_food;

			// Error
			if(golden_man_info.ctm_info1.ctm_status != None && golden_man_info.ctm_info2.ctm_status != None)
				golden_err_msg = D_man_busy;  // Delivery man busy
			else begin
				if(take[1] || take[2] || take[3]) begin
					if(take[1]) golden_res_info.ser_FOOD1 = food_1;
					if(take[2]) golden_res_info.ser_FOOD2 = food_2;
					if(take[3]) golden_res_info.ser_FOOD3 = food_3;

					if(golden_man_info.ctm_info1.ctm_status == None)
						golden_man_info.ctm_info1 = ctm_info;
					else if((golden_man_info.ctm_info1.ctm_status == Normal) && (ctm_info.ctm_status == VIP)) begin
						golden_man_info.ctm_info2 = golden_man_info.ctm_info1;
						golden_man_info.ctm_info1 = ctm_info;
					end
					else golden_man_info.ctm_info2 = ctm_info;
				end
				else golden_err_msg = No_Food;  // No food
			end

			// Dram & Golden
			dram_man[man_id] = golden_man_info;
			dram_res[ctm_info.res_ID] = golden_res_info;
		end
		Deliver: begin
			// Error
			if(golden_man_info.ctm_info1.ctm_status == None && golden_man_info.ctm_info2.ctm_status == None)
				golden_err_msg = No_customers;  // No customers
			else begin
				golden_man_info.ctm_info1 = golden_man_info.ctm_info2;
				golden_man_info.ctm_info2 = 0;
			end

			// Dram & Golden
			dram_man[man_id] = golden_man_info;
			golden_res_info = 0;
		end
		Order: begin
			// Calcuclate
			food_1 = golden_res_info.ser_FOOD1 + food.d_ser_food;
			food_2 = golden_res_info.ser_FOOD2 + food.d_ser_food;
			food_3 = golden_res_info.ser_FOOD3 + food.d_ser_food;
			food_total = golden_res_info.ser_FOOD1 + golden_res_info.ser_FOOD2 + golden_res_info.ser_FOOD3 + food.d_ser_food;

			// Error
			if(food_total > golden_res_info.limit_num_orders) begin
				golden_err_msg = Res_busy; // Restaurant busy
			end
			else begin
				if(food.d_food_ID == FOOD1) golden_res_info.ser_FOOD1 = food_1;
				if(food.d_food_ID == FOOD2) golden_res_info.ser_FOOD2 = food_2;
				if(food.d_food_ID == FOOD3) golden_res_info.ser_FOOD3 = food_3;
			end

			// Dram & Golden
			dram_res[res_id] = golden_res_info;
			golden_man_info = 0;
		end
		Cancel: begin
			// Calcuclate
			// if(golden_man_info.ctm_info1.ctm_status == None) cancel_1 = 0;  // No customer
			// else begin
				cancel_1[0] = (golden_man_info.ctm_info1.res_ID == res_id);
				cancel_1[1] = (golden_man_info.ctm_info1.food_ID == food.d_food_ID);
				cancel_1[2] = (golden_man_info.ctm_info1.res_ID == res_id) && (golden_man_info.ctm_info1.food_ID == food.d_food_ID);
			// end
			// if(golden_man_info.ctm_info2.ctm_status == None) cancel_2 = 0;  // No customer
			// else begin
				cancel_2[0] = (golden_man_info.ctm_info2.res_ID == res_id);
				cancel_2[1] = (golden_man_info.ctm_info2.food_ID == food.d_food_ID);
				cancel_2[2] = (golden_man_info.ctm_info2.res_ID == res_id) && (golden_man_info.ctm_info2.food_ID == food.d_food_ID);
			// end

			// Error
			// if(golden_man_info.ctm_info1.ctm_status == None && golden_man_info.ctm_info2.ctm_status == None) begin
			if(golden_man_info == 0) begin  
				golden_err_msg = Wrong_cancel;  // Wrong cancel
			end
			else if(cancel_1[2] && cancel_2[2]) begin
				golden_man_info = 0;
			end
			else if(cancel_1[2]) begin
				golden_man_info.ctm_info1 = golden_man_info.ctm_info2;
				golden_man_info.ctm_info2 = 0;
			end
			else if(cancel_2[2]) begin
				golden_man_info.ctm_info2 = 0;
			end
			else if(cancel_1[0] || cancel_2[0]) begin
				golden_err_msg = Wrong_food_ID; // Wrong food ID
			end
			else begin // Wrong restaurant ID
				golden_err_msg = Wrong_res_ID;
			end

			// Dram & Golden
			dram_man[man_id] = golden_man_info;
			golden_res_info = 0;
		end
	endcase
endtask

task check_ans_task;
	while (inf.out_valid === 1'b0) @(negedge clk);

	golden_complete = !(|golden_err_msg);
	golden_out_info = (golden_complete)? {golden_man_info, golden_res_info} : 0;
	golden_err_msg = (golden_complete)? 0 : golden_err_msg;
	// golden_out_info = (golden_complete)? {golden_man_info, golden_res_info} : inf.out_info; // Don't check out_info when complete = 0
	// golden_err_msg = (golden_complete)? inf.err_msg : golden_err_msg; // Don't check err_msg when complete = 1

	if (inf.complete !== golden_complete || inf.err_msg !== golden_err_msg || inf.out_info !== golden_out_info) begin
		$display("Wrong Answer");
		// $display("----------------------------------------------------------------------\n");
		// $display("                          Wrong Answer!                                 ");
		// $display("golden should be %1b, %4b, %32b  %32b                                   ", golden_complete, golden_err_msg, golden_out_info[63:32], golden_out_info[31:0]);
		// $display("your is          %1b, %4b, %32b  %32b                                   ", inf.complete, inf.err_msg, inf.out_info[63:32], inf.out_info[31:0]);
		// $display("----------------------------------------------------------------------\n");
		$finish;
	end
	
	// if(action == Take) action_str = "Take";
	// if(action == Deliver) action_str = "Deliver";
	// if(action == Order) action_str = "Order";
	// if(action == Cancel) action_str = "Cancel";
	// if(last && action == Take) action_str = "Take(last)";
	// if(last && action == Order) action_str = "Order(last)";
	// if(golden_err_msg == No_Err) err_msg_str = "No_Err";
	// if(golden_err_msg == No_Food) err_msg_str = "No_Food";
	// if(golden_err_msg == D_man_busy) err_msg_str = "D_man_busy";
	// if(golden_err_msg == No_customers) err_msg_str = "No_customers";
	// if(golden_err_msg == Res_busy) err_msg_str = "Res_busy";
	// if(golden_err_msg == Wrong_cancel) err_msg_str = "Wrong_cancel";
	// if(golden_err_msg == Wrong_res_ID) err_msg_str = "Wrong_res_ID";
	// if(golden_err_msg == Wrong_food_ID) err_msg_str = "Wrong_food_ID";
    // $display("\033[0;34mPass Pattern NO.%4d, \033[0;32mLatency: %3d,  \033[0;35mAction: %11s,  \033[1;33mError: %s\033[m", patcount, latency, action_str, err_msg_str);
	@(negedge clk);
endtask


task YOU_PASS_task;
    begin
        // $display ("\n--------------------------------------------------------------------");
        // $display ("           ~(￣▽￣)~(＿△＿)~(￣▽￣)~(＿△＿)~(￣▽￣)~             ");
        // $display ("                         Congratulations!                           ");
        // $display ("                   You have passed all patterns!                    ");
		// $display ("                         Total Cycle: %4d                           ", total_cycle);
        // $display ("--------------------------------------------------------------------\n");
        $finish;
    end
endtask

endprogram