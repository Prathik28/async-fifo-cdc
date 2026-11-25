// Black-box formal harness. wclk and rclk are completely unconstrained, so the
// proof covers every frequency ratio and phase relationship between them.
module fv_async_fifo #(
    parameter DATA_WIDTH = 2,
    parameter ADDR_WIDTH = 2
) (
    input wire                  arst_n,
    input wire                  wclk,
    input wire                  winc,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire                  rclk,
    input wire                  rinc
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    wire [DATA_WIDTH-1:0] rdata;
    wire                  wfull, walmost_full, woverflow;
    wire                  rempty, ralmost_empty, runderflow;
    wire [ADDR_WIDTH:0]   wlevel, rlevel;

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .arst_n(arst_n),
        .wclk(wclk), .winc(winc), .wdata(wdata), .wfull(wfull),
        .walmost_full(walmost_full), .wlevel(wlevel), .woverflow(woverflow),
        .rclk(rclk), .rinc(rinc), .rdata(rdata), .rempty(rempty),
        .ralmost_empty(ralmost_empty), .rlevel(rlevel), .runderflow(runderflow));

    // Reset is applied at the start and, once released, stays released.
    reg past_valid = 1'b0;
    reg was_released = 1'b0;
    (* gclk *) reg gclk;
    always @(posedge gclk) begin
        past_valid <= 1'b1;
        if (arst_n) was_released <= 1'b1;
    end
    always @* begin
        if (!past_valid)  assume (!arst_n);
        if (was_released) assume (arst_n);
    end

    // Reference counts of accepted transfers, independent of the DUT's pointers.
    reg [ADDR_WIDTH:0] wcount, rcount;
    always @(posedge wclk or negedge arst_n)
        if (!arst_n)               wcount <= 0;
        else if (winc && !wfull)   wcount <= wcount + 1'b1;
    always @(posedge rclk or negedge arst_n)
        if (!arst_n)               rcount <= 0;
        else if (rinc && !rempty)  rcount <= rcount + 1'b1;

    wire [ADDR_WIDTH:0] occupancy = wcount - rcount;

    // Data integrity: follow one arbitrarily chosen transfer through the FIFO.
    // The solver picks the tag, so the result holds for every transfer number.
    (* anyconst *) reg [ADDR_WIDTH:0] tag;
    reg                  stored, consumed;
    reg [DATA_WIDTH-1:0] expected;
    always @(posedge wclk or negedge arst_n)
        if (!arst_n) stored <= 1'b0;
        else if (winc && !wfull && wcount == tag && !stored) begin
            stored   <= 1'b1;
            expected <= wdata;
        end
    always @(posedge rclk or negedge arst_n)
        if (!arst_n) consumed <= 1'b0;
        else if (rinc && !rempty && rcount == tag && stored) consumed <= 1'b1;

    always @* if (past_valid && arst_n) begin
        a_occupancy:  assert (occupancy <= DEPTH);
        a_no_overflow:  assert (wfull  || occupancy < DEPTH);
        a_no_underflow: assert (rempty || occupancy > 0);
        a_wlevel_safe:  assert (wlevel >= occupancy && wlevel <= DEPTH);
        a_rlevel_safe:  assert (rlevel <= occupancy);
        if (stored && !consumed && !rempty && rcount == tag)
            a_data: assert (rdata == expected);
    end

    // Reachability, so the assertions above are not passing vacuously.
    reg seen_full = 1'b0;
    always @(posedge gclk)
        if (!arst_n)    seen_full <= 1'b0;
        else if (wfull && occupancy == DEPTH) seen_full <= 1'b1;
    always @* if (past_valid && arst_n) begin
        c_full:           cover (seen_full);
        c_full_then_empty: cover (seen_full && rempty && occupancy == 0);
        c_tag_through:    cover (consumed);
    end
endmodule
