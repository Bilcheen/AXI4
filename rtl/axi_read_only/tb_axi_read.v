`timescale 1ns/1ps

module tb_axi_read;

    localparam ID_WIDTH = 4;
    localparam DATA_WIDTH = 32;
    localparam USER_WIDTH = 1;

    reg clk;
    reg rst;

    // AR Channel
    reg s_axi_arvalid;
    wire s_axi_arready;
    reg [31:0] s_axi_araddr;
    reg [2:0] s_axi_arsize;
    reg [1:0] s_axi_arburst;
    reg [3:0] s_axi_arcache;
    reg [2:0] s_axi_arprot;
    reg [ID_WIDTH-1:0] s_axi_arid;
    reg [7:0] s_axi_arlen;
    reg s_axi_arlock;
    reg [3:0] s_axi_arqos;
    reg [3:0] s_axi_arregion;
    reg [USER_WIDTH-1:0] s_axi_aruser;

    // R Channel
    wire s_axi_rvalid;
    reg s_axi_rready;
    wire s_axi_rlast;
    wire [DATA_WIDTH-1:0] s_axi_rdata;
    wire [1:0] s_axi_rresp;
    wire [ID_WIDTH-1:0] s_axi_rid;
    wire [USER_WIDTH-1:0] s_axi_ruser;

    // Debug
    reg [7:0] debug_memory_addr;
    wire [DATA_WIDTH-1:0] debug_memory_data;

    integer errors;
    integer timeout;

    axi #(
        .ID_WIDTH(ID_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .USER_WIDTH(USER_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),

        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arregion(s_axi_arregion),
        .s_axi_aruser(s_axi_aruser),

        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rid(s_axi_rid),
        .s_axi_ruser(s_axi_ruser),

        .debug_memory_addr(debug_memory_addr),
        .debug_memory_data(debug_memory_data)
    );

    always #5 clk = ~clk;

    task automatic check;
        input condition;
        input [255:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("ERROR: %0s", message);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s", message);
            end
        end
    endtask

    task automatic send_ar;
        input [31:0] address;
        input [7:0] length;
        input [1:0] burst;
        input [ID_WIDTH-1:0] id;
        begin
            @(negedge clk);
            s_axi_araddr  = address;
            s_axi_arsize  = 3'd2;
            s_axi_arburst = burst;
            s_axi_arlen   = length;
            s_axi_arid    = id;
            s_axi_aruser  = 1'b1;
            s_axi_arvalid = 1'b1;

            while (!s_axi_arready)
                @(posedge clk);

            @(posedge clk);
            @(negedge clk);
            s_axi_arvalid = 1'b0;
        end
    endtask

    task automatic receive_r;
        input [DATA_WIDTH-1:0] expected_data;
        input expected_last;
        input [ID_WIDTH-1:0] expected_id;
        begin
            timeout = 0;

            while (!s_axi_rvalid && timeout < 20) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            check(timeout < 20, "RVALID timeout");
            check(s_axi_rdata == expected_data, "RDATA mismatch");
            check(s_axi_rlast == expected_last, "RLAST mismatch");
            check(s_axi_rresp == 2'b00, "RRESP is not OKAY");
            check(s_axi_rid == expected_id, "RID mismatch");
            check(s_axi_ruser == 1'b1, "RUSER mismatch");

            @(negedge clk);
            s_axi_rready = 1'b1;

            @(posedge clk);

            @(negedge clk);
            s_axi_rready = 1'b0;
        end
    endtask

    task automatic read_memory_word;
        input [7:0] address;
        output [DATA_WIDTH-1:0] value;
        begin
            debug_memory_addr = address;
            #1;
            value = debug_memory_data;
        end
    endtask

    reg [DATA_WIDTH-1:0] read_value;

    initial begin
        $dumpfile("axi_read.vcd");
        $dumpvars(0, tb_axi_read);

        clk = 1'b0;
        rst = 1'b1;
        errors = 0;

        s_axi_arvalid = 1'b0;
        s_axi_rready = 1'b0;

        s_axi_araddr = 0;
        s_axi_arsize = 0;
        s_axi_arburst = 0;
        s_axi_arcache = 0;
        s_axi_arprot = 0;
        s_axi_arid = 0;
        s_axi_arlen = 0;
        s_axi_arlock = 0;
        s_axi_arqos = 0;
        s_axi_arregion = 0;
        s_axi_aruser = 0;

        debug_memory_addr = 0;

        repeat (2) @(posedge clk);
        rst = 1'b0;

        check(s_axi_arready, "ARREADY is not high after reset");

        // Test 1: 直接透過 debug port 驗證預設資料
        read_memory_word(8'd16, read_value);
        check(read_value == 32'hAABB_CCDD, "Preloaded memory word 16 mismatch");

        read_memory_word(8'd18, read_value);
        check(read_value == 32'h1111_2222, "Preloaded memory word 18 mismatch");

        // Test 2: Single-beat read (Address 0x48 -> Word 18)
        $display("--- Test 2: Read Address 0x48 ---");
        send_ar(32'h48, 8'd0, 2'b01, 4'h5);
        check(s_axi_rvalid, "RVALID should be high after AR handshake");
        check(s_axi_rdata == 32'h1111_2222, "Read beat 0 RDATA mismatch");
        check(s_axi_rlast, "Single-beat RLAST should be high");
        receive_r(32'h1111_2222, 1'b1, 4'h5);

        // Test 3: Single-beat read (Address 0x4C -> Word 19)
        $display("--- Test 3: Read Address 0x4C ---");
        send_ar(32'h4C, 8'd0, 2'b01, 4'h6);
        check(s_axi_rvalid, "RVALID should be high after AR handshake");
        check(s_axi_rdata == 32'h3333_4444, "Read beat 1 RDATA mismatch");
        check(s_axi_rlast, "Single-beat RLAST should be high");
        receive_r(32'h3333_4444, 1'b1, 4'h6);

        if (errors == 0)
            $display("PASS: AXI read testbench");
        else
            $display("FAIL: %0d error(s)", errors);

        #20;
        $finish;
    end

endmodule