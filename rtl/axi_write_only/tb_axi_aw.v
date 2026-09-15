`timescale 1ns/1ps

module tb_axi_aw;

    localparam ID_WIDTH = 4;
    localparam DATA_WIDTH = 32;
    localparam USER_WIDTH = 1;

    reg clk;
    reg rst;

    reg s_axi_awvalid;
    wire s_axi_awready;
    reg [31:0] s_axi_awaddr;
    reg [2:0] s_axi_awsize;
    reg [1:0] s_axi_awburst;
    reg [3:0] s_axi_awcache;
    reg [2:0] s_axi_awprot;
    reg [ID_WIDTH-1:0] s_axi_awid;
    reg [7:0] s_axi_awlen;
    reg s_axi_awlock;
    reg [3:0] s_axi_awqos;
    reg [3:0] s_axi_awregion;
    reg [USER_WIDTH-1:0] s_axi_awuser;

    reg s_axi_wvalid;
    wire s_axi_wready;
    reg s_axi_wlast;
    reg [DATA_WIDTH-1:0] s_axi_wdata;
    reg [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg [USER_WIDTH-1:0] s_axi_wuser;

    wire s_axi_bwvalid;
    reg s_axi_bwready;
    wire [1:0] s_axi_bresp;
    wire [ID_WIDTH-1:0] s_axi_bid;
    wire [USER_WIDTH-1:0] s_axi_buser;

    axi #(
        .ID_WIDTH(ID_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),

        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awregion(s_axi_awregion),
        .s_axi_awuser(s_axi_awuser),

        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),

        .s_axi_bwvalid(s_axi_bwvalid),
        .s_axi_bwready(s_axi_bwready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bid(s_axi_bid),
        .s_axi_buser(s_axi_buser)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        s_axi_awvalid  = 1'b0;
        s_axi_awaddr   = 32'd0;
        s_axi_awsize   = 3'd0;
        s_axi_awburst  = 2'b00;
        s_axi_awcache  = 4'd0;
        s_axi_awprot   = 3'd0;
        s_axi_awid     = 4'd0;
        s_axi_awlen    = 8'd0;
        s_axi_awlock   = 1'b0;
        s_axi_awqos    = 4'd0;
        s_axi_awregion = 4'd0;
        s_axi_awuser   = 1'b0;

        s_axi_wvalid = 1'b0;
        s_axi_wlast  = 1'b0;
        s_axi_wdata  = 32'd0;
        s_axi_wstrb  = 4'd0;
        s_axi_wuser  = 1'b0;

        s_axi_bwready = 1'b1;

        repeat (2) @(posedge clk);
        rst = 1'b0;

        // 確認 reset 結束後可以接收 AW
        #1;
        if (s_axi_awready !== 1'b1) begin
            $display("ERROR: AWREADY should be 1 after reset");
            $finish;
        end

        // 準備 AW transaction
        @(negedge clk);
        s_axi_awaddr  = 32'h0000_0040;
        s_axi_awsize  = 3'd2;
        s_axi_awburst = 2'b01;
        s_axi_awlen   = 8'd0;
        s_axi_awid    = 4'hA;
        s_axi_awuser  = 1'b1;
        s_axi_awvalid = 1'b1;

        // 等待 AW handshake
        @(posedge clk);
        while (!s_axi_awready)
            @(posedge clk);

        #1;
        

        @(negedge clk);
        s_axi_awvalid = 1'b0;

        #1;
        if (s_axi_awready !== 1'b0) begin
            $display("ERROR: AWREADY should be 0 after AW handshake");
            $finish;
        end

        if (s_axi_wready !== 1'b1) begin
            $display("ERROR: WREADY should be 1 after AW handshake");
            $finish;
        end


        $display("PASS: AW channel test passed");
        $finish;
    end

endmodule