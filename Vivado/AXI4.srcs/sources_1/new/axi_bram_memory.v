`timescale 1ns/1ps
module axi_bram_memory #(
    parameter DATA_WIDTH = 32,
    parameter MEMORY_DEPTH = 256
)(
    input  wire                            clk,
    input  wire [$clog2(MEMORY_DEPTH)-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0]           wr_data,
    input  wire [(DATA_WIDTH/8)-1:0]       wr_strb,
    input  wire                            wr_en,
    input  wire [$clog2(MEMORY_DEPTH)-1:0] rd_addr,
    output reg  [DATA_WIDTH-1:0]           rd_data
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram [0:MEMORY_DEPTH-1];

    always @(posedge clk) begin
        if (wr_en) begin
            if (wr_strb[0]) ram[wr_addr][7:0]   <= wr_data[7:0];
            if (wr_strb[1]) ram[wr_addr][15:8]  <= wr_data[15:8];
            if (wr_strb[2]) ram[wr_addr][23:16] <= wr_data[23:16];
            if (wr_strb[3]) ram[wr_addr][31:24] <= wr_data[31:24];
        end
        rd_data <= ram[rd_addr];
    end
endmodule
