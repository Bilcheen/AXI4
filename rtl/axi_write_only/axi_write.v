module axi #(
    parameter ID_WIDTH = 4,
    parameter DATA_WIDTH = 32,
    parameter USER_WIDTH = 1
)(
    input wire clk,
    input wire rst,

    //=========================
    //AXI4 Write Address(AW) Channel
    //=========================
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    input wire [31:0] s_axi_awaddr,
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire [3:0] s_axi_awcache,
    input wire [2:0] s_axi_awprot,
    input wire [ID_WIDTH-1:0] s_axi_awid,
    input wire [7:0] s_axi_awlen,
    input wire s_axi_awlock,
    //input wire [3:0] s_axi_awlen;    //AXI3
    //input wire [1:0] s_axi_awlock;   //AXI3
    input wire [3:0] s_axi_awqos,
    input wire [3:0] s_axi_awregion,
    input wire [USER_WIDTH-1:0] s_axi_awuser,

    //=========================
    //AXI4 Write Data(W) Channel
    //=========================
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    input wire s_axi_wlast,
    input wire [DATA_WIDTH-1:0] s_axi_wdata,
    input wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    //input wire [ID_WIDTH-1:0] s_axi_wid   //AXI3
    input wire [USER_WIDTH-1:0] s_axi_wuser,

    //=========================
    //AXI4 Write Response(B) Channel
    //=========================
    output reg s_axi_bwvalid,
    input wire s_axi_bwready,
    output reg [1:0] s_axi_bresp,
    output reg [ID_WIDTH-1:0] s_axi_bid,
    output reg [USER_WIDTH-1:0] s_axi_buser,

    //=========================
    //Debug Memory Interface
    //=========================
    output wire [DATA_WIDTH-1:0] debug_memory_data,
    input wire [7:0] debug_memory_addr
);

/* ==========================
    AXI4 Write Address(AW) Channel
    ==========================
    1. rst -> aw_active = 0, s_axi_awready = 1
    2. s_axi_awvalid = 1, s_axi_awready = 1, -> aw_handshake
    3. aw_active = 1, wready = 1
    4. wait wdata channel handshake
    5. s_axi_wvalid = 1, s_axi_wready = 1, -> w_handshake
    6. 接收WDATA
    7. check WSTRB bit
    8. write byte
*/
localparam integer STRB_WIDTH = DATA_WIDTH / 8;
localparam integer MEMORY_DEPTH = 256;

reg aw_active;
reg [31:0] awaddr_reg;
reg [2:0] awsize_reg;
reg [1:0] awburst_reg;
reg [7:0] awlen_reg;
reg [ID_WIDTH-1:0] awid_reg;
reg [USER_WIDTH-1:0] awuser_reg;
reg [DATA_WIDTH-1:0] memory [0:MEMORY_DEPTH-1];
reg [7:0] boat_count;
integer i;

assign s_axi_awready = !aw_active && !s_axi_bwvalid;
assign s_axi_wready = aw_active && !s_axi_bwvalid;


assign debug_memory_data = memory[debug_memory_addr];

//AW Channel
always @(posedge clk) begin
    if (rst) begin
        aw_active <= 1'b0;
        awaddr_reg <= 32'b0;
        awsize_reg <= 3'b0;
        awburst_reg <= 2'b0;
        awlen_reg <= 8'b0;
        awid_reg <= {ID_WIDTH{1'b0}};
        awuser_reg <= {USER_WIDTH{1'b0}};

        s_axi_bwvalid <= 1'b0;
        s_axi_bresp   <= 2'b00;
        s_axi_bid     <= {ID_WIDTH{1'b0}};
        s_axi_buser   <= {USER_WIDTH{1'b0}};
    end else begin
        if (s_axi_awvalid && s_axi_awready) begin //aw handshake
            aw_active <= 1'b1;
            awaddr_reg <= s_axi_awaddr;
            awsize_reg <= s_axi_awsize;
            awburst_reg <= s_axi_awburst;
            awlen_reg <= s_axi_awlen;
            awid_reg <= s_axi_awid;
            awuser_reg <= s_axi_awuser;
        end 
    end
end

//W Channel
always @(posedge clk) begin
    if (!rst) begin
        if (s_axi_wvalid && s_axi_wready) begin
            for (i = 0; i < STRB_WIDTH; i = i + 1) begin
                if (s_axi_wstrb[i]) begin
                    memory[awaddr_reg[9:2]][i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                end
            end
        end
    end
end

//B Channel
always @(posedge clk) begin
    if (!rst) begin
        if (s_axi_bwvalid && s_axi_bwready) begin
            s_axi_bwvalid <= 1'b0;
        end

        if (s_axi_wvalid && s_axi_wready && s_axi_wlast) begin
            aw_active     <= 1'b0;
            s_axi_bwvalid <= 1'b1;
            s_axi_bresp   <= 2'b00; //OKAY
            s_axi_bid     <= awid_reg;
            s_axi_buser   <= awuser_reg;
        end
    end
end

endmodule



