`timescale 1ns/1ps

module tb_axi_read_system;

    //==========================================================================
    // 參數定義
    //==========================================================================
    localparam ADDR_WIDTH   = 32;
    localparam DATA_WIDTH   = 32;
    localparam ID_WIDTH     = 4;
    localparam USER_WIDTH   = 1;
    localparam MEMORY_DEPTH = 256;
    localparam STRB_WIDTH   = DATA_WIDTH / 8;
    localparam ADDR_SHIFT   = $clog2(STRB_WIDTH);

    //==========================================================================
    // 時脈與重設
    //==========================================================================
    reg clk;
    reg rst;

    //==========================================================================
    // Master Local 控制與串流資料介面
    //==========================================================================
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

    //==========================================================================
    // AXI4 Read 匯流排通道 (Master <-> Slave)
    //==========================================================================
    // AR Channel
    wire [ID_WIDTH-1:0]     axi_arid;
    wire [ADDR_WIDTH-1:0]   axi_araddr;
    wire [7:0]              axi_arlen;
    wire [2:0]              axi_arsize;
    wire [1:0]              axi_arburst;
    wire [USER_WIDTH-1:0]   axi_aruser;
    wire                    axi_arvalid;
    wire                    axi_arready;

    // R Channel
    wire [ID_WIDTH-1:0]     axi_rid;
    wire [DATA_WIDTH-1:0]   axi_rdata;
    wire [1:0]              axi_rresp;
    wire                    axi_rlast;
    wire [USER_WIDTH-1:0]   axi_ruser;
    wire                    axi_rvalid;
    wire                    axi_rready;

    // Slave Memory 讀取介面
    wire [$clog2(MEMORY_DEPTH)-1:0] mem_rd_addr;
    reg  [DATA_WIDTH-1:0]           mem_rd_data;

    //==========================================================================
    // 內部測試記憶體 (SRAM Model) 與統計變數
    //==========================================================================
    reg [DATA_WIDTH-1:0] sram [0:MEMORY_DEPTH-1];
    integer errors;
    integer i, a_idx, d_idx;

    // 非同步模擬同步 SRAM 讀取行為 (隨 mem_rd_addr 即時更新)
    always @(*) begin
        mem_rd_data = sram[mem_rd_addr];
    end

    //==========================================================================
    // 待測模組 1: AXI Read Master
    //==========================================================================
    axi_read_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) u_master (
        .clk(clk),
        .rst(rst),

        .start_read(start_read),
        .read_addr(read_addr),
        .read_len(read_len),
        .read_id(read_id),
        .read_user(read_user),

        .read_data(read_data),
        .read_strb(read_strb),
        .read_data_valid(read_data_valid),
        .read_data_last(read_data_last),
        .read_data_ready(read_data_ready),

        .read_busy(read_busy),
        .read_done(read_done),
        .read_resp(read_resp),
        .read_resp_id(read_resp_id),
        .read_resp_user(read_resp_user),

        .m_axi_arid(axi_arid),
        .m_axi_araddr(axi_araddr),
        .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize),
        .m_axi_arburst(axi_arburst),
        .m_axi_aruser(axi_aruser),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),

        .m_axi_rid(axi_rid),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        .m_axi_rlast(axi_rlast),
        .m_axi_ruser(axi_ruser),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready)
    );

    //==========================================================================
    // 待測模組 2: AXI Read Slave
    //==========================================================================
    axi_read_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .USER_WIDTH(USER_WIDTH),
        .MEMORY_DEPTH(MEMORY_DEPTH)
    ) u_slave (
        .clk(clk),
        .rst(rst),

        .s_axi_arid(axi_arid),
        .s_axi_araddr(axi_araddr),
        .s_axi_arlen(axi_arlen),
        .s_axi_arsize(axi_arsize),
        .s_axi_arburst(axi_arburst),
        .s_axi_aruser(axi_aruser),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),

        .s_axi_rid(axi_rid),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rlast(axi_rlast),
        .s_axi_ruser(axi_ruser),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),

        .mem_rd_addr(mem_rd_addr),
        .mem_rd_data(mem_rd_data)
    );

    // 時脈產生 (100MHz, 週期 10ns)
    always #5 clk = ~clk;

    //==========================================================================
    // Task: 執行單拍讀取並自動斷言 (Single-beat Read Assertion)
    //==========================================================================
    task automatic execute_single_read(
        input [ADDR_WIDTH-1:0] target_addr,
        input [DATA_WIDTH-1:0] expected_data,
        input [ID_WIDTH-1:0]   trans_id
    );
        integer timer;
        begin
            @(posedge clk);
            start_read      <= 1'b1;
            read_addr       <= target_addr;
            read_len        <= 8'd0;       // 單拍 (len=0)
            read_id         <= trans_id;
            read_user       <= 1'b1;
            read_data_ready <= 1'b1;       // Master local side ready to consume

            @(posedge clk);
            start_read <= 1'b0;

            // 等待 local read_data_valid
            timer = 0;
            while (!read_data_valid && timer < 100) begin
                @(posedge clk);
                timer = timer + 1;
            end

            if (timer >= 100) begin
                $display("[ERROR] Timeout waiting for read_data_valid at Addr: 0x%08x", target_addr);
                errors = errors + 1;
            end else begin
                // 資料與狀態檢查
                if (read_data !== expected_data) begin
                    $display("[FAIL] Data Mismatch at Addr: 0x%08x | Expected: 0x%08x | Got: 0x%08x",
                             target_addr, expected_data, read_data);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] Read Addr: 0x%08x -> Data: 0x%08x [Verified]",
                             target_addr, read_data);
                end

                if (read_data_last !== 1'b1) begin
                    $display("[ERROR] read_data_last should be 1 for single-beat read!");
                    errors = errors + 1;
                end
                if (read_resp !== 2'b00) begin
                    $display("[ERROR] Response RRESP is not OKAY (00), got: %b", read_resp);
                    errors = errors + 1;
                end
                if (read_resp_id !== trans_id) begin
                    $display("[ERROR] Response ID mismatch! Expected: %h, Got: %h", trans_id, read_resp_id);
                    errors = errors + 1;
                end
            end

            // 等待 read_done
            timer = 0;
            while (!read_done && timer < 100) begin
                @(posedge clk);
                timer = timer + 1;
            end
        end
    endtask

    //==========================================================================
    // 交叉測試設定 (Addresses & Pattern Datas)
    //==========================================================================
    localparam NUM_ADDRS = 6;
    localparam NUM_DATAS = 6;

    reg [ADDR_WIDTH-1:0] test_addrs [0:NUM_ADDRS-1];
    reg [DATA_WIDTH-1:0] test_datas [0:NUM_DATAS-1];

    initial begin
        // 位址清單：覆蓋 Word 0、中間 Offset 以及深度邊界
        test_addrs[0] = 32'h0000_0000; // Word 0
        test_addrs[1] = 32'h0000_0010; // Word 4
        test_addrs[2] = 32'h0000_0054; // Word 21
        test_addrs[3] = 32'h0000_00A8; // Word 42
        test_addrs[4] = 32'h0000_01FC; // Word 127
        test_addrs[5] = 32'h0000_03FC; // Word 255 (邊界)

        // 特徵資料清單
        test_datas[0] = 32'h0000_0000;
        test_datas[1] = 32'hFFFF_FFFF;
        test_datas[2] = 32'hA5A5_5A5A;
        test_datas[3] = 32'h1234_5678;
        test_datas[4] = 32'hDEAD_BEEF;
        test_datas[5] = 32'hCAFE_BABE;
    end

    //==========================================================================
    // 主測試程序
    //==========================================================================
    integer burst_beat;
    initial begin
        $dumpfile("tb_axi_read_system.vcd");
        $dumpvars(0, tb_axi_read_system);

        clk = 1'b0;
        rst = 1'b1;
        errors = 0;
        start_read = 1'b0;
        read_addr = 0;
        read_len = 0;
        read_id = 0;
        read_user = 0;
        read_data_ready = 1'b0;

        // 初始化記憶體
        for (i = 0; i < MEMORY_DEPTH; i = i + 1) begin
            sram[i] = 32'h0000_0000;
        end

        // 系統重設
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        $display("=====================================================================");
        $display("  AXI4 Read System Cross-Verification (Multiple Addr x Data)");
        $display("=====================================================================");

        //----------------------------------------------------------------------
        // 階段一：Address 與 Data 交叉組合讀取測試
        // 將不同 Data 填入目標 Address，發起讀取驗證傳輸正確性
        //----------------------------------------------------------------------
        for (a_idx = 0; a_idx < NUM_ADDRS; a_idx = a_idx + 1) begin
            for (d_idx = 0; d_idx < NUM_DATAS; d_idx = d_idx + 1) begin

                // 填入 SRAM 目標 Word
                sram[test_addrs[a_idx][ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1 : ADDR_SHIFT]] = test_datas[d_idx];

                // 呼叫單拍讀取驅動與比對
                execute_single_read(
                    test_addrs[a_idx],
                    test_datas[d_idx],
                    (a_idx + d_idx) % (1 << ID_WIDTH)
                );

                repeat (2) @(posedge clk);
            end
        end

        //----------------------------------------------------------------------
        // 階段二：Burst Read 突發長度讀取測試 (INCR Burst, len = 3 -> 4 beats)
        //----------------------------------------------------------------------
        $display("---------------------------------------------------------------------");
        $display("  Testing Multi-beat Burst Read (len = 3, 4 beats)...");
        $display("---------------------------------------------------------------------");

        // 預先寫入連續 4 個 Word
        sram[8'd32] = 32'hAAAA_0001; // 0x080
        sram[8'd33] = 32'hBBBB_0002; // 0x084
        sram[8'd34] = 32'hCCCC_0003; // 0x088
        sram[8'd35] = 32'hDDDD_0004; // 0x08C

        @(posedge clk);
        start_read      <= 1'b1;
        read_addr       <= 32'h0000_0080;
        read_len        <= 8'd3;           // 4 beats
        read_id         <= 4'h9;
        read_user       <= 1'b1;
        read_data_ready <= 1'b1;

        @(posedge clk);
        start_read <= 1'b0;

        for (burst_beat = 0; burst_beat < 4; burst_beat = burst_beat + 1) begin
            while (!read_data_valid) @(posedge clk);

            // 驗證連續 beats 資料
            if (read_data !== sram[8'd32 + burst_beat]) begin
                $display("[FAIL] Burst Beat %0d mismatch! Expected: 0x%08x, Got: 0x%08x",
                         burst_beat, sram[8'd32 + burst_beat], read_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] Burst Beat %0d: 0x%08x Verified", burst_beat, read_data);
            end

            // 驗證最後一拍的 last 旗標
            if (burst_beat == 3 && !read_data_last) begin
                $display("[FAIL] Burst Beat 3 missing read_data_last!");
                errors = errors + 1;
            end

            @(posedge clk);
        end

        while (!read_done) @(posedge clk);

        //----------------------------------------------------------------------
        // 結果統計
        //----------------------------------------------------------------------
        $display("=====================================================================");
        if (errors == 0) begin
            $display("  >>> ALL TESTS PASSED! AXI Read System verification successful. <<<");
        end else begin
            $display("  >>> TEST FAILED with %0d error(s). <<<", errors);
        end
        $display("=====================================================================");

        #50;
        $finish;
    end

endmodule