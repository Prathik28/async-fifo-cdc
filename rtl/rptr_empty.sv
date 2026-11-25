// Read-domain pointer, empty / almost-empty flags, fill level and underflow pulse.
module rptr_empty #(
    parameter int ADDR_WIDTH    = 4,
    parameter int AEMPTY_THRESH = 2
) (
    input  logic                  rclk,
    input  logic                  rrst_n,
    input  logic                  rinc,
    input  logic [ADDR_WIDTH:0]   wgray_sync, // write pointer, synchronized to rclk
    output logic [ADDR_WIDTH-1:0] raddr,
    output logic [ADDR_WIDTH:0]   rgray,
    output logic                  rempty,
    output logic                  ralmost_empty,
    output logic [ADDR_WIDTH:0]   rlevel,
    output logic                  runderflow
);
    localparam logic [ADDR_WIDTH:0] AEMPTY = (ADDR_WIDTH+1)'(AEMPTY_THRESH);

    logic [ADDR_WIDTH:0] rbin, rbin_next, rgray_next, wbin_sync, level_next;
    logic                ren, empty_next;

    assign ren        = rinc & ~rempty;
    assign raddr      = rbin[ADDR_WIDTH-1:0];
    assign rbin_next  = rbin + (ADDR_WIDTH+1)'(ren);
    assign rgray_next = rbin_next ^ (rbin_next >> 1);

    for (genvar i = 0; i <= ADDR_WIDTH; i++) begin : g_g2b
        assign wbin_sync[i] = ^(wgray_sync >> i);
    end

    // Empty: the next read pointer has caught up with the synchronized write pointer.
    assign empty_next = rgray_next == wgray_sync;
    assign level_next = wbin_sync - rbin_next;

    always_ff @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin
            rbin          <= '0;
            rgray         <= '0;
            rempty        <= 1'b1;
            ralmost_empty <= 1'b1;
            rlevel        <= '0;
            runderflow    <= 1'b0;
        end else begin
            rbin          <= rbin_next;
            rgray         <= rgray_next;
            rempty        <= empty_next;
            ralmost_empty <= level_next <= AEMPTY;
            rlevel        <= level_next;
            runderflow    <= rinc & rempty;
        end
endmodule
