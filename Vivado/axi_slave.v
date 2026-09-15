`timescale 1ns/1ps

module axi_slave #(
    parameter ADDR_WIDTH = 32, parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 4, parameter USER_WIDTH = 1,
    parameter MEMORY_DEPTH = 256
)(
    input wire clk, 
    input wire aresetn,
    input wire [ID_WIDTH-1:0] s_axi_awid, 
    input wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [7:0] s_axi_awlen, 
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst, 
    input wire [USER_WIDTH-1:0] s_axi_awuser,
    input wire s_axi_awvalid, 
    output wire s_axi_awready,
    input wire [DATA_WIDTH-1:0] s_axi_wdata, 
    input wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input wire s_axi_wlast, 
    input wire [USER_WIDTH-1:0] s_axi_wuser,
    input wire s_axi_wvalid, 
    output wire s_axi_wready,
    output wire [ID_WIDTH-1:0] s_axi_bid, 
    output wire [1:0] s_axi_bresp,
    output wire [USER_WIDTH-1:0] s_axi_buser, 
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    input wire [ID_WIDTH-1:0] s_axi_arid, 
    input wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input wire [7:0] s_axi_arlen, 
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst, 
    input wire [USER_WIDTH-1:0] s_axi_aruser,
    input wire s_axi_arvalid, 
    output wire s_axi_arready,
    output wire [ID_WIDTH-1:0] s_axi_rid, 
    output wire [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0] s_axi_rresp, 
    output wire s_axi_rlast,
    output wire [USER_WIDTH-1:0] s_axi_ruser, 
    output wire s_axi_rvalid,
    input wire s_axi_rready,
    output wire [$clog2(MEMORY_DEPTH)-1:0] mem_wr_addr,
    output wire [DATA_WIDTH-1:0] mem_wr_data,
    output wire [(DATA_WIDTH/8)-1:0] mem_wr_strb, 
    output wire mem_wr_en,
    output wire [$clog2(MEMORY_DEPTH)-1:0] mem_rd_addr,
    input wire [DATA_WIDTH-1:0] mem_rd_data
);
    wire rst = ~aresetn;
    axi_write_slave #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH), .MEMORY_DEPTH(MEMORY_DEPTH)) u_write (
        .clk(clk), .rst(rst), .s_axi_awid(s_axi_awid), .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen), .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst), .s_axi_awuser(s_axi_awuser), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready), .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast), .s_axi_wuser(s_axi_wuser), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready), .s_axi_bid(s_axi_bid), .s_axi_bresp(s_axi_bresp), .s_axi_buser(s_axi_buser), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready), .mem_wr_addr(mem_wr_addr), .mem_wr_data(mem_wr_data), .mem_wr_strb(mem_wr_strb), .mem_wr_en(mem_wr_en));
    axi_read_slave #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH), .MEMORY_DEPTH(MEMORY_DEPTH)) u_read (
        .clk(clk), .rst(rst), .s_axi_arid(s_axi_arid), .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen), .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst), .s_axi_aruser(s_axi_aruser), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready), .s_axi_rid(s_axi_rid), .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rlast(s_axi_rlast), .s_axi_ruser(s_axi_ruser), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready), .mem_rd_addr(mem_rd_addr), .mem_rd_data(mem_rd_data));
endmodule