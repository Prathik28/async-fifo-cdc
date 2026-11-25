// Parameterized dual-clock FIFO with first-word fall-through read.
//
// rdata is valid whenever rempty is low; assert rinc to consume it.
// A single asynchronous reset is synchronized into each clock domain, so both
// pointers are always reset together. Hold arst_n low for at least one period
// of the slower clock, with both clocks running when it is released.
module async_fifo #(
    parameter int DATA_WIDTH    = 8,
    parameter int ADDR_WIDTH    = 4,                    // depth = 2**ADDR_WIDTH, minimum 2
    parameter int SYNC_STAGES   = 2,                    // minimum 2
    parameter int AFULL_THRESH  = (1 << ADDR_WIDTH) - 2,
    parameter int AEMPTY_THRESH = 2
) (
    input  logic                  arst_n,

    // Write domain
    input  logic                  wclk,
    input  logic                  winc,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic                  wfull,
    output logic                  walmost_full,
    output logic [ADDR_WIDTH:0]   wlevel,    // never lower than the true fill level
    output logic                  woverflow, // one-cycle pulse after a refused write

    // Read domain
    input  logic                  rclk,
    input  logic                  rinc,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  rempty,
    output logic                  ralmost_empty,
    output logic [ADDR_WIDTH:0]   rlevel,    // never higher than the true fill level
    output logic                  runderflow // one-cycle pulse after a refused read
);
`ifndef SYNTHESIS
`ifndef FORMAL
    initial begin
        if (ADDR_WIDTH < 2)  $fatal(1, "async_fifo: ADDR_WIDTH must be >= 2");
        if (SYNC_STAGES < 2) $fatal(1, "async_fifo: SYNC_STAGES must be >= 2");
    end
`endif
`endif

    logic                  wrst_n, rrst_n, wen;
    logic [ADDR_WIDTH-1:0] waddr, raddr;
    logic [ADDR_WIDTH:0]   wgray, rgray, wgray_sync, rgray_sync;

    reset_sync #(.STAGES(SYNC_STAGES)) u_wrst (.clk(wclk), .arst_n(arst_n), .srst_n(wrst_n));
    reset_sync #(.STAGES(SYNC_STAGES)) u_rrst (.clk(rclk), .arst_n(arst_n), .srst_n(rrst_n));

    sync_ff #(.WIDTH(ADDR_WIDTH+1), .STAGES(SYNC_STAGES)) u_sync_r2w (
        .clk(wclk), .rst_n(wrst_n), .d(rgray), .q(rgray_sync));

    sync_ff #(.WIDTH(ADDR_WIDTH+1), .STAGES(SYNC_STAGES)) u_sync_w2r (
        .clk(rclk), .rst_n(rrst_n), .d(wgray), .q(wgray_sync));

    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH), .AFULL_THRESH(AFULL_THRESH)) u_wptr (
        .wclk, .wrst_n, .winc, .rgray_sync, .wen, .waddr, .wgray,
        .wfull, .walmost_full, .wlevel, .woverflow);

    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH), .AEMPTY_THRESH(AEMPTY_THRESH)) u_rptr (
        .rclk, .rrst_n, .rinc, .wgray_sync, .raddr, .rgray,
        .rempty, .ralmost_empty, .rlevel, .runderflow);

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk, .wen, .waddr, .wdata, .raddr, .rdata);
endmodule
