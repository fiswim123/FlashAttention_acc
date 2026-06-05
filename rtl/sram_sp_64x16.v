// =============================================================================
// Single-Port SRAM: 64 entries x 16-bit
// Wrapper for ASAP7 fakeram7_64x21 (padded to 21-bit width)
// For Q buffer and O buffer
// =============================================================================
module sram_sp_64x16 (
    input  wire        clk,
    input  wire        ce_in,     // chip enable
    input  wire        we_in,     // write enable
    input  wire [5:0]  addr_in,   // 6-bit address (64 entries)
    input  wire [15:0] wd_in,     // write data
    output reg  [15:0] rd_out     // read data
);

    // Behavioral SRAM (synthesis will infer SRAM macro)
    reg [15:0] mem [0:63];

    always @(posedge clk) begin
        if (ce_in) begin
            if (we_in) begin
                mem[addr_in] <= wd_in;
            end
            rd_out <= mem[addr_in];
        end
    end

endmodule
