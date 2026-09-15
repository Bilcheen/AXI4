`timescale 1ns/1ps

module axi_read_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4,
    parameter USER_WIDTH = 1,
    parameter MEMORY_DEPTH = 256
)(
    input wire clk,
    input wire rst,

    input wire [ID_WIDTH-1:0]     s_axi_arid,
    input wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input wire [7:0]              s_axi_arlen,
    input wire [2:0]              s_axi_arsize,
    input wire [1:0]              s_axi_arburst,
    input wire [USER_WIDTH-1:0]   s_axi_aruser,
    input wire                    s_axi_arvalid,
    output wire                   s_axi_arready,

    output reg [ID_WIDTH-1:0]     s_axi_rid,
    output reg [DATA_WIDTH-1:0]   s_axi_rdata,
    output reg [1:0]              s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg [USER_WIDTH-1:0]   s_axi_ruser,
    output reg                    s_axi_rvalid,
    input wire                    s_axi_rready,

    output reg [$clog2(MEMORY_DEPTH)-1:0] mem_rd_addr,
    input wire [DATA_WIDTH-1:0]           mem_rd_data
);

    localparam integer ADDR_SHIFT = $clog2(DATA_WIDTH / 8);
    localparam [1:0] S_IDLE = 2'd0, S_DATA = 2'd1;

    reg [1:0] state;
    reg [7:0] read_len_reg;
    reg [7:0] read_beat_count;
    reg [2:0] read_size_reg;
    reg [1:0] read_burst_reg;
    reg [ADDR_WIDTH-1:0] read_addr_reg;
    reg [ID_WIDTH-1:0] read_id_reg;
    reg [USER_WIDTH-1:0] read_user_reg;

    wire [ADDR_WIDTH-1:0] beat_bytes =
        ({{(ADDR_WIDTH-1){1'b0}}, 1'b1} << read_size_reg);
    wire [ADDR_WIDTH-1:0] next_read_addr = read_addr_reg + beat_bytes;

    assign s_axi_arready = (state == S_IDLE);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            read_len_reg <= 8'd0;
            read_beat_count <= 8'd0;
            read_size_reg <= 3'd0;
            read_burst_reg <= 2'b01;
            read_addr_reg <= {ADDR_WIDTH{1'b0}};
            read_id_reg <= {ID_WIDTH{1'b0}};
            read_user_reg <= {USER_WIDTH{1'b0}};
            s_axi_rid <= {ID_WIDTH{1'b0}};
            s_axi_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_rresp <= 2'b00;
            s_axi_rlast <= 1'b0;
            s_axi_ruser <= {USER_WIDTH{1'b0}};
            s_axi_rvalid <= 1'b0;
            mem_rd_addr <= {($clog2(MEMORY_DEPTH)){1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    s_axi_rvalid <= 1'b0;
                    if (s_axi_arvalid && s_axi_arready) begin
                        read_len_reg <= s_axi_arlen;
                        read_beat_count <= 8'd0;
                        read_size_reg <= s_axi_arsize;
                        read_burst_reg <= s_axi_arburst;
                        read_addr_reg <= s_axi_araddr;
                        read_id_reg <= s_axi_arid;
                        read_user_reg <= s_axi_aruser;
                        mem_rd_addr <= s_axi_araddr[
                            ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1:
                            ADDR_SHIFT
                        ];
                        state <= S_DATA;
                    end
                end

                S_DATA: begin
                    if (!s_axi_rvalid) begin
                        s_axi_rid <= read_id_reg;
                        s_axi_rdata <= mem_rd_data;
                        s_axi_rresp <= 2'b00;
                        s_axi_rlast <= (read_beat_count == read_len_reg);
                        s_axi_ruser <= read_user_reg;
                        s_axi_rvalid <= 1'b1;
                    end else if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        if (read_beat_count == read_len_reg) begin
                            s_axi_rlast <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            read_beat_count <= read_beat_count + 1'b1;
                            case (read_burst_reg)
                                2'b00: read_addr_reg <= read_addr_reg;
                                default: read_addr_reg <= read_addr_reg + beat_bytes;
                            endcase
                            if (read_burst_reg == 2'b00)
                                mem_rd_addr <= read_addr_reg[
                                    ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1:
                                    ADDR_SHIFT
                                ];
                            else
                                mem_rd_addr <= next_read_addr[
                                    ADDR_SHIFT + $clog2(MEMORY_DEPTH) - 1:
                                    ADDR_SHIFT
                                ];
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                    s_axi_rvalid <= 1'b0;
                end
            endcase
        end
    end
endmodule