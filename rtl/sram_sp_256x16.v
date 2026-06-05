// =============================================================================
// Single-Port SRAM: 256 entries x 16-bit
// Wrapper for ASAP7 fakeram7_256x32 (padded to 32-bit width)
// For exp LUT ROM
// =============================================================================
module sram_sp_256x16 (
    input  wire        clk,
    input  wire        ce_in,     // chip enable
    input  wire        we_in,     // write enable (unused for ROM)
    input  wire [7:0]  addr_in,   // 8-bit address (256 entries)
    input  wire [15:0] wd_in,     // write data (unused for ROM)
    output reg  [15:0] rd_out     // read data
);

    // ROM initialized with exp values
    reg [15:0] mem [0:255];

    // Initialize with approximate exp values
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            mem[i] = i[15:0];
        for (i = 64; i < 128; i = i + 1)
            mem[i] = (i - 64) * 4 + 64;
        for (i = 128; i < 192; i = i + 1)
            mem[i] = (i - 128) * 16 + 320;
        for (i = 192; i < 256; i = i + 1)
            mem[i] = (i - 192) * 64 + 1344;
    end

    always @(posedge clk) begin
        if (ce_in) begin
            rd_out <= mem[addr_in];
        end
    end

endmodule
