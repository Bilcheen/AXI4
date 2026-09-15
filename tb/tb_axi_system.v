`timescale 1ns/1ps

module tb_axi_system;

    localparam ADDR_WIDTH   = 32;
    localparam DATA_WIDTH   = 32;
    localparam ID_WIDTH     = 4;
    localparam USER_WIDTH   = 1;
    localparam MEMORY_DEPTH = 256;
    localparam STRB_WIDTH   = DATA_WIDTH / 8;

    reg clk;
    reg rst;

    // Master 介面信號
    reg                     start_write;
    reg  [ADDR_WIDTH-1:0]   write_addr;
    reg  [7:0]              write_len;
    reg  [ID_WIDTH-1:0]     write_id;
    reg  [USER_WIDTH-1:0]   write_user;
    reg  [DATA_WIDTH-1:0]   write_data;
    reg  [STRB_WIDTH-1:0]   write_strb;
    wire                    write_data_ready;
    reg                     write_data_valid;
    wire                    write_busy;
    wire                    write_done;
    wire [1:0]              write_resp;
    wire [ID_WIDTH-1:0]     write_resp_id;
    wire [USER_WIDTH-1:0]   write_resp_user;

    reg                     start_read;
    reg  [ADDR_WIDTH-1:0]   read_addr;
    reg  [7:0]              read_len;
    reg  [ID_WIDTH-1:0]     read_id;
    reg  [USER_WIDTH-1:0]   read_user;
    wire [DATA_WIDTH-1:0]   read_data;
    wire [STRB_WIDTH-1:0]   read_strb;
    wire                    read_data_valid;
    wire                    read_data_last;
    reg                     read_data_ready;
    wire                    read_busy;
    wire                    read_done;
    wire [1:0]              read_resp;
    wire [ID_WIDTH-1:0]     read_resp_id;
    wire [USER_WIDTH-1:0]   read_resp_user;

    // AXI 內部匯流排信號
    wire [ID_WIDTH-1:0]     axi_awid, axi_bid, axi_arid, axi_rid;
    wire [ADDR_WIDTH-1:0]   axi_awaddr, axi_araddr;
    wire [7:0]              axi_awlen, axi_arlen;
    wire [2:0]              axi_awsize, axi_arsize;
    wire [1:0]              axi_awburst, axi_arburst;
    wire [USER_WIDTH-1:0]   axi_awuser, axi_buser, axi_aruser, axi_ruser;
    wire                    axi_awvalid, axi_awready;
    wire [DATA_WIDTH-1:0]   axi_wdata, axi_rdata;
    wire [STRB_WIDTH-1:0]   axi_wstrb;
    wire                    axi_wlast, axi_rlast;
    wire                    axi_wvalid, axi_wready;
    wire [1:0]              axi_bresp, axi_rresp;
    wire                    axi_bvalid, axi_bready;
    wire                    axi_arvalid, axi_arready;
    wire                    axi_rvalid, axi_rready;

    // Slave 連接記憶體信號
    wire [$clog2(MEMORY_DEPTH)-1:0] mem_wr_addr;
    wire [DATA_WIDTH-1:0]           mem_wr_data;
    wire [STRB_WIDTH-1:0]           mem_wr_strb;
    wire                            mem_wr_en;
    wire [$clog2(MEMORY_DEPTH)-1:0] mem_rd_addr;
    reg  [DATA_WIDTH-1:0]           mem_rd_data;

    reg [DATA_WIDTH-1:0] mem_array [0:MEMORY_DEPTH-1];
    integer i, errors;

    // 模擬 SRAM 寫入與讀出行為
    always @(posedge clk) begin
        if (mem_wr_en) begin
            for (i = 0; i < STRB_WIDTH; i = i + 1) begin
                if (mem_wr_strb[i])
                    mem_array[mem_wr_addr][i*8 +: 8] <= mem_wr_data[i*8 +: 8];
            end
        end
    end

    always @(*) begin
        mem_rd_data = mem_array[mem_rd_addr];
    end

    // Master
    axi_master #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH)
    ) u_master (
        .clk(clk), .rst(rst),
        .start_write(start_write), .write_addr(write_addr), .write_len(write_len),
        .write_id(write_id), .write_user(write_user), .write_data(write_data),
        .write_strb(write_strb), .write_data_valid(write_data_valid),
        .write_data_ready(write_data_ready), .write_busy(write_busy),
        .write_done(write_done), .write_resp(write_resp),
        .write_resp_id(write_resp_id), .write_resp_user(write_resp_user),
        .m_axi_awid(axi_awid), .m_axi_awaddr(axi_awaddr), .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize), .m_axi_awburst(axi_awburst), .m_axi_awuser(axi_awuser),
        .m_axi_awvalid(axi_awvalid), .m_axi_awready(axi_awready),
        .m_axi_wdata(axi_wdata), .m_axi_wstrb(axi_wstrb), .m_axi_wlast(axi_wlast),
        .m_axi_wuser(axi_wuser), .m_axi_wvalid(axi_wvalid), .m_axi_wready(axi_wready),
        .m_axi_bid(axi_bid), .m_axi_bresp(axi_bresp), .m_axi_buser(axi_buser),
        .m_axi_bvalid(axi_bvalid), .m_axi_bready(axi_bready),
        .start_read(start_read), .read_addr(read_addr), .read_len(read_len),
        .read_id(read_id), .read_user(read_user), .read_data(read_data),
        .read_strb(read_strb), .read_data_valid(read_data_valid),
        .read_data_last(read_data_last), .read_data_ready(read_data_ready),
        .read_busy(read_busy), .read_done(read_done), .read_resp(read_resp),
        .read_resp_id(read_resp_id), .read_resp_user(read_resp_user),
        .m_axi_arid(axi_arid), .m_axi_araddr(axi_araddr), .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize), .m_axi_arburst(axi_arburst), .m_axi_aruser(axi_aruser),
        .m_axi_arvalid(axi_arvalid), .m_axi_arready(axi_arready),
        .m_axi_rid(axi_rid), .m_axi_rdata(axi_rdata), .m_axi_rresp(axi_rresp),
        .m_axi_rlast(axi_rlast), .m_axi_ruser(axi_ruser),
        .m_axi_rvalid(axi_rvalid), .m_axi_rready(axi_rready)
    );

    // Slave 
    axi_slave #(
        .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH), .USER_WIDTH(USER_WIDTH),
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) u_slave (
        .clk(clk), .rst(rst),
        .s_axi_awid(axi_awid), .s_axi_awaddr(axi_awaddr), .s_axi_awlen(axi_awlen),
        .s_axi_awsize(axi_awsize), .s_axi_awburst(axi_awburst), .s_axi_awuser(axi_awuser),
        .s_axi_awvalid(axi_awvalid), .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata), .s_axi_wstrb(axi_wstrb), .s_axi_wlast(axi_wlast),
        .s_axi_wuser(axi_wuser), .s_axi_wvalid(axi_wvalid), .s_axi_wready(axi_wready),
        .s_axi_bid(axi_bid), .s_axi_bresp(axi_bresp), .s_axi_buser(axi_buser),
        .s_axi_bvalid(axi_bvalid), .s_axi_bready(axi_bready),
        .s_axi_arid(axi_arid), .s_axi_araddr(axi_araddr), .s_axi_arlen(axi_arlen),
        .s_axi_arsize(axi_arsize), .s_axi_arburst(axi_arburst), .s_axi_aruser(axi_aruser),
        .s_axi_arvalid(axi_arvalid), .s_axi_arready(axi_arready),
        .s_axi_rid(axi_rid), .s_axi_rdata(axi_rdata), .s_axi_rresp(axi_rresp),
        .s_axi_rlast(axi_rlast), .s_axi_ruser(axi_ruser),
        .s_axi_rvalid(axi_rvalid), .s_axi_rready(axi_rready),
        .mem_wr_addr(mem_wr_addr), .mem_wr_data(mem_wr_data),
        .mem_wr_strb(mem_wr_strb), .mem_wr_en(mem_wr_en),
        .mem_rd_addr(mem_rd_addr), .mem_rd_data(mem_rd_data)
    );

    always #5 clk = ~clk;

    // 寫入任務
    task automatic write_word(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data, input [ID_WIDTH-1:0] id);
        begin
            @(posedge clk);
            start_write      <= 1'b1;
            write_addr       <= addr;
            write_len        <= 8'd0;
            write_id         <= id;
            write_user       <= 1'b1;
            write_data       <= data;
            write_strb       <= 4'b1111;
            write_data_valid <= 1'b1;

            @(posedge clk);
            start_write <= 1'b0;

            while (!(write_data_valid && write_data_ready)) @(posedge clk);
            @(posedge clk);
            write_data_valid <= 1'b0;

            while (!write_done) @(posedge clk);
        end
    endtask

    // 讀取
    task automatic read_and_check(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected_data, input [ID_WIDTH-1:0] id);
        begin
            @(posedge clk);
            start_read      <= 1'b1;
            read_addr       <= addr;
            read_len        <= 8'd0;
            read_id         <= id;
            read_user       <= 1'b1;
            read_data_ready <= 1'b1;

            @(posedge clk);
            start_read <= 1'b0;

            while (!read_data_valid) @(posedge clk);

            if (read_data !== expected_data) begin
                $display("  [FAIL] Addr: 0x%08x | Expected: 0x%08x | Got: 0x%08x", addr, expected_data, read_data);
                errors = errors + 1;
            end else begin
                $display("  [PASS] Addr: 0x%08x | Got Correct Data: 0x%08x", addr, read_data);
            end

            while (!read_done) @(posedge clk);
        end
    endtask

    // 測試主流程
    initial begin
        $dumpfile("tb_axi_system.vcd");
        $dumpvars(0, tb_axi_system);

        clk = 0;
        rst = 1;
        errors = 0;
        start_write = 0;
        write_data_valid = 0;
        start_read = 0;
        read_data_ready = 0;

        // 初始狀態記憶體清零
        for (i = 0; i < MEMORY_DEPTH; i = i + 1) mem_array[i] = 32'h0;

        repeat (4) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        //----------------------------------------------------------------------
        // 測試 1: 同一 Address 連續寫入 2 次，確認讀回為第 2 次的最新資料
        //----------------------------------------------------------------------
        $display("\n--- [Scenario 1] Overwrite Same Address Twice ---");
        $display("  Writing 0x1111_1111 to 0x0000_0010 (1st time)");
        write_word(32'h0000_0010, 32'h1111_1111, 4'h1);

        $display("  Writing 0x2222_2222 to 0x0000_0010 (2nd time - Overwrite)");
        write_word(32'h0000_0010, 32'h2222_2222, 4'h2);

        $display("  Reading back from 0x0000_0010...");
        read_and_check(32'h0000_0010, 32'h2222_2222, 4'h3);

        //----------------------------------------------------------------------
        // 測試 2: 順向依序寫入 3 個位址，反向順序讀回驗證 (A->B->C, 讀 C->B->A)
        //----------------------------------------------------------------------
        $display("\n--- [Scenario 2] Write 3 Addresses, Read in Reverse Order ---");
        $display("  Writing Addr A (0x0000_0020) = 0xAAAA_0001");
        write_word(32'h0000_0020, 32'hAAAA_0001, 4'h4);

        $display("  Writing Addr B (0x0000_0030) = 32'hBBBB_0002");
        write_word(32'h0000_0030, 32'hBBBB_0002, 4'h5);

        $display("  Writing Addr C (0x0000_0040) = 32'hCCCC_0003");
        write_word(32'h0000_0040, 32'hCCCC_0003, 4'h6);

        $display("  Reverse Reading Addr C (0x0000_0040)...");
        read_and_check(32'h0000_0040, 32'hCCCC_0003, 4'h7);

        $display("  Reverse Reading Addr B (0x0000_0030)...");
        read_and_check(32'h0000_0030, 32'hBBBB_0002, 4'h8);

        $display("  Reverse Reading Addr A (0x0000_0020)...");
        read_and_check(32'h0000_0020, 32'hAAAA_0001, 4'h9);

        //----------------------------------------------------------------------
        // 測試 3: 讀取從未被寫入過的 3 個位址，確認讀回為預設初始值 (0x0000_0000)
        //----------------------------------------------------------------------
        $display("\n--- [Scenario 3] Read 3 Unwritten Addresses (Expect default 0) ---");
        $display("  Checking unwritten Addr 0x0000_0100...");
        read_and_check(32'h0000_0100, 32'h0000_0000, 4'hA);

        $display("  Checking unwritten Addr 0x0000_0200...");
        read_and_check(32'h0000_0200, 32'h0000_0000, 4'hB);

        $display("  Checking unwritten Addr 0x0000_03FC (Boundary)...");
        read_and_check(32'h0000_03FC, 32'h0000_0000, 4'hC);

        //----------------------------------------------------------------------
        // 結果統整
        //----------------------------------------------------------------------
        $display("\n=============================================================");
        if (errors == 0)
            $display(">>> ALL 3 SCENARIOS PASSED SUCCESSFULLY! <<<");
        else
            $display(">>> TEST FAILED with %0d error(s)! <<<", errors);
        $display("=============================================================");

        #20;
        $finish;
    end

endmodule