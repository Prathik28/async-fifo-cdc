// Write-domain pointer, full / almost-full flags, fill level and overflow pulse.
module wptr_full #(
    parameter int ADDR_WIDTH   = 4,
    parameter int AFULL_THRESH = (1 << ADDR_WIDTH) - 2
) (
    input  logic                  wclk,
    input  logic                  wrst_n,
    input  logic                  winc,
    input  logic [ADDR_WIDTH:0]   rgray_sync, // read pointer, synchronized to wclk
    output logic                  wen,
    output logic [ADDR_WIDTH-1:0] waddr,
    output logic [ADDR_WIDTH:0]   wgray,
    output logic                  wfull,
    output logic                  walmost_full,
    output logic [ADDR_WIDTH:0]   wlevel,
    output logic                  woverflow
);
    localparam logic [ADDR_WIDTH:0] AFULL = (ADDR_WIDTH+1)'(AFULL_THRESH);

    logic [ADDR_WIDTH:0] wbin, wbin_next, wgray_next, rbin_sync, level_next;
    logic                full_next;

    assign wen        = winc & ~wfull;
    assign waddr      = wbin[ADDR_WIDTH-1:0];
    assign wbin_next  = wbin + (ADDR_WIDTH+1)'(wen);
    assign wgray_next = wbin_next ^ (wbin_next >> 1);

    // Gray to binary: bit i is the XOR of all Gray bits at and above i.
    for (genvar i = 0; i <= ADDR_WIDTH; i++) begin : g_g2b
        assign rbin_sync[i] = ^(rgray_sync >> i);
    end

    // Full: same address, opposite wrap. In Gray code the top two bits differ.
    assign full_next  = wgray_next == {~rgray_sync[ADDR_WIDTH -: 2],
                                        rgray_sync[ADDR_WIDTH-2:0]};
    assign level_next = wbin_next - rbin_sync;

    // Flags reset to "full" so a write attempted during reset is refused.
    always_ff @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin
            wbin         <= '0;
            wgray        <= '0;
            wfull        <= 1'b1;
            walmost_full <= 1'b1;
            wlevel       <= '0;
            woverflow    <= 1'b0;
        end else begin
            wbin         <= wbin_next;
            wgray        <= wgray_next;
            wfull        <= full_next;
            walmost_full <= level_next >= AFULL;
            wlevel       <= level_next;
            woverflow    <= winc & wfull;
        end
endmodule
