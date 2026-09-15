`timescale 1ns/1ps

module tb_axi_write_system;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam ID_WIDTH = 4;
    localparam USER_WIDTH = 1;
    localparam MEMORY_DEPTH = 256;
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam ADDR_SHIFT = $clog2(STRB_WIDTH);
    reg clk;
    reg rst;

    //=========================
    // AXI Write Master
    //========================= 
    reg start_write;
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [7:0] write_len;
    reg [ID_WIDTH-1:0] write_id;
    reg [USER_WIDTH-1:0] write_user;
    reg [DATA_WIDTH-1:0] write_data;
    reg [STRB_WIDTH-1:0] write_strb;
    reg write_data_valid;
    wire write_data_ready;
    wire write_busy;
    wire write_done;
    wire [1:0] write_resp;
    wire [ID_WIDTH-1:0] write_resp_id;
    wire [USER_WIDTH-1:0] write_resp_user;

    //=========================
    // AXI4 (Master -> Slave)
    //==========================
    // AW Channel
    wire [ID_WIDTH-1:0]     axi_awid;
    wire [ADDR_WIDTH-1:0]   axi_awaddr;
    wire [7:0]              axi_awlen;
    wire [2:0]              axi_awsize;
    wire [1:0]              axi_awburst;
    wire [USER_WIDTH-1:0]   axi_awuser;
    wire                    axi_awvalid;
    wire                    axi_awready;

    // W Channel
    wire [DATA_WIDTH-1:0]   axi_wdata;
    wire [STRB_WIDTH-1:0]   axi_wstrb;
    wire                    axi_wlast;
    wire [USER_WIDTH-1:0]   axi_wuser;
    wire                    axi_wvalid;
    wire                    axi_wready;

    // B Channel
    wire [ID_WIDTH-1:0]     axi_bid;
    wire [1:0]              axi_bresp;
    wire [USER_WIDTH-1:0]   axi_buser;
    wire                    axi_bvalid;
    wire                    axi_bready;

    // Slave Memory
    wire [$clog2(MEMORY_DEPTH)-1:0] mem_wr_addr;
    wire [DATA_WIDTH-1:0]           mem_wr_data;
    wire [STRB_WIDTH-1:0]           mem_wr_strb;
    wire                            mem_wr_en;

    //=========================
    // 驗證用 Reference Memory
    //=========================
    reg [DATA_WIDTH-1:0] shadow_mem [0:MEMORY_DEPTH-1];
    integer errors;
    integer a_idx, d_idx, byte_i;

    //=========================
    // AXI Write Master
    //=========================
    axi_write_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) u_master (
        .clk(clk),
        .rst(rst),

        .start_write(start_write),
        .write_addr(write_addr),
        .write_len(write_len),
        .write_id(write_id),
        .write_user(write_user),

        .write_data(write_data),
        .write_strb(write_strb),
        .write_data_valid(write_data_valid),
        .write_data_ready(write_data_ready),

        .write_busy(write_busy),
        .write_done(write_done),
        .write_resp(write_resp),
        .write_resp_id(write_resp_id),
        .write_resp_user(write_resp_user),

        .m_axi_awid(axi_awid),
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize),
        .m_axi_awburst(axi_awburst),
        .m_axi_awuser(axi_awuser),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),

        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wlast(axi_wlast),
        .m_axi_wuser(axi_wuser),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),

        .m_axi_bid(axi_bid),
        .m_axi_bresp(axi_bresp),
        .m_axi_buser(axi_buser),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready)
    );

    //=========================
    // AXI Write Slave
    //=========================
    axi_write_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) u_slave (
        .clk(clk),
        .rst(rst),

        .s_axi_awid(axi_awid),
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awlen(axi_awlen),
        .s_axi_awsize(axi_awsize),
        .s_axi_awburst(axi_awburst),
        .s_axi_awuser(axi_awuser),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),

        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wlast(axi_wlast),
        .s_axi_wuser(axi_wuser),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),

        .s_axi_bid(axi_bid),
        .s_axi_bresp(axi_bresp),
        .s_axi_buser(axi_buser),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),

        .mem_wr_addr(mem_wr_addr),
        .mem_wr_data(mem_wr_data),
        .mem_wr_strb(mem_wr_strb),
        .mem_wr_en(mem_wr_en)
    );

    always #5 clk = ~clk;
    //=========================
    // Slave Memory
    //=========================
    always @(posedge clk) begin
        if (!rst && mem_wr_en) begin
            for (byte_i = 0; byte_i < STRB_WIDTH; byte_i = byte_i + 1) begin
                if (mem_wr_strb[byte_i]) begin
                    shadow_mem[mem_wr_addr][byte_i*8 +: 8] <= mem_wr_data[byte_i*8 +: 8];
                end
            end
        end
    end

    //=========================
    // Task: 單拍寫入驅動 (Single-beat Write Transaction)
    //=========================
    task automatic execute_single_write(
        input [ADDR_WIDTH-1:0] target_addr,
        input [DATA_WIDTH-1:0] target_data,
        input [STRB_WIDTH-1:0] target_strb,
        input [ID_WIDTH-1:0]   trans_id
    );
        integer wait_timer;
        begin
            @(posedge clk);
            start_write      <= 1'b1;
            write_addr       <= target_addr;
            write_len        <= 8'd0;       // len=0 代表 1 個 beat[cite: 4]
            write_id         <= trans_id;
            write_user       <= 1'b1;

            write_data       <= target_data;
            write_strb       <= target_strb;
            write_data_valid <= 1'b1;

            @(posedge clk);
            start_write <= 1'b0;

            // 等待 Master 進入 W_GET 狀態並拉取資料 (包含 100 個時脈週期的安全計時)
            wait_timer = 0;
            while (!(write_data_valid && write_data_ready) && wait_timer < 100) begin
                @(posedge clk);
                wait_timer = wait_timer + 1;
            end

            if (wait_timer >= 100) begin
                $display("[ERROR] Timeout waiting for write_data_ready at Addr: 0x%08x", target_addr);
                errors = errors + 1;
            end

            @(posedge clk);
            write_data_valid <= 1'b0;

            // 等待整個寫入交易完成 (write_done)
            wait_timer = 0;
            while (!write_done && wait_timer < 100) begin
                @(posedge clk);
                wait_timer = wait_timer + 1;
            end

            if (wait_timer >= 100) begin
                $display("[ERROR] Timeout waiting for write_done! Addr: 0x%08x", target_addr);
                errors = errors + 1;
            end else begin
                // 檢查回應狀態與 ID
                if (write_resp !== 2'b00) begin
                    $display("[ERROR] Response BRESP not OKAY (00), got: %b", write_resp);
                    errors = errors + 1;
                end
                if (write_resp_id !== trans_id) begin
                    $display("[ERROR] Response ID mismatch! Expected: %h, Got: %h", trans_id, write_resp_id);
                    errors = errors + 1;
                end
            end
        end
    endtask


    //=========================
    // 交叉測試清單定義 (Cross-Testing Arrays)
    //=========================
    localparam NUM_ADDRS = 6;
    localparam NUM_DATAS = 6;

    reg [ADDR_WIDTH-1:0] test_addrs [0:NUM_ADDRS-1];
    reg [DATA_WIDTH-1:0] test_datas [0:NUM_DATAS-1];
    reg [STRB_WIDTH-1:0] test_strbs [0:NUM_DATAS-1];

    initial begin
        // test_addrs
        test_addrs[0] = 32'h0000_0000; // 最低位址 Word 0
        test_addrs[1] = 32'h0000_0010; // Word 4
        test_addrs[2] = 32'h0000_0054; // Word 21
        test_addrs[3] = 32'h0000_00A8; // Word 42
        test_addrs[4] = 32'h0000_01FC; // Word 127
        test_addrs[5] = 32'h0000_03FC; // 深度邊界 Word 255 ((256-1)*4)

        // test_datas
        test_datas[0] = 32'h0000_0000; test_strbs[0] = 4'b1111;
        test_datas[1] = 32'hFFFF_FFFF; test_strbs[1] = 4'b1111;
        test_datas[2] = 32'hA5A5_5A5A; test_strbs[2] = 4'b1111;
        test_datas[3] = 32'h1234_5678;  test_strbs[3] = 4'b1111;
        test_datas[4] = 32'hDEAD_BEEF; test_strbs[4] = 4'b1111;
        test_datas[5] = 32'hCAFE_BABE; test_strbs[5] = 4'b1111;
    end


    initial begin
        // 波形輸出設定 (預設生成至 sim/ 目錄)
        $dumpfile("tb_axi_write_system.vcd");
        $dumpvars(0, tb_axi_write_system);

        // 初始訊號狀態
        clk = 1'b0;
        rst = 1'b1;
        errors = 0;
        start_write = 1'b0;
        write_addr = 0;
        write_len = 0;
        write_id = 0;
        write_user = 0;
        write_data = 0;
        write_strb = 0;
        write_data_valid = 1'b0;

        for (a_idx = 0; a_idx < MEMORY_DEPTH; a_idx = a_idx + 1) begin
            shadow_mem[a_idx] = 32'h0;
        end

        // 系統非同步/同步重設釋放
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        $display("=====================================================================");
        $display("  AXI4 Write System Cross-Verification (Multiple Addr x Data)");
        $display("=====================================================================");

        //----------------------------------------------------------------------
        // 階段一：Address 與 Data 交叉組合寫入測試 (Cross Testing Matrix)
        // 總計執行 NUM_ADDRS * NUM_DATAS = 36 次不同排列組合測試
        //----------------------------------------------------------------------
        for (a_idx = 0; a_idx < NUM_ADDRS; a_idx = a_idx + 1) begin
            for (d_idx = 0; d_idx < NUM_DATAS; d_idx = d_idx + 1) begin
                
                // 執行寫入，ID 動態切換 (利用位址與資料索引組裝 ID)
                execute_single_write(
                    test_addrs[a_idx],
                    test_datas[d_idx],
                    test_strbs[d_idx],
                    (a_idx + d_idx) % (1 << ID_WIDTH)
                );

                // 即時驗證：檢查 Shadow RAM 與預期資料是否一致
                if (shadow_mem[test_addrs[a_idx][ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1 : ADDR_SHIFT]] !== test_datas[d_idx]) begin
                    $display("[FAIL] Cross Match Mismatch! Addr: 0x%08x (Word idx %0d) | Expected: 0x%08x | Got: 0x%08x",
                             test_addrs[a_idx],
                             test_addrs[a_idx][ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1 : ADDR_SHIFT],
                             test_datas[d_idx],
                             shadow_mem[test_addrs[a_idx][ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1 : ADDR_SHIFT]]);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Write Addr: 0x%08x -> Data: 0x%08x [Verified]", 
                             test_addrs[a_idx], test_datas[d_idx]);
                end

                repeat (2) @(posedge clk);
            end
        end

        //----------------------------------------------------------------------
        // 階段二：WSTRB Byte Mask 遮罩局部覆寫測試
        //----------------------------------------------------------------------
        $display("---------------------------------------------------------------------");
        $display("  Testing Byte Strobes (WSTRB partial write)...");
        $display("---------------------------------------------------------------------");
        // 先寫入基底資料 0x11223344 到 0x0000_0020 (Word 8)
        execute_single_write(32'h0000_0020, 32'h1122_3344, 4'b1111, 4'hE);
        
        // 僅覆寫 Byte 0 與 Byte 2 (WSTRB = 4'b0101)，寫入 0xAAAA_BBBB
        execute_single_write(32'h0000_0020, 32'hAAAA_BBBB, 4'b0101, 4'hF);

        // 預期結果應為 0x11AA_33BB
        if (shadow_mem[32'h20 >> 2] !== 32'h11AA_33BB) begin
            $display("[FAIL] WSTRB Test Failed! Expected: 0x11AA33BB, Got: 0x%08x", shadow_mem[32'h20 >> 2]);
            errors = errors + 1;
        end else begin
            $display("[PASS] WSTRB Partial Write Verified: 0x%08x", shadow_mem[32'h20 >> 2]);
        end

        //----------------------------------------------------------------------
        // 測試結果彙整
        //----------------------------------------------------------------------
        $display("=====================================================================");
        if (errors == 0) begin
            $display("  >>> ALL TESTS PASSED! AXI Write System verification successful. <<<");
        end else begin
            $display("  >>> TEST FAILED with %0d error(s). <<<", errors);
        end
        $display("=====================================================================");

        #50;
        $finish;
    end

endmodule