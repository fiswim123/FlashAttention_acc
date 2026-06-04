// =============================================================================
// Module: fa_dma
// Description: AXI4 Master DMA engine for Q/K/V/O data transfer.
//              FSM: IDLE -> ADDR_CALC -> AR_SEND/R_RECV (read) or AW_SEND/W_SEND/B_RECV (write)
// MAS: M03 | Type: io | Deps: fa_buffer_mgr (M07)
// =============================================================================
module fa_dma (
    input  logic        clk,
    input  logic        rst_n,
    // Control interface from fa_ctrl
    input  logic        dma_start,
    output logic        dma_done,
    input  logic [1:0]  dma_cmd,      // 00=Q, 01=K, 10=V, 11=O
    // Base addresses from regfile
    input  logic [63:0] q_base,
    input  logic [63:0] k_base,
    input  logic [63:0] v_base,
    input  logic [63:0] o_base,
    input  logic [31:0] stride,
    input  logic [7:0]  row_cnt,
    input  logic [3:0]  tile_cnt,
    // AXI4 Master Write Address Channel
    output logic [63:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,
    output logic [2:0]  m_axi_awsize,
    output logic [1:0]  m_axi_awburst,
    output logic        m_axi_awvalid,
    input  logic        m_axi_awready,
    // AXI4 Master Write Data Channel
    output logic [127:0] m_axi_wdata,
    output logic [15:0]  m_axi_wstrb,
    output logic         m_axi_wlast,
    output logic         m_axi_wvalid,
    input  logic         m_axi_wready,
    // AXI4 Master Write Response Channel
    input  logic [1:0]  m_axi_bresp,
    input  logic        m_axi_bvalid,
    output logic        m_axi_bready,
    // AXI4 Master Read Address Channel
    output logic [63:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    output logic        m_axi_arvalid,
    input  logic        m_axi_arready,
    // AXI4 Master Read Data Channel
    input  logic [127:0] m_axi_rdata,
    input  logic [1:0]  m_axi_rresp,
    input  logic        m_axi_rlast,
    input  logic        m_axi_rvalid,
    output logic        m_axi_rready,
    // Buffer interface
    output logic        buf_wr_en,
    output logic [11:0] buf_wr_addr,
    output logic [127:0] buf_wr_data,
    output logic        buf_rd_en,
    output logic [11:0] buf_rd_addr,
    input  logic [127:0] buf_rd_data
);

    // =========================================================================
    // DMA Commands
    // =========================================================================
    localparam CMD_Q = 2'b00;
    localparam CMD_K = 2'b01;
    localparam CMD_V = 2'b10;
    localparam CMD_O = 2'b11;

    // =========================================================================
    // FSM States
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE      = 3'b000,
        ADDR_CALC = 3'b001,
        AR_SEND   = 3'b010,
        R_RECV    = 3'b011,
        AW_SEND   = 3'b100,
        W_SEND    = 3'b101,
        B_RECV    = 3'b110
    } dma_state_t;

    dma_state_t state, next;

    // =========================================================================
    // Internal Registers
    // =========================================================================
    logic [1:0]  cmd_reg;
    logic [63:0] target_addr;
    logic [7:0]  burst_len;      // awlen/arlen (beats - 1)
    logic [7:0]  beat_cnt;
    logic [11:0] buf_wr_addr_reg;
    logic [11:0] buf_rd_addr_reg;
    logic [63:0] base_addr;

    // =========================================================================
    // FSM: State register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next;
    end

    // =========================================================================
    // FSM: Next state logic
    // =========================================================================
    always_comb begin
        next = state;
        case (state)
            IDLE: begin
                if (dma_start)
                    next = ADDR_CALC;
            end
            ADDR_CALC: begin
                if (cmd_reg == CMD_O)
                    next = AW_SEND;
                else
                    next = AR_SEND;
            end
            AR_SEND: begin
                if (m_axi_arready)
                    next = R_RECV;
            end
            R_RECV: begin
                if (m_axi_rlast && m_axi_rvalid)
                    next = IDLE;
            end
            AW_SEND: begin
                if (m_axi_awready)
                    next = W_SEND;
            end
            W_SEND: begin
                if (m_axi_wlast && m_axi_wready)
                    next = B_RECV;
            end
            B_RECV: begin
                if (m_axi_bvalid)
                    next = IDLE;
            end
            default: next = IDLE;
        endcase
    end

    // =========================================================================
    // Address generation
    // =========================================================================
    // Select base address based on command
    always_comb begin
        case (cmd_reg)
            CMD_Q: base_addr = q_base + 64'(row_cnt) * stride;
            CMD_K: base_addr = k_base + 64'(tile_cnt) * 16 * stride;
            CMD_V: base_addr = v_base + 64'(tile_cnt) * 16 * stride;
            CMD_O: base_addr = o_base + 64'(row_cnt) * stride;
        endcase
    end

    // Burst length calculation
    // Q: 128 bytes = 8 beats (arlen=7), K/V: 256 bytes = 16 beats (arlen=15), O: 128 bytes = 8 beats
    always_comb begin
        case (cmd_reg)
            CMD_Q: burst_len = 8'd7;
            CMD_K: burst_len = 8'd15;
            CMD_V: burst_len = 8'd15;
            CMD_O: burst_len = 8'd7;
        endcase
    end

    // =========================================================================
    // Command latch and address register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_reg        <= 2'b00;
            target_addr    <= 64'h0;
            beat_cnt       <= 8'h0;
            buf_wr_addr_reg <= 12'h0;
            buf_rd_addr_reg <= 12'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (dma_start) begin
                        cmd_reg <= dma_cmd;
                    end
                end
                ADDR_CALC: begin
                    target_addr <= base_addr;
                    beat_cnt    <= 8'h0;
                    buf_wr_addr_reg <= 12'h0;
                    buf_rd_addr_reg <= 12'h0;
                end
                R_RECV: begin
                    if (m_axi_rvalid) begin
                        beat_cnt <= beat_cnt + 1'b1;
                        buf_wr_addr_reg <= buf_wr_addr_reg + 1'b1;
                    end
                end
                W_SEND: begin
                    if (m_axi_wready) begin
                        beat_cnt <= beat_cnt + 1'b1;
                        buf_rd_addr_reg <= buf_rd_addr_reg + 1'b1;
                    end
                end
                default: ;
            endcase
        end
    end

    // =========================================================================
    // AXI4 Read Address Channel
    // =========================================================================
    assign m_axi_araddr  = target_addr;
    assign m_axi_arlen   = burst_len;
    assign m_axi_arsize  = 3'b100;  // 16 bytes (128-bit)
    assign m_axi_arburst = 2'b01;   // INCR burst
    assign m_axi_arvalid = (state == AR_SEND);

    // =========================================================================
    // AXI4 Read Data Channel -> Buffer Write
    // =========================================================================
    assign m_axi_rready  = (state == R_RECV);
    assign buf_wr_en     = (state == R_RECV) && m_axi_rvalid;
    assign buf_wr_addr   = buf_wr_addr_reg;
    assign buf_wr_data   = m_axi_rdata;

    // =========================================================================
    // AXI4 Write Address Channel
    // =========================================================================
    assign m_axi_awaddr  = target_addr;
    assign m_axi_awlen   = burst_len;
    assign m_axi_awsize  = 3'b100;  // 16 bytes (128-bit)
    assign m_axi_awburst = 2'b01;   // INCR burst
    assign m_axi_awvalid = (state == AW_SEND);

    // =========================================================================
    // AXI4 Write Data Channel <- Buffer Read
    // =========================================================================
    assign buf_rd_en     = (state == W_SEND) && m_axi_wready;
    assign buf_rd_addr   = buf_rd_addr_reg;
    assign m_axi_wdata   = buf_rd_data;
    assign m_axi_wstrb   = 16'hFFFF;
    assign m_axi_wlast   = (state == W_SEND) && (beat_cnt == burst_len);
    assign m_axi_wvalid  = (state == W_SEND);

    // =========================================================================
    // AXI4 Write Response Channel
    // =========================================================================
    assign m_axi_bready  = (state == B_RECV);

    // =========================================================================
    // DMA done signal
    // =========================================================================
    // Assert dma_done for one cycle when returning to IDLE from R_RECV or B_RECV
    logic dma_done_pulse;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dma_done_pulse <= 1'b0;
        else
            dma_done_pulse <= (state == R_RECV && m_axi_rlast && m_axi_rvalid) ||
                              (state == B_RECV && m_axi_bvalid);
    end

    assign dma_done = dma_done_pulse;

endmodule
