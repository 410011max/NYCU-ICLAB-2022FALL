module FD(input clk, INF.FD_inf inf);
import usertype::*;

//===========================================================================
// parameter 
//===========================================================================
typedef enum logic  [4:0] { INPUT   = 0,
                            READ    = 1,
                            WAIT    = 2,
                            READ_2  = 3,
                            WAIT_2  = 4,
                            TAKE    = 5,
                            DELIVER = 6,
                            ORDER   = 7,
                            CANCEL  = 8,
                            OUTPUT  = 9,
                            ERROR   = 10,
                            WRITE   = 11,
                            WAIT_W  = 12,
                            WRITE_2 = 13,
                            WAIT_W_2= 14,
                            IDLE    = 15,
                            IDLE_2  = 16
                            } State;

//===========================================================================
// logic 
//===========================================================================
State c_state, n_state;
Action action;
Delivery_man_id man_id;
Ctm_Info ctm_info;
food_ID_servings food_serving;
Restaurant_id res_id;

D_man_Info man_info_reg, man_info_reg_2;
res_info res_info_reg, res_info_reg_2;

logic [2:0] err_reg;
logic take[1:3];
logic [7:0] food_1, food_2, food_3;
logic [9:0] food_total, food_temp_1, food_temp_2;
logic [2:0] cancel_1, cancel_2;

//===========================================================================
// design
//===========================================================================
// Input
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        action <= 0;
        man_id <= 0;
        ctm_info <= 0;
        food_serving <= 0;
        res_id <= 0;
    end
    else begin
        action <= (inf.act_valid)? inf.D.d_act[0] : action;
        man_id <= (inf.id_valid)? inf.D.d_id[0] : man_id;
        ctm_info <= (inf.cus_valid)? inf.D.d_ctm_info[0] : ctm_info;
        food_serving <= (inf.food_valid)? inf.D.d_food_ID_ser[0] : food_serving;
        res_id <= (inf.res_valid)? inf.D.d_res_id[0] : res_id;
    end
end

// Action
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        err_reg <= 0;
        man_info_reg <= 0;
        res_info_reg <= 0;
        man_info_reg_2 <= 0;
        res_info_reg_2 <= 0;
    end
    else begin
        case (c_state)
            INPUT: err_reg <= 0;
            WAIT: begin
                man_info_reg <= (inf.C_out_valid)? inf.C_data_r[63:32] : man_info_reg;
                res_info_reg <= (inf.C_out_valid)? inf.C_data_r[31:0] : res_info_reg;
            end
            WAIT_2: begin
                man_info_reg_2 <= (inf.C_out_valid)? inf.C_data_r[63:32] : man_info_reg_2;
                res_info_reg_2 <= (inf.C_out_valid)? inf.C_data_r[31:0] : res_info_reg_2;
            end
            TAKE: begin
                if(man_info_reg_2.ctm_info1.ctm_status != None && man_info_reg_2.ctm_info2.ctm_status != None)
                    err_reg[0] <= 1;
                else begin
                    if(take[1] || take[2] || take[3]) begin
                        if(take[1]) res_info_reg.ser_FOOD1 <= food_1;
                        if(take[2]) res_info_reg.ser_FOOD2 <= food_2;
                        if(take[3]) res_info_reg.ser_FOOD3 <= food_3;

                        if(man_info_reg_2.ctm_info1.ctm_status == None)
                            man_info_reg_2.ctm_info1 <= ctm_info;
                        else if((man_info_reg_2.ctm_info1.ctm_status == Normal) && (ctm_info.ctm_status == VIP)) begin
                            man_info_reg_2.ctm_info1 <= ctm_info;
                            man_info_reg_2.ctm_info2 <= man_info_reg_2.ctm_info1;
                        end
                        else man_info_reg_2.ctm_info2 <= ctm_info;
                    end
                    else err_reg[1] <= 1;
                end
            end
            DELIVER: begin
                if(man_info_reg.ctm_info1.ctm_status == None && man_info_reg.ctm_info2.ctm_status == None)
                    err_reg[0] <= 1;
                else begin
                    man_info_reg.ctm_info1 <= man_info_reg.ctm_info2;
                    man_info_reg.ctm_info2 <= 0;
                end
            end
            ORDER: begin
                if(food_total > res_info_reg.limit_num_orders) begin
                    err_reg[0] <= 1;
                end
                else begin
                    if(food_serving.d_food_ID == FOOD1) 
                        res_info_reg.ser_FOOD1 <= food_1;
                    if(food_serving.d_food_ID == FOOD2) 
                        res_info_reg.ser_FOOD2 <= food_2;
                    if(food_serving.d_food_ID == FOOD3) 
                        res_info_reg.ser_FOOD3 <= food_3;
                end
            end
            CANCEL: begin
                if(man_info_reg.ctm_info1.ctm_status == None && man_info_reg.ctm_info2.ctm_status == None) begin  // Wrong cancel
                    err_reg[0] <= 1; 
                end
                else if(cancel_1[2] && cancel_2[2]) begin
                    man_info_reg <= 0;
                end
                else if(cancel_1[2]) begin
                    man_info_reg.ctm_info1 <= man_info_reg.ctm_info2;
                    man_info_reg.ctm_info2 <= 0;
                end
                else if(cancel_2[2]) begin
                    man_info_reg.ctm_info2 <= 0;
                end
                else if(cancel_1[0] || cancel_2[0]) begin
                    err_reg[2] <= 1; // Wrong food ID
                end
                else begin // Wrong restaurant ID
                    err_reg[1] <= 1;
                end
            end
        endcase
    end
end

// Calculate
always_comb begin
    take[1] = (ctm_info.food_ID == FOOD1) && (res_info_reg.ser_FOOD1 >= ctm_info.ser_food);
    take[2] = (ctm_info.food_ID == FOOD2) && (res_info_reg.ser_FOOD2 >= ctm_info.ser_food);
    take[3] = (ctm_info.food_ID == FOOD3) && (res_info_reg.ser_FOOD3 >= ctm_info.ser_food);
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        food_1 <= 0;
        food_2 <= 0;
        food_3 <= 0;
        food_total <= 0;
    end
    else begin
        food_1 <= (action == Take)? res_info_reg.ser_FOOD1 - ctm_info.ser_food : res_info_reg.ser_FOOD1 + food_serving.d_ser_food;;
        food_2 <= (action == Take)? res_info_reg.ser_FOOD2 - ctm_info.ser_food : res_info_reg.ser_FOOD2 + food_serving.d_ser_food;;
        food_3 <= (action == Take)? res_info_reg.ser_FOOD3 - ctm_info.ser_food : res_info_reg.ser_FOOD3 + food_serving.d_ser_food;;
        food_temp_1 <= res_info_reg.ser_FOOD1 + res_info_reg.ser_FOOD2;
        food_temp_2 <= res_info_reg.ser_FOOD3 + food_serving.d_ser_food;
        food_total <= food_temp_1 + food_temp_2;
    end
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        cancel_1 <= 0;
        cancel_2 <= 0;
    end
    else begin
        if(man_info_reg.ctm_info1.ctm_status == None) cancel_1 <= 0;  // No customer
        else begin
            cancel_1[0] <= (man_info_reg.ctm_info1.res_ID == res_id);
            cancel_1[1] <= (man_info_reg.ctm_info1.food_ID == food_serving.d_food_ID);
            cancel_1[2] <= (man_info_reg.ctm_info1.res_ID == res_id) && (man_info_reg.ctm_info1.food_ID == food_serving.d_food_ID);
        end
        if(man_info_reg.ctm_info2.ctm_status == None) cancel_2 <= 0;  // No customer
        else begin
            cancel_2[0] <= (man_info_reg.ctm_info2.res_ID == res_id);
            cancel_2[1] <= (man_info_reg.ctm_info2.food_ID == food_serving.d_food_ID);
            cancel_2[2] <= (man_info_reg.ctm_info2.res_ID == res_id) && (man_info_reg.ctm_info2.food_ID == food_serving.d_food_ID);
        end
    end
end


// DRAM
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        inf.C_addr <= 0;
        inf.C_data_w <= 0;
        inf.C_in_valid <= 0;
        inf.C_r_wb <= 0;
    end
    else begin
        if(c_state == READ) begin
            if(action == Take)          inf.C_addr <= ctm_info.res_ID;
            else if(action == Deliver)  inf.C_addr <= man_id;
            else if(action == Order)    inf.C_addr <= res_id;
            else                        inf.C_addr <= man_id;
            inf.C_data_w <= 0;
            inf.C_in_valid <= 1;
            inf.C_r_wb <= 1;  // 1 for Read, 0 for Write
        end
        else if(c_state == WRITE) begin
            if(action == Take)          inf.C_addr <= ctm_info.res_ID;
            else if(action == Deliver)  inf.C_addr <= man_id;
            else if(action == Order)    inf.C_addr <= res_id;
            else                        inf.C_addr <= man_id;
            inf.C_data_w <= {man_info_reg, res_info_reg};
            inf.C_in_valid <= !(|err_reg);
            inf.C_r_wb <= 0;  // 1 for Read, 0 for Write
        end
        else if(c_state == READ_2) begin
            inf.C_addr <= man_id;
            inf.C_data_w <= 0;
            inf.C_in_valid <= 1;
            inf.C_r_wb <= 1;  // 1 for Read, 0 for Write
        end
        else if(c_state == WRITE_2) begin
            inf.C_addr <= man_id;
            inf.C_data_w <= (man_id == ctm_info.res_ID)? {man_info_reg_2, res_info_reg} : {man_info_reg_2, res_info_reg_2};
            inf.C_in_valid <= 1;
            inf.C_r_wb <= 0;  // 1 for Read, 0 for Write
        end
        else begin
            inf.C_addr <= 0;
            inf.C_data_w <= 0;
            inf.C_in_valid <= 0;
            inf.C_r_wb <= 0;  // 1 for Read, 0 for Write
        end
    end
end

// Output
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        inf.out_valid <= 0;
        inf.out_info <= 0;
        inf.complete <= 0;
        inf.err_msg <= 0;
    end
    else begin
        // Take    : {Delivery man info, Restaurant info} 
        // Deliver : {Delivery man info,32'd0} 
        // Order   : {32'd0,Restaurant info} 
        // Cancel  : {Delivery man info, 32'd0} 
        inf.out_valid <= (c_state == OUTPUT);
        if(c_state == OUTPUT) begin
            if(action == Take) begin
                inf.out_info <= {man_info_reg_2, res_info_reg};
                if(err_reg[0]) inf.err_msg <= D_man_busy;
                else if(err_reg[1]) inf.err_msg <= No_Food;
            end
            if(action == Deliver) begin
                inf.out_info <= {man_info_reg, 32'd0};
                if(|err_reg) inf.err_msg <= No_customers;
            end
            if(action == Order) begin
                inf.out_info <= {32'd0, res_info_reg};
                if(|err_reg) inf.err_msg <= Res_busy;
            end
            if(action == Cancel) begin
                inf.out_info <= {man_info_reg, 32'd0};
                if(err_reg[0]) inf.err_msg <= Wrong_cancel;
                else if(err_reg[1]) inf.err_msg <= Wrong_res_ID;
                else if(err_reg[2]) inf.err_msg <= Wrong_food_ID;
            end
            if(|err_reg) inf.out_info <= 0;
            inf.complete <= !(|err_reg);
        end
        else begin
            inf.out_info <= 0;
            inf.complete <= 0;
            inf.err_msg <= 0;
        end 
    end
end

//===========================================================================
// FSM
//===========================================================================
always_comb begin
    case (c_state)
        INPUT: begin
            // Take    : Delivery man ID, Customer info, (Delivery man ID, … if needed) 
            // Deliver : Delivery man ID 
            // Order   : Restaurant ID, {Food ID, servings of FOOD#}, (Restaurant ID, …if needed) 
            // Cancel  : Restaurant ID, {Food ID,4’d0}, Delivery man ID 
            if(action == Take && inf.cus_valid)         n_state = READ;
            else if(action == Deliver && inf.id_valid)  n_state = READ;
            else if(action == Order && inf.food_valid)  n_state = READ;
            else if(action == Cancel && inf.id_valid)   n_state = READ;
            else n_state = INPUT;
        end
        READ:    n_state = WAIT;
        WAIT: begin
            if(inf.C_out_valid) begin
                if(action == Take)          n_state = READ_2;
                else if(action == Deliver)  n_state = DELIVER;
                else if(action == Order)    n_state = IDLE;
                else                        n_state = IDLE;
            end
            else  n_state = WAIT;
        end
        READ_2:   n_state = WAIT_2;
        WAIT_2:   n_state = (inf.C_out_valid)? IDLE : WAIT_2;
        TAKE:     n_state = WRITE;
        DELIVER:  n_state = WRITE;
        ORDER:    n_state = WRITE;
        CANCEL:   n_state = WRITE;
        WRITE:    n_state = (|err_reg)? OUTPUT : WAIT_W;
        WAIT_W:   n_state = (!inf.C_out_valid)? WAIT_W : (action == Take)? WRITE_2 : OUTPUT;
        WRITE_2:  n_state = WAIT_W_2;
        WAIT_W_2: n_state = (inf.C_out_valid)? OUTPUT : WAIT_W_2;
        OUTPUT:   n_state = INPUT;
        IDLE:     n_state = (action == Take)? TAKE : (action == Order)? IDLE_2 : CANCEL;
        IDLE_2:   n_state = ORDER;
        default:  n_state = INPUT; 
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) c_state <= INPUT;
    else c_state <= n_state;
end

endmodule