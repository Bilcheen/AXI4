module test (in1, in2, clock, sum, cout);
input [31:0] in1, in2;
input clock;
output [31:0] sum;
output cout;

reg [31:0] a, b;
reg [31:0] sum;
reg cout;

always @(posedge clock) begin
        a = in1;
        b = in2;
        {cout, sum} = a + b;
    end

endmodule