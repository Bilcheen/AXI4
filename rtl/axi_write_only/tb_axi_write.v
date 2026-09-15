`timescale 1ns/1ps

module tb_axi_write;

    localparam ID_WIDTH   = 4;
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

    reg [7:0] debug_memory_addr;
    wire [DATA_WIDTH-1:0] debug_memory_data;

    integer errors;

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
        .s_axi_buser(s_axi_buser),

        .debug_memory_addr(debug_memory_addr),
        .debug_memory_data(debug_memory_data)
    );

    always #5 clk = ~clk;

    task send_aw;
        input [31:0] address;
        input [7:0] burst_length;
        input [ID_WIDTH-1:0] transaction_id;
        input [USER_WIDTH-1:0] user_value;

        begin
            @(negedge clk);

            s_axi_awaddr  = address;
            s_axi_awsize  = 3'd2;
            s_axi_awburst = 2'b01;
            s_axi_awlen   = burst_length;
            s_axi_awid    = transaction_id;
            s_axi_awuser  = user_value;
            s_axi_awvalid = 1'b1;

            while (!s_axi_awready)
                @(posedge clk);

            @(posedge clk);
            #1;

            @(negedge clk);
            s_axi_awvalid = 1'b0;
        end
    endtask

    task send_w;
        input [DATA_WIDTH-1:0] data_value;
        input [(DATA_WIDTH/8)-1:0] strobe_value;
        input last_value;

        begin
            @(negedge clk);

            s_axi_wdata  = data_value;
            s_axi_wstrb  = strobe_value;
            s_axi_wlast  = last_value;
            s_axi_wvalid = 1'b1;

            while (!s_axi_wready)
                @(posedge clk);

            @(posedge clk);
            #1;

            @(negedge clk);
            s_axi_wvalid = 1'b0;
            s_axi_wlast  = 1'b0;
        end
    endtask

    task wait_for_b;
        input [1:0] expected_resp;
        input [ID_WIDTH-1:0] expected_id;
        input [USER_WIDTH-1:0] expected_user;

        begin
            while (!s_axi_bwvalid)
                @(posedge clk);

            #1;

            if (s_axi_bresp !== expected_resp) begin
                $display("ERROR: BRESP mismatch, expected %b, got %b",
                         expected_resp, s_axi_bresp);
                errors = errors + 1;
            end

            if (s_axi_bid !== expected_id) begin
                $display("ERROR: BID mismatch, expected %h, got %h",
                         expected_id, s_axi_bid);
                errors = errors + 1;
            end

            if (s_axi_buser !== expected_user) begin
                $display("ERROR: BUSER mismatch");
                errors = errors + 1;
            end

            if (s_axi_bwvalid !== 1'b1) begin
                $display("ERROR: BVALID should remain high before BREADY");
                errors = errors + 1;
            end
        end
    endtask

    task accept_b;
        begin
            @(negedge clk);
            s_axi_bwready = 1'b1;

            @(posedge clk);
            #1;

            if (s_axi_bwvalid !== 1'b0) begin
                $display("ERROR: BVALID should be cleared after B handshake");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("axi_write.vcd");
        $dumpvars(0, tb_axi_write);

        clk = 1'b0;
        rst = 1'b1;
        errors = 0;

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

        s_axi_bwready = 1'b0;

        //==================================================
        // Test 1: Reset
        //==================================================
        repeat (2) @(posedge clk);
        #1;
        rst = 1'b0;

        #1;

        if (s_axi_awready !== 1'b1) begin
            $display("ERROR: AWREADY should be high after reset");
            errors = errors + 1;
        end

        if (s_axi_bwvalid !== 1'b0) begin
            $display("ERROR: BVALID should be low after reset");
            errors = errors + 1;
        end

        //==================================================
        // Test 2: Single-beat full write
        // Address 0x40 -> memory[16]
        //==================================================
        send_aw(
            32'h0000_0040,
            8'd0,
            4'hA,
            1'b1
        );

        if (s_axi_awready !== 1'b0) begin
            $display("ERROR: AWREADY should be low while write is active");
            errors = errors + 1;
        end

        if (s_axi_wready !== 1'b1) begin
            $display("ERROR: WREADY should be high after AW handshake");
            errors = errors + 1;
        end

        send_w(
            32'hAABB_CCDD,
            4'b1111,
            1'b1
        );

        debug_memory_addr = 8'd16;
        #1;

        if (debug_memory_data !== 32'hAABB_CCDD) begin
            $display("ERROR: full write data mismatch");
            $display("       expected AABBCCDD, got %h", debug_memory_data);
            errors = errors + 1;
        end

        // BREADY is low, so BVALID must be held
        wait_for_b(2'b00, 4'hA, 1'b1);

        accept_b;

        if (s_axi_awready !== 1'b1) begin
            $display("ERROR: AWREADY should be high after B handshake");
            errors = errors + 1;
        end

        //==================================================
        // Test 3: Partial WSTRB
        // Original: 0x11223344
        // WDATA:   0xAABBCCDD
        // WSTRB:   0101
        // Result:  0x11BB33DD
        // Address 0x44 -> memory[17]
        //==================================================
        send_aw(
            32'h0000_0044,
            8'd0,
            4'h9,
            1'b0
        );

        send_w(
            32'h1122_3344,
            4'b1111,
            1'b1
        );

        wait_for_b(2'b00, 4'h9, 1'b0);
        accept_b;

        send_aw(
            32'h0000_0044,
            8'd0,
            4'hB,
            1'b0
        );

        send_w(
            32'hAABB_CCDD,
            4'b0101,
            1'b1
        );

        debug_memory_addr = 8'd17;
        #1;

        if (debug_memory_data !== 32'h11BB_33DD) begin
            $display("ERROR: partial WSTRB write mismatch");
            $display("       expected 11BB33DD, got %h", debug_memory_data);
            errors = errors + 1;
        end

        wait_for_b(2'b00, 4'hB, 1'b0);
        accept_b;

        //==================================================
        // Test 4: WLAST = 0 followed by WLAST = 1
        // Address 0x48 -> memory[18]
        //==================================================
        send_aw(
            32'h0000_0048,
            8'd1,
            4'hC,
            1'b1
        );

        send_w(
            32'h1111_2222,
            4'b1111,
            1'b0
        );

        if (s_axi_bwvalid !== 1'b0) begin
            $display("ERROR: BVALID should remain low before WLAST");
            errors = errors + 1;
        end

        if (s_axi_wready !== 1'b1) begin
            $display("ERROR: WREADY should remain high before WLAST");
            errors = errors + 1;
        end

        send_w(
            32'h3333_4444,
            4'b1111,
            1'b1
        );

        debug_memory_addr = 8'd18;
        #1;

        if (debug_memory_data !== 32'h3333_4444) begin
            $display("ERROR: second write data mismatch");
            errors = errors + 1;
        end

        wait_for_b(2'b00, 4'hC, 1'b1);
        accept_b;

        //==================================================
        // Final result
        //==================================================
        if (errors == 0) begin
            $display("PASS: AXI write testbench passed");
        end else begin
            $display("FAIL: %0d error(s)", errors);
        end

        #10;
        $finish;
    end

endmodule