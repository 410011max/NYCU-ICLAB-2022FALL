
`ifdef RTL
    `define CYCLE_TIME 10.0
`endif
`ifdef GATE
    `define CYCLE_TIME 10.0
`endif

module PATTERN(
           // Output Signals
           clk,
           rst_n,
           in_valid,
           guy,
           in0,
           in1,
           in2,
           in3,
           in4,
           in5,
           in6,
           in7,
           // Input Siganls
           out_valid,
           out
       );

//================================================================
//   Input and Output Declaration
//================================================================
output reg       clk, rst_n;
output reg       in_valid;
output reg [2:0] guy;
output wire [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
input            out_valid;
input      [1:0] out;

//================================================================
// Parameters & Integer Declaration
//================================================================
real CYCLE = `CYCLE_TIME;
parameter PAT_NUM = 300;
parameter PAT_LEN = 64;
integer SEED = 123;
integer i, j;
integer patcount = 1, total_latency, wait_val_time;
integer out_cycle, guy_pos, guy_height, jump, obs_pos, obs_type, pre_obs_pos, need_cycle;

//================================================================
// Wire & Registers Declaration
//================================================================
reg [1:0] in[0:7];
reg [1:0] in_reg[0:7][0:63];

//================================================================
// Clock
//================================================================
initial begin
    clk = 0;
end
always #(CYCLE/2.0) clk = ~clk;

//================================================================
// Input Wire
//================================================================
assign in0 = in[0];
assign in1 = in[1];
assign in2 = in[2];
assign in3 = in[3];
assign in4 = in[4];
assign in5 = in[5];
assign in6 = in[6];
assign in7 = in[7];

//================================================================
// initial
//================================================================
initial begin

    rst_n = 1'b1;
    in_valid = 1'd0;
    force clk = 0;

    total_latency = 0;

    SPEC3_reset_signal_task;

    for(patcount=1; patcount <= PAT_NUM; patcount = patcount+1) begin
        input_task;
        SPEC6_wait_out_valid;
        SPEC8_check_ans;
    end
    YOU_PASS_task;
end

always @(negedge clk) begin
    SPEC4_low_out_valid_reset_out;
    SPEC5_in_valid_high_dont_out_valid;
    SPEC7_out_64cycle;
end


//================================================================
// task
//================================================================
task input_task;
    begin
        // Inputs start from second negtive edge after the begining of clock
        if(patcount=='d1)
            repeat(2)@(negedge clk);

        // Set in_valid and input the data
        in_valid = 1'b1;

        // First cycle
        guy = $urandom % 8;
        guy_pos = guy;
        pre_obs_pos = guy_pos;

        for(i=0;i<8;i=i+1) begin
            in[i] = 'd0;
            in_reg[i][0] = 'd0;
        end
        @(negedge clk);
        guy = 3'dx;

        for(i=1; i < PAT_LEN; i = i+1) begin
            //+++++++++++++++++++++++++++++++++++++++++++++++++++
            // Generate Input here
            obs_pos = $urandom % 8;
            obs_type = $urandom % 2 + 1;
            need_cycle = (pre_obs_pos < obs_pos) ? obs_pos - pre_obs_pos : pre_obs_pos - obs_pos;
            need_cycle = (obs_type == 2'b01) ? need_cycle : need_cycle -1;
            while(need_cycle > 0 && i < PAT_LEN) begin // flat ground
                for(j=0;j<8;j=j+1) begin
                    in[j] = 'd0;
                    in_reg[j][i] = 'd0;
                end
                i = i + 1;
                need_cycle = need_cycle - 1;
                @(negedge clk);
            end
            if(i < PAT_LEN) begin
                for(j=0;j<8;j=j+1) begin // obstacle
                    in[j] = 'd11;
                    in_reg[j][i] = 'd11;
                end
                in[obs_pos] = obs_type;
                in_reg[obs_pos][i] = obs_type;
                i = i + 1;
                @(negedge clk);
            end
            if(i < PAT_LEN) begin // next must be flat ground
                for(j=0;j<8;j=j+1) begin
                    in[j] = 'd0;
                    in_reg[j][i] = 'd0;
                end
                @(negedge clk);
            end
            pre_obs_pos = obs_pos;
            //+++++++++++++++++++++++++++++++++++++++++++++++++++
        end

        // Disable input
        in_valid = 1'b0;
        for(i=0;i<8;i=i+1)
            in[i] = 'dx;
    end
endtask

task SPEC3_reset_signal_task;
    begin
        #(5.0);
        rst_n=0;
        #(5.0);
        if((out_valid !== 0)||(out !== 0)) begin
            $display("SPEC 3 IS FAIL!");
            $display("**************************************************************");
            $display("*   Output signal should be 0 after initial RESET at %4t     *",$time);
            $display("**************************************************************");
            $finish;
        end
        #(5.0);
        rst_n=1;
        #(5.0);
        release clk;
    end
endtask

task SPEC4_low_out_valid_reset_out;
    begin
        if((out_valid === 0) && (out !== 0)) begin
            $display("SPEC 4 IS FAIL!");
            $display("*******************************************************************");
            $display("*   The out should be reset when your out_valid is low at %4t     *",$time);
            $display("*******************************************************************");
            $finish;
        end
    end
endtask

task SPEC5_in_valid_high_dont_out_valid;
    begin
        if((in_valid === 1) && (out_valid === 1)) begin
            $display("SPEC 5 IS FAIL!");
            $display("***********************************************************************");
            $display("*   The out_valid should not be high when in_valid is high at %4t     *",$time);
            $display("***********************************************************************");
            $finish;
        end
    end
endtask

task SPEC6_wait_out_valid;
    begin
        wait_val_time = 0;
        while(out_valid !== 1) begin
            wait_val_time = wait_val_time + 1;
            if(wait_val_time == 3000) begin
                $display("SPEC 6 IS FAIL!");
                $display("***************************************************************");
                $display("*         The execution latency are over 3000 cycles.         *");
                $display("***************************************************************");
                $finish;
            end
            @(negedge clk);
        end
        total_latency = total_latency + wait_val_time;
    end
endtask

task SPEC7_out_64cycle;
    begin
        // Output no more that 64 cycle
        if(out_cycle > 64) begin
            $display("SPEC 7 IS FAIL!");
            $display ("-----------------------------------");
            $display (" Out_valid is more than 63 cycles. ");
            $display ("-----------------------------------");
            $finish;
        end
        else if(out_cycle > 1 && out_cycle < 63 && out_valid === 1'd0) begin
            $display("SPEC 7 IS FAIL!");
            $display ("-----------------------------------");
            $display (" Out_valid is less than 63 cycles. ");
            $display ("-----------------------------------");
            $finish;
        end
    end
endtask

task SPEC8_check_ans;
    begin
        // Check the answer
        out_cycle = 1;
        guy_height = 0;
        jump = 0;
        while(out_valid === 1) begin
            if(out === 2'd1) // right
                guy_pos = guy_pos + 1;
            else if(out === 2'd2) // left
                guy_pos = guy_pos - 1;
            else if(out === 2'd3) begin // jump
                guy_height = guy_height + 1;
            end
            if(out !== 2'd3)
                guy_height = (guy_height > 0) ? guy_height - 1 : 0;

            // SPEC 8-3: If the guy jumps to the same height, out must be 2'b00 for 1 cycle
            if(jump == 1 && out !== 2'd0) begin
                $display("SPEC 8-3 IS FAIL!");
                $display("***********************************************************************************");
                $display("*  SPEC 8-3: If the guy jumps to the same height, out must be 2'b00 for 1 cycle.  *");
                $display("*  Your output : %d  at %8t                          		      ",out,$time); //show output
                $display("***********************************************************************************");
                $finish;
            end

            // SPEC 8-2: If the guy jumps from high to low place, out must be 2'b00 for 2 cycles
            if(jump >= 2 && out !== 2'd0) begin
                $display("SPEC 8-2 IS FAIL!");
                $display("*****************************************************************************************");
                $display("*  SPEC 8-2: If the guy jumps from high to low place, out must be 2'b00 for 2 cycles.  *");
                $display("*  Your output : %d  at %8t                          		      ",out,$time); //show output
                $display("****************************************************************************************");
                $finish;
            end

            // SPEC 8-1: The correct output means that the guy has to avoid all obstacles and cannot leave the platform
            if(guy_height < 2 && in_reg[guy_pos][out_cycle][guy_height] == 1)  begin
                $display("SPEC 8-1 IS FAIL!");
                $display("**************************************************");
                $display("*  SPEC 8-1: The guy has to avoid all obstacles. *");
                $display("*  Your output : %d  at %8t                          		      ",out,$time); //show output
                $display("**************************************************");
                $finish;
            end
            else if(guy_pos == -1  || guy_pos == 8 ) begin
                $display("SPEC 8-1 IS FAIL!");
                $display("*************************************************");
                $display("*  SPEC 8-1: The guy cannot leave the platform. *");
                $display("*  Your output : %d  at %8t                          		      ",out,$time); //show output
                $display("*************************************************");
                $finish;
            end

            if(jump == 1 || jump == 3)
                jump = 0;
            else if(jump == 2)
                jump = 3;

            if(out == 2'd3) begin
                if(guy_height == 1) begin
                    if(in_reg[guy_pos][out_cycle] !== 2'b01)
                        jump = 1;
                    else
                        jump = 0;
                end
                else if(guy_height == 2) begin
                    if(in_reg[guy_pos][out_cycle+1] === 2'b00)
                        jump = 2;
                    else
                        jump = 1;
                end
            end
            @(negedge clk);
            out_cycle = out_cycle + 1;
        end

        $display("\033[0;34mPASS PATTERN NO.%4d,\033[m \033[0;32mexecution cycle : %3d\033[m",patcount ,wait_val_time);
        repeat(2)@(negedge clk);
    end
endtask


task YOU_PASS_task;
    begin
        $display ("--------------------------------------------------------------------");
        $display ("          ~(￣▽￣)~(＿△＿)~(￣▽￣)~(＿△＿)~(￣▽￣)~            ");
        $display ("                         Congratulations!                           ");
        $display ("                  You have passed all patterns!                     ");
        $display ("--------------------------------------------------------------------");

        #(500);
        $finish;
    end
endtask


endmodule
