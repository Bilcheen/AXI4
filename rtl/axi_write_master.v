`timescale 1ns/1ps

module axi_write_master #(
    parameter ADDR_WIDTH = 32,  // Address width
    parameter DATA_WIDTH = 32,  // Data width
    parameter ID_WIDTH   = 4,   //transaction ID width  
    parameter USER_WIDTH = 1    // User signal width
)(
    input wire clk,
    input wire rst,

    // Local write command
    input wire                    start_write,
    input wire [ADDR_WIDTH-1:0]   write_addr,
    input wire [7:0]              write_len,
    input wire [ID_WIDTH-1:0]     write_id,
    input wire [USER_WIDTH-1:0]   write_user,

    // Local write data stream
    input wire [DATA_WIDTH-1:0]   write_data,
    input wire [(DATA_WIDTH/8)-1:0] write_strb,
    input wire                    write_data_valid,
    output wire                   write_data_ready,

    // Local status
    output reg                    write_busy,
    output reg                    write_done,
    output reg [1:0]              write_resp,
    output reg [ID_WIDTH-1:0]     write_resp_id,
    output reg [USER_WIDTH-1:0]   write_resp_user,

    // AXI4 AW channel
    output reg [ID_WIDTH-1:0]     m_axi_awid,
    output reg [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output reg [7:0]              m_axi_awlen,
    output reg [2:0]              m_axi_awsize,
    output reg [1:0]              m_axi_awburst,
    output reg [USER_WIDTH-1:0]   m_axi_awuser,
    output reg                    m_axi_awvalid,
    input wire                    m_axi_awready,

    // AXI4 W channel
    output reg [DATA_WIDTH-1:0]   m_axi_wdata,
    output reg [(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg [USER_WIDTH-1:0]   m_axi_wuser,
    output reg                    m_axi_wvalid,
    input wire                    m_axi_wready,

    // AXI4 B channel
    input wire [ID_WIDTH-1:0]     m_axi_bid,
    input wire [1:0]              m_axi_bresp,
    input wire [USER_WIDTH-1:0]   m_axi_buser,
    input wire                    m_axi_bvalid,
    output reg                    m_axi_bready
);

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam [2:0] AXI_SIZE = $clog2(STRB_WIDTH);

    localparam [2:0]
        W_IDLE = 3'd0,  //等待write command寫入
        W_AW   = 3'd1,  //傳送AW channel
        W_GET   = 3'd2, //等待data寫入
        W_DATA  = 3'd3, //傳送W channel
        W_B     = 3'd4; //等待B channel回應

    reg [2:0] state;

    reg [ADDR_WIDTH-1:0] write_addr_reg;
    reg [7:0]            write_len_reg;
    reg [7:0]            beat_count_reg;
    reg [ID_WIDTH-1:0]   write_id_reg;
    reg [USER_WIDTH-1:0] write_user_reg;

    reg [DATA_WIDTH-1:0] write_data_reg;
    reg [STRB_WIDTH-1:0] write_strb_reg;
    reg                  write_last_reg;

    assign write_data_ready = (state == W_GET);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= W_IDLE;

            write_addr_reg <= {ADDR_WIDTH{1'b0}};
            write_len_reg <= 8'd0;
            beat_count_reg <= 8'd0;
            write_id_reg <= {ID_WIDTH{1'b0}};
            write_user_reg <= {USER_WIDTH{1'b0}};

            write_data_reg <= {DATA_WIDTH{1'b0}};
            write_strb_reg <= {STRB_WIDTH{1'b0}};
            write_last_reg <= 1'b0;

            m_axi_awid <= {ID_WIDTH{1'b0}};
            m_axi_awaddr <= {ADDR_WIDTH{1'b0}};
            m_axi_awlen <= 8'd0;
            m_axi_awsize <= AXI_SIZE;
            m_axi_awburst <= 2'b01;
            m_axi_awuser <= {USER_WIDTH{1'b0}};
            m_axi_awvalid <= 1'b0;

            m_axi_wdata <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb <= {STRB_WIDTH{1'b0}};
            m_axi_wlast <= 1'b0;
            m_axi_wuser <= {USER_WIDTH{1'b0}};
            m_axi_wvalid <= 1'b0;

            m_axi_bready <= 1'b0;

            write_busy <= 1'b0;
            write_done <= 1'b0;
            write_resp <= 2'b00;
            write_resp_id <= {ID_WIDTH{1'b0}};
            write_resp_user <= {USER_WIDTH{1'b0}};
        end else begin
            write_done <= 1'b0;

            case (state)

                W_IDLE: begin
                    write_busy <= 1'b0;

                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid <= 1'b0;
                    m_axi_wlast <= 1'b0;
                    m_axi_bready <= 1'b0;

                    if (start_write) begin
                        write_busy <= 1'b1;

                        write_addr_reg <= write_addr;
                        write_len_reg <= write_len;
                        beat_count_reg <= 8'd0;
                        write_id_reg <= write_id;
                        write_user_reg <= write_user;

                        m_axi_awid <= write_id;
                        m_axi_awaddr <= write_addr;
                        m_axi_awlen <= write_len;
                        m_axi_awsize <= AXI_SIZE;
                        m_axi_awburst <= 2'b01;
                        m_axi_awuser <= write_user;
                        m_axi_awvalid <= 1'b1;

                        state <= W_AW;
                    end
                end

                W_AW: begin
                    write_busy <= 1'b1;

                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        state <= W_GET;
                    end
                end

                W_GET: begin
                    write_busy <= 1'b1;

                    if (write_data_valid && write_data_ready) begin
                        write_data_reg <= write_data;
                        write_strb_reg <= write_strb;
                        write_last_reg <=
                            (beat_count_reg == write_len_reg);

                        m_axi_wdata <= write_data;
                        m_axi_wstrb <= write_strb;
                        m_axi_wlast <=
                            (beat_count_reg == write_len_reg);
                        m_axi_wuser <= write_user_reg;
                        m_axi_wvalid <= 1'b1;

                        state <= W_DATA;
                    end
                end

                W_DATA: begin
                    write_busy <= 1'b1;

                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;

                        if (write_last_reg) begin
                            m_axi_wlast <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state <= W_B;
                        end else begin
                            beat_count_reg <= beat_count_reg + 1'b1;

                            write_addr_reg <=
                                write_addr_reg + (1 << AXI_SIZE);

                            state <= W_GET;
                        end
                    end
                end

                W_B: begin
                    write_busy <= 1'b1;

                    if (m_axi_bvalid && m_axi_bready) begin
                        write_resp <= m_axi_bresp;
                        write_resp_id <= m_axi_bid;
                        write_resp_user <= m_axi_buser;

                        m_axi_bready <= 1'b0;
                        write_busy <= 1'b0;
                        write_done <= 1'b1;

                        state <= W_IDLE;
                    end
                end

                default: begin
                    state <= W_IDLE;
                    write_busy <= 1'b0;
                end

            endcase
        end
    end

endmodule