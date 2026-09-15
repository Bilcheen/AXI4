# AXI Tree

```text
AXI/
├── rtl/
│   ├── axi_read_only/
│   │   ├── axi_read.v             # 讀取專用(AR/R通道)功能
│   │   ├── tb_axi_read.v          # AR/R 完整讀取流程Testbench
│   │   ├── tb_axi_read.vvp        # AR/R測試binary檔
│   │   └── axi_read.vcd           # 波形輸出
│   │
│   ├── axi_write_only/
│   │   ├── axi_write.v            # 寫入專用(AW/W/B通道)功能
│   │   ├── tb_axi_aw.v            # AW 驗證Testbench
│   │   ├── tb_axi_aw.vvp          # AW 測試binary檔
│   │   ├── tb_axi_write.v         # AW/W 完整寫入流程Testbench
│   │   ├── tb_axi_write.vvp       # AW/W測試binary檔
│   │   └── axi_write.vcd          # AW/W波形輸出
│   │
│   ├── axi_master.v               # Top AXI Master（整合讀寫）
│   ├── axi_read_master.v          # AXI 讀取 Master 狀態機
│   ├── axi_read_slave.v           # AXI 讀取 Slave 狀態機
│   ├── axi_slave.v                # Top AXI Slave（整合讀寫）
│   ├── axi_write_master.v         # AXI 寫入 Master 狀態機
│   └── axi_write_slave.v          # AXI 寫入 Slave 狀態機
│
├── tb/
│   ├── tb_axi_read_system.v       # read功能(Master Slave)驗證Testbench
│   ├── tb_axi_write_system.v      # write功能(Master Slave)驗證Testbench
│   └── tb_axi_system.v            # Top層完整Testbench
├── sim/
│   ├── tb_axi_read_system.vvp     # 
│   ├── tb_axi_read_system.vcd     # read功能(Master Slave)波行檔
│   ├── tb_axi_write_system.vvp    # 
│   ├── tb_axi_write_system.vcd    # write功能(Master Slave)波行檔
│   ├── tb_axi_system.vvp          # 
│   └── tb_axi_system.vcd          # Top層完整波行檔
│
└── test_tool/                     # gtkwave與iVerilog tool測試
    ├── test_tb.v                  
    ├── test.v                     
    ├── test.txt                   
    ├── test.vcd                   
    └── wave                       
```