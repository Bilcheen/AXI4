`timescale 1ns / 1ps
module test_tb;
reg [31:0] in1, in2;
reg clock;
wire [31:0] sum;
wire cout;

test uut (.in1(in1), .in2(in2), .clock(clock), .sum(sum), .cout(cout));

always #5 clock = ~clock;

initial begin
        clock = 0;
        in1 = 10; in2 = 20;
        @(negedge clock);
        in1 = 15; in2 = 25;
        @(negedge clock);
        #100
        $finish;
    end

initial begin
        $dumpfile("test.vcd");
        $dumpvars(0, test_tb);
    end

endmodule