# AXI4 System (Verilog Implementation)

本專案實作了一套基於 **AMBA AXI4 (Advanced eXtensible Interface 4)** 通訊協定的 Master 與 Slave 控制架構。設計從單通道獨立模組出發，逐步解耦、驗證，最終整合成完整的 AXI4 讀寫系統，並透過 Icarus Verilog (`iverilog`) 與 GTKWave 完成驗證。

---

## 📌 系統特性與支援規範

* **Protocol**: AMBA AXI4 Memory-Mapped 規格。
* **匯流排架構**:
  * 獨立 5 通道交握機制：Write Address (`AW`)、Write Data (`W`)、Write Response (`B`)、Read Address (`AR`)、Read Data (`R`)。
  * 支援非對稱傳輸握手 (`VALID` / `READY`)。
* **功能支援**:
  * **Burst Types**: 支援 `FIXED` (2'b00) 與 `INCR` (2'b01) 突發傳輸模式。
  * **Byte Masking**: 支援寫入資料 Strobe 遮罩 (`WSTRB`) 局部寫入。
  * **Multi-Beat Burst**: 完整支援多拍 Burst 傳輸與 `WLAST` / `RLAST` 標記判定。
  * **Backpressure**: 具備回應通道 (`B`) 與資料通道 (`R`) 的 Slave/Master 端背壓等待機制。
  * **Sideband Signals**: 支援可自訂寬度之 Transaction ID (`AWID`/`ARID`/`BID`/`RID`) 與 Sideband User 信號 (`USER`)。

---

## 🚀 實現計畫與開發路程

* **Phase 1: Write 通道獨立開發與驗證**
  * 實作純寫入模組 (`axi_write_only`)，聚焦於 `AW` 與 `W` 通道的狀態轉換。

* **Phase 2: Read 通道獨立開發與驗證**
  * 實作純讀取模組 (`axi_read_only`)，鎖定 `AR` 位址請求與 `R` 資料返回機制。

* **Phase 3: Write Master / Slave 狀態機獨立模組化**
  * 將寫入邏輯拆分為標準 Master 控制器 (`axi_write_master.v`) 與 Slave 介面 (`axi_write_slave.v`)。
  * 實作 Local 驅動介面與 `B Channel` 回應狀態檢查。

* **Phase 4: Read Master / Slave 狀態機獨立模組化**
  * 拆分讀取邏輯為 `axi_read_master.v` 與 `axi_read_slave.v`。
  * Slave 連接外部 SRAM 讀取介面，Master 端提供串流輸出與 Valid/Ready 交握。

* **Phase 5: 頂層 AXI Master 與 Slave 系統整合**
  * 整合頂層 `axi_master.v` 與 `axi_slave.v`，封裝完整 5 條通道互連匯流排。

* **Phase 6: Vivado 硬體系統整合與 ZCU104 (PYNQ) 板端實體驗證**
  * **Block Design 系統整合**：
    * 於 Vivado IP Integrator 建立 Block Design，加入 **Zynq UltraScale+ MPSoC 處理系統核心（針對 ZCU104 開發板配置）。
    * 透過 **AXI SmartConnect / AXI Interconnect** IP 將 PS Master 連接至`axi_master.v`與`axi_slave`。
    * 將 Slave 的內部記憶體介面連接至 FPGA Block RAM (BRAM)。
  * **實體合成、實現與 Bitstream 生成**：
    * 執行 Synthesis、Place & Route (Implementation)，確保時序收斂（Timing Closure，滿足 Slack > 0）。
    * 匯出硬體手體檔，產生包含硬體邏輯的 `.bit` 檔與硬體描述檔 `.hwh`。
  * **PYNQ Jupyter Notebook 實體測試 (PS-PL 互動驗證)**：
    * 將 `.bit` 與 `.hwh` 上傳至運行 PYNQ Linux 映像檔的 ZCU104 開發板。
    * 透過 Python `pynq` 套件的 `Overlay` 物件載入 Bitstream驗證

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
└── test_tool/                     # Gatewave與iVerilog tool測試
    ├── test_tb.v                  
    ├── test.v                     
    ├── test.txt                   
    ├── test.vcd                   
    └── wave               
```