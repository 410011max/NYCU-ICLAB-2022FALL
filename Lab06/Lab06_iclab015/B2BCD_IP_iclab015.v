//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP.v
//   Module Name : B2BCD_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module B2BCD_IP #(parameter WIDTH = 4, parameter DIGIT = 2) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Declaration
// ===============================================================
input  [WIDTH-1:0]   Binary_code;
output wire [DIGIT*4-1:0] BCD_code;
reg [DIGIT*4-1:0] transfer_state[0:WIDTH];  // [BCD code of each number][transfer state (shift + add 3)]
reg [DIGIT*4-1:0] temp[0:WIDTH];

// ===============================================================
// Soft IP DESIGN
// ===============================================================
genvar i, j;
generate
    for(i=0;i<WIDTH;i=i+1) begin  // transfer state
        for(j=1;j<=DIGIT;j=j+1) begin  // each number
            always @(*) begin  // add 3
                if(transfer_state[i][j*4-1:j*4-4] > 'd4) temp[i][j*4-1:j*4-4] = transfer_state[i][j*4-1:j*4-4] + 'd3;
                else temp[i][j*4-1:j*4-4] = transfer_state[i][j*4-1:j*4-4];
            end
        end
        always @(*) begin
            if(i == 0) transfer_state[i+1] = Binary_code[WIDTH-1];
            else transfer_state[i+1] = {temp[i][DIGIT*4-2:0], Binary_code[WIDTH - 1 - i]};  // shift
        end
    end
endgenerate

assign BCD_code = transfer_state[WIDTH];

endmodule