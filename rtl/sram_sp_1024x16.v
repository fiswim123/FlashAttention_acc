// =============================================================================
// Single-Port SRAM: 1024 entries x 16-bit
// Wrapper for ASAP7 fakeram7_2048x39 (padded to 39-bit width, use 2 banks)
// For K tile buffer and V tile buffer (dual-buffered)
// =============================================================================
module sram_sp_1024x16 (
    input  wire         clk,
    input  wire         ce_in,     // chip enable
    input  wire         we_in,     // write enable
    input  wire [9:0]   addr_in,   // 10-bit address (1024 entries)
    input  wire [15:0]  wd_in,     // write data
    output reg  [15:0]  rd_out     // read data
);

    // Behavioral SRAM (synthesis will infer SRAM macro)
    reg [15:0] mem [0:1023];

    always @(posedge clk) begin
        if (ce_in) begin
            if (we_in) begin
                mem[addr_in] <= wd_in;
            end
            rd_out <= mem[addr_in];
        end
    end

endmodule
