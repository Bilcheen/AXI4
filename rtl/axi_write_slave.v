`timescale 1ns/1ps

module axi_write_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter USER_WIDTH = 1,
    parameter MEMORY_DEPTH = 256
)(
    input wire clk,
    input wire rst,

    // AXI4 AW channel
    input wire [ID_WIDTH-1:0]     s_axi_awid,
    input wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input wire [7:0]              s_axi_awlen,
    input wire [2:0]              s_axi_awsize,
    input wire [1:0]              s_axi_awburst,
    input wire [USER_WIDTH-1:0]   s_axi_awuser,
    input wire                    s_axi_awvalid,
    output wire                   s_axi_awready,

    // AXI4 W channel
    input wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input wire                    s_axi_wlast,
    input wire [USER_WIDTH-1:0]   s_axi_wuser,
    input wire                    s_axi_wvalid,
    output wire                   s_axi_wready,

    // AXI4 B channel
    output reg [ID_WIDTH-1:0]     s_axi_bid,
    output reg [1:0]              s_axi_bresp,
    output reg [USER_WIDTH-1:0]   s_axi_buser,
    output reg                    s_axi_bvalid,
    input wire                    s_axi_bready,

    // External memory write interface
    output reg [$clog2(MEMORY_DEPTH)-1:0] mem_wr_addr,
    output reg [DATA_WIDTH-1:0]           mem_wr_data,
    output reg [(DATA_WIDTH/8)-1:0]       mem_wr_strb,
    output reg                            mem_wr_en
);

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam integer ADDR_SHIFT = $clog2(STRB_WIDTH);

    localparam [1:0]
        S_IDLE = 2'd0,
        S_DATA = 2'd1,
        S_RESP = 2'd2;

    reg [1:0] state;

    reg [ADDR_WIDTH-1:0] write_addr_reg;
    reg [7:0] write_len_reg;
    reg [7:0] write_beat_count;
    reg [2:0] write_size_reg;
    reg [1:0] write_burst_reg;
    reg [ID_WIDTH-1:0] write_id_reg;
    reg [USER_WIDTH-1:0] write_user_reg;

    wire [ADDR_WIDTH-1:0] beat_bytes;
    assign beat_bytes = ({{(ADDR_WIDTH-1){1'b0}}, 1'b1}
                         << write_size_reg);

    assign s_axi_awready = (state == S_IDLE);
    assign s_axi_wready  = (state == S_DATA);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;

            write_addr_reg <= {ADDR_WIDTH{1'b0}};
            write_len_reg <= 8'd0;
            write_beat_count <= 8'd0;
            write_size_reg <= 3'd0;
            write_burst_reg <= 2'b01;
            write_id_reg <= {ID_WIDTH{1'b0}};
            write_user_reg <= {USER_WIDTH{1'b0}};

            s_axi_bid <= {ID_WIDTH{1'b0}};
            s_axi_bresp <= 2'b00;
            s_axi_buser <= {USER_WIDTH{1'b0}};
            s_axi_bvalid <= 1'b0;

            mem_wr_addr <= {($clog2(MEMORY_DEPTH)){1'b0}};
            mem_wr_data <= {DATA_WIDTH{1'b0}};
            mem_wr_strb <= {STRB_WIDTH{1'b0}};
            mem_wr_en <= 1'b0;
        end else begin
            mem_wr_en <= 1'b0;

            case (state)

                S_IDLE: begin
                    s_axi_bvalid <= 1'b0;

                    if (s_axi_awvalid && s_axi_awready) begin
                        write_addr_reg <= s_axi_awaddr;
                        write_len_reg <= s_axi_awlen;
                        write_beat_count <= 8'd0;
                        write_size_reg <= s_axi_awsize;
                        write_burst_reg <= s_axi_awburst;
                        write_id_reg <= s_axi_awid;
                        write_user_reg <= s_axi_awuser;

                        state <= S_DATA;
                    end
                end

                S_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        mem_wr_addr <=
                            write_addr_reg[
                                ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1:
                                ADDR_SHIFT
                            ];

                        mem_wr_data <= s_axi_wdata;
                        mem_wr_strb <= s_axi_wstrb;
                        mem_wr_en <= 1'b1;

                        if (s_axi_wlast) begin
                            s_axi_bid <= write_id_reg;
                            s_axi_bresp <= 2'b00;
                            s_axi_buser <= write_user_reg;
                            s_axi_bvalid <= 1'b1;

                            state <= S_RESP;
                        end else begin
                            write_beat_count <=
                                write_beat_count + 1'b1;

                            case (write_burst_reg)
                                2'b00: begin
                                    // FIXED burst
                                    write_addr_reg <= write_addr_reg;
                                end

                                2'b01: begin
                                    // INCR burst
                                    write_addr_reg <=
                                        write_addr_reg + beat_bytes;
                                end

                                default: begin
                                    // WRAP 尚未實作
                                    write_addr_reg <=
                                        write_addr_reg + beat_bytes;
                                end
                            endcase
                        end
                    end
                end

                S_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: begin
                    state <= S_IDLE;
                    s_axi_bvalid <= 1'b0;
                end

            endcase
        end
    end

endmodule