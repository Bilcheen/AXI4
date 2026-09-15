`timescale 1ns/1ps

module axi_read_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter USER_WIDTH = 1
)(
    input wire clk,
    input wire rst,

    input wire                    start_read,
    input wire [ADDR_WIDTH-1:0]   read_addr,
    input wire [7:0]              read_len,
    input wire [ID_WIDTH-1:0]     read_id,
    input wire [USER_WIDTH-1:0]   read_user,

    output reg [DATA_WIDTH-1:0]   read_data,
    output reg [(DATA_WIDTH/8)-1:0] read_strb,
    output reg                    read_data_valid,
    output reg                    read_data_last,
    input wire                    read_data_ready,
    output reg                    read_busy,
    output reg                    read_done,
    output reg [1:0]              read_resp,
    output reg [ID_WIDTH-1:0]     read_resp_id,
    output reg [USER_WIDTH-1:0]   read_resp_user,

    output reg [ID_WIDTH-1:0]     m_axi_arid,
    output reg [ADDR_WIDTH-1:0]   m_axi_araddr,
    output reg [7:0]              m_axi_arlen,
    output reg [2:0]              m_axi_arsize,
    output reg [1:0]              m_axi_arburst,
    output reg [USER_WIDTH-1:0]   m_axi_aruser,
    output reg                    m_axi_arvalid,
    input wire                    m_axi_arready,

    input wire [ID_WIDTH-1:0]     m_axi_rid,
    input wire [DATA_WIDTH-1:0]   m_axi_rdata,
    input wire [1:0]              m_axi_rresp,
    input wire                    m_axi_rlast,
    input wire [USER_WIDTH-1:0]   m_axi_ruser,
    input wire                    m_axi_rvalid,
    output wire                   m_axi_rready
);

    localparam integer STRB_WIDTH = DATA_WIDTH / 8;
    localparam [2:0] AXI_SIZE = $clog2(STRB_WIDTH);
    localparam [2:0] R_IDLE = 3'd0, R_AR = 3'd1, R_DATA = 3'd2;

    reg [2:0] state;
    reg [7:0] beat_count;

    assign m_axi_rready = (state == R_DATA) &&
                          (!read_data_valid || read_data_ready);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= R_IDLE;
            beat_count <= 8'd0;
            read_data <= {DATA_WIDTH{1'b0}};
            read_strb <= {STRB_WIDTH{1'b0}};
            read_data_valid <= 1'b0;
            read_data_last <= 1'b0;
            read_busy <= 1'b0;
            read_done <= 1'b0;
            read_resp <= 2'b00;
            read_resp_id <= {ID_WIDTH{1'b0}};
            read_resp_user <= {USER_WIDTH{1'b0}};
            m_axi_arid <= {ID_WIDTH{1'b0}};
            m_axi_araddr <= {ADDR_WIDTH{1'b0}};
            m_axi_arlen <= 8'd0;
            m_axi_arsize <= AXI_SIZE;
            m_axi_arburst <= 2'b01;
            m_axi_aruser <= {USER_WIDTH{1'b0}};
            m_axi_arvalid <= 1'b0;
        end else begin
            read_done <= 1'b0;

            if (read_data_valid && read_data_ready) begin
                read_data_valid <= 1'b0;
                if (read_data_last) begin
                    read_data_last <= 1'b0;
                    read_done <= 1'b1;
                    read_busy <= 1'b0;
                    state <= R_IDLE;
                end
            end

            case (state)
                R_IDLE: begin
                    read_busy <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    if (start_read) begin
                        read_busy <= 1'b1;
                        beat_count <= 8'd0;
                        m_axi_arid <= read_id;
                        m_axi_araddr <= read_addr;
                        m_axi_arlen <= read_len;
                        m_axi_arsize <= AXI_SIZE;
                        m_axi_arburst <= 2'b01;
                        m_axi_aruser <= read_user;
                        m_axi_arvalid <= 1'b1;
                        state <= R_AR;
                    end
                end

                R_AR: begin
                    read_busy <= 1'b1;
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state <= R_DATA;
                    end
                end

                R_DATA: begin
                    read_busy <= 1'b1;
                    if (m_axi_rvalid && m_axi_rready) begin
                        read_data <= m_axi_rdata;
                        read_strb <= {STRB_WIDTH{1'b1}};
                        read_data_last <= m_axi_rlast;
                        read_data_valid <= 1'b1;
                        read_resp <= m_axi_rresp;
                        read_resp_id <= m_axi_rid;
                        read_resp_user <= m_axi_ruser;
                        beat_count <= beat_count + 1'b1;
                    end
                end

                default: begin
                    state <= R_IDLE;
                    read_busy <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    read_data_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule