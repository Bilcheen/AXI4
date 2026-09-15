// write axi read case
`timescale 1ns/1ps
module axi #(
    parameter ID_WIDTH = 4,
    parameter DATA_WIDTH = 32,
    parameter USER_WIDTH = 1
)(
    input wire clk,
    input wire rst,
    //=========================
    //AXI4 Read Address(AR) Channel
    //=========================
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    input wire [31:0] s_axi_araddr,
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire [3:0] s_axi_arcache,
    input wire [2:0] s_axi_arprot,
    input wire [ID_WIDTH-1:0] s_axi_arid,
    //input wire [3:0] s_axi_arlen,    //AXI3
    input wire [7:0] s_axi_arlen,
    input wire s_axi_arlock,
    //input wire [1:0] s_axi_arlock,   //AXI3
    input wire [3:0] s_axi_arqos,
    input wire [3:0] s_axi_arregion,
    input wire [USER_WIDTH-1:0] s_axi_aruser,

    //=========================
    //AXI4 Read Data(R) Channel
    //=========================
    output reg s_axi_rvalid,
    input wire s_axi_rready,
    output reg s_axi_rlast,
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg [ID_WIDTH-1:0] s_axi_rid,
    output reg [USER_WIDTH-1:0] s_axi_ruser,

    //=========================
    //Debug Memory Interface
    //=========================
    output wire [DATA_WIDTH-1:0] debug_memory_data,
    input wire [7:0] debug_memory_addr
);

localparam integer MEMORY_DEPTH = 256;

reg [DATA_WIDTH-1:0] memory [0:MEMORY_DEPTH-1];

reg ar_active;
reg [31:0] araddr_reg;
reg [2:0] arsize_reg;
reg [1:0] arburst_reg;
reg [7:0] arlen_reg;
reg [ID_WIDTH-1:0] arid_reg;
reg [USER_WIDTH-1:0] aruser_reg;

//預先填入測試資料 for read tb
integer idx;
initial begin
    for (idx = 0; idx < MEMORY_DEPTH; idx = idx + 1) begin
        memory[idx] = 32'h0;
    end
    memory[8'd16] = 32'hAABB_CCDD; // 0x40 對應的 Word
    memory[8'd17] = 32'h11BB_33DD; // 0x44 對應的 Word
    memory[8'd18] = 32'h1111_2222; // 0x48 對應的 Word
    memory[8'd19] = 32'h3333_4444; // 0x4C 對應的 Word
end

assign s_axi_arready = !ar_active && !s_axi_rvalid;
assign debug_memory_data = memory[debug_memory_addr];

// AR & R Channel
always @(posedge clk) begin
    if (rst) begin
        ar_active <= 1'b0;
        araddr_reg <= 32'b0;
        arsize_reg <= 3'b0;
        arburst_reg <= 2'b0;
        arlen_reg <= 8'b0;
        arid_reg <= {ID_WIDTH{1'b0}};
        aruser_reg <= {USER_WIDTH{1'b0}};

        s_axi_rvalid <= 1'b0;
        s_axi_rdata <= {DATA_WIDTH{1'b0}};
        s_axi_rresp <= 2'b00;
        s_axi_rid <= {ID_WIDTH{1'b0}};
        s_axi_rlast <= 1'b0;
        s_axi_ruser <= {USER_WIDTH{1'b0}};
    end else begin

        // AR handshake
        if (s_axi_arvalid && s_axi_arready) begin
            ar_active <= 1'b1;
            araddr_reg <= s_axi_araddr;
            arsize_reg <= s_axi_arsize;
            arburst_reg <= s_axi_arburst;
            arlen_reg <= s_axi_arlen;
            arid_reg <= s_axi_arid;
            aruser_reg <= s_axi_aruser;

            s_axi_rvalid <= 1'b1;
            s_axi_rdata <= memory[s_axi_araddr[9:2]];
            s_axi_rresp <= 2'b00; //OKAY
            s_axi_rid <= s_axi_arid;
            s_axi_rlast <= 1'b1;
            s_axi_ruser <= s_axi_aruser;
        end

        // R handshake
        if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0; 
            s_axi_rlast <= 1'b0;
            ar_active <= 1'b0;
        end

    end
end

endmodule



