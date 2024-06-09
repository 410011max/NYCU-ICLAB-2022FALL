module HD(
           code_word1,
           code_word2,
           out_n
       );
input [6:0] code_word1, code_word2;
output reg signed [5:0] out_n;

wire signed [3:0] out_1, out_2;
wire err_1, err_2;

haming_code h1(code_word1, out_1, err_1);
haming_code h2(code_word2, out_2, err_2);

always @(*) begin
    case ({err_1, err_2})
        2'b00:
            out_n = 2*out_1 + out_2;
        2'b01:
            out_n = 2*out_1 - out_2;
        2'b10:
            out_n = out_1 - 2*out_2;
        2'b11:
            out_n = out_1 + 2*out_2;
    endcase
end

endmodule


    module haming_code(code_word, out, err);
input [6:0] code_word;
output reg[3:0] out;
output reg err;

reg p1, p2, p3;
reg x1, x2, x3, x4;
reg c1, c2, c3;

always @(*) begin
    p1 = code_word[6];
    p2 = code_word[5];
    p3 = code_word[4];
    x1 = code_word[3];
    x2 = code_word[2];
    x3 = code_word[1];
    x4 = code_word[0];
    c1 = p1^x1^x2^x3;
    c2 = p2^x1^x2^x4;
    c3 = p3^x1^x3^x4;

    case ({c1, c2, c3})
        3'b111: begin
            out = {~x1, x2, x3, x4};
            err = x1;
        end
        3'b110: begin
            out = {x1, ~x2, x3, x4};
            err = x2;
        end
        3'b101: begin
            out = {x1, x2, ~x3, x4};
            err = x3;
        end
        3'b011: begin
            out = {x1, x2, x3, ~x4};
            err = x4;
        end
        3'b100: begin
            out = {x1, x2, x3, x4};
            err = p1;
        end
        3'b010: begin
            out = {x1, x2, x3, x4};
            err = p2;
        end
        default: begin
            out = {x1, x2, x3, x4};
            err = p3;
        end
    endcase
end
endmodule
