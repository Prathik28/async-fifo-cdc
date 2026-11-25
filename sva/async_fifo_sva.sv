// Assertions bound into the DUT, so the RTL stays free of verification code.
module fifo_wr_sva #(parameter int ADDR_WIDTH = 4) (
    input logic                wclk,
    input logic                wrst_n,
    input logic                winc,
    input logic                wfull,
    input logic                woverflow,
    input logic [ADDR_WIDTH:0] wbin,
    input logic [ADDR_WIDTH:0] wgray,
    input logic [ADDR_WIDTH:0] wlevel
);
    // Overflow: a write while full must not move the pointer, and must be reported.
    a_no_overflow: assert property (@(posedge wclk) disable iff (!wrst_n)
        wfull |=> $stable(wbin))
        else $error("write pointer moved while full");
    a_overflow_flag: assert property (@(posedge wclk) disable iff (!wrst_n)
        winc && wfull |=> woverflow)
        else $error("refused write not reported");

    // Pointer coherency: Gray register matches binary, one bit changes at a time.
    a_wgray_matches_bin: assert property (@(posedge wclk) disable iff (!wrst_n)
        wgray == (wbin ^ (wbin >> 1)))
        else $error("wgray does not encode wbin");
    a_wgray_one_bit: assert property (@(posedge wclk) disable iff (!wrst_n)
        1'b1 |=> $onehot0(wgray ^ $past(wgray)))
        else $error("more than one wgray bit changed");

    a_wlevel_range: assert property (@(posedge wclk) disable iff (!wrst_n)
        int'(wlevel) <= (1 << ADDR_WIDTH))
        else $error("wlevel above depth");

    c_full:     cover property (@(posedge wclk) disable iff (!wrst_n) wfull);
    c_overflow: cover property (@(posedge wclk) disable iff (!wrst_n) winc && wfull);
endmodule

module fifo_rd_sva #(parameter int ADDR_WIDTH = 4) (
    input logic                  rclk,
    input logic                  rrst_n,
    input logic                  rinc,
    input logic                  rempty,
    input logic                  runderflow,
    input logic [ADDR_WIDTH:0]   rbin,
    input logic [ADDR_WIDTH:0]   rgray,
    input logic [ADDR_WIDTH:0]   rlevel
);
    // Underflow: a read while empty must not move the pointer, and must be reported.
    a_no_underflow: assert property (@(posedge rclk) disable iff (!rrst_n)
        rempty |=> $stable(rbin))
        else $error("read pointer moved while empty");
    a_underflow_flag: assert property (@(posedge rclk) disable iff (!rrst_n)
        rinc && rempty |=> runderflow)
        else $error("refused read not reported");

    a_rgray_matches_bin: assert property (@(posedge rclk) disable iff (!rrst_n)
        rgray == (rbin ^ (rbin >> 1)))
        else $error("rgray does not encode rbin");
    a_rgray_one_bit: assert property (@(posedge rclk) disable iff (!rrst_n)
        1'b1 |=> $onehot0(rgray ^ $past(rgray)))
        else $error("more than one rgray bit changed");

    a_rlevel_range: assert property (@(posedge rclk) disable iff (!rrst_n)
        int'(rlevel) <= (1 << ADDR_WIDTH))
        else $error("rlevel above depth");

    c_empty:     cover property (@(posedge rclk) disable iff (!rrst_n) rempty);
    c_underflow: cover property (@(posedge rclk) disable iff (!rrst_n) rinc && rempty);
endmodule

bind wptr_full fifo_wr_sva #(.ADDR_WIDTH(ADDR_WIDTH)) u_sva (
    .wclk, .wrst_n, .winc, .wfull, .woverflow, .wbin, .wgray, .wlevel);

bind rptr_empty fifo_rd_sva #(.ADDR_WIDTH(ADDR_WIDTH)) u_sva (
    .rclk, .rrst_n, .rinc, .rempty, .runderflow, .rbin, .rgray, .rlevel);
