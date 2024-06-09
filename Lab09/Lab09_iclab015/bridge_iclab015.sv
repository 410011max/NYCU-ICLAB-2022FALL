module bridge(input clk, INF.bridge_inf inf);
import usertype::*;

//================================================================
// logic 
//================================================================
typedef enum logic  [2:0] { IDLE    = 0,
                            A_READ  = 1,
                            READ    = 2,
                            A_WRITE = 3,
                            WRITE   = 4,
                            WAIT    = 5,
                            OUTPUT  = 6
                            } B_State;

B_State c_state, n_state;
logic [8:0] addr;
logic [63:0] data;

D_man_Info C_data_man_r, C_data_man_w;
res_info C_data_res_r, C_data_res_w;

//================================================================
// design 
//================================================================
// Read
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        inf.AR_VALID <= 0;
        inf.AR_ADDR <= 0;
        inf.R_READY <= 0;
    end
    else begin
        inf.AR_VALID <= (inf.AR_READY)? 0 : (c_state == A_READ);
        inf.AR_ADDR <= (inf.C_in_valid)? 17'h10000 + 8*inf.C_addr : inf.AR_ADDR;
        inf.R_READY <= (inf.R_VALID)? 0 : (c_state == READ);
    end
end

// Write
assign C_data_man_w = {inf.C_data_w[39:32], inf.C_data_w[47:40], inf.C_data_w[55:48], inf.C_data_w[63:56]};
assign C_data_res_w = {inf.C_data_w[7:0], inf.C_data_w[15:8], inf.C_data_w[23:16], inf.C_data_w[31:24]};
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        inf.AW_VALID <= 0;
        inf.AW_ADDR <= 0;
        inf.W_VALID <= 0;
        inf.W_DATA <= 0;
    end
    else begin
        inf.AW_VALID <= (inf.AW_READY)? 0 : (c_state == A_WRITE);
        inf.AW_ADDR <= (inf.C_in_valid)? 17'h10000 + 8*inf.C_addr : inf.AW_ADDR;
        inf.W_VALID <= (inf.W_READY)? 0 : (c_state == WRITE);
        inf.W_DATA <= (inf.C_in_valid)? {C_data_man_w, C_data_res_w} : inf.W_DATA;
    end
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.B_READY = 0;
    else inf.B_READY = 1;
end


// Output
assign C_data_man_r = {inf.R_DATA[39:32], inf.R_DATA[47:40], inf.R_DATA[55:48], inf.R_DATA[63:56]};
assign C_data_res_r = {inf.R_DATA[7:0], inf.R_DATA[15:8], inf.R_DATA[23:16], inf.R_DATA[31:24]};
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) begin
        inf.C_out_valid <= 0;
        inf.C_data_r <= 0;
    end
    else begin
        inf.C_out_valid <= (c_state == OUTPUT);
        inf.C_data_r <= (inf.R_VALID)? {C_data_man_r, C_data_res_r} : inf.C_data_r;
    end
end

//================================================================
//   FSM
//================================================================
// Next state logic
always_comb begin
    case (c_state)
        IDLE: begin
            if (inf.C_in_valid && inf.C_r_wb)
                n_state = A_READ;
            else if (inf.C_in_valid && !inf.C_r_wb)
                n_state = A_WRITE;
            else                    
                n_state = c_state;
        end
        A_READ:  n_state = (inf.AR_READY)? READ : A_READ;
        READ:    n_state = (inf.R_VALID)? OUTPUT : READ;
        A_WRITE: n_state = (inf.AW_READY)? WRITE : A_WRITE;
        WRITE:   n_state = (inf.W_READY)? WAIT : WRITE;
        WAIT:    n_state = (inf.B_VALID)? OUTPUT : WAIT;
        OUTPUT:  n_state = IDLE;
        default: n_state = IDLE;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) c_state <= IDLE;
    else c_state <= n_state;
end

endmodule