`timescale 1ns/1ps
// Short directed run that produces docs/waveform.svg (see scripts/waveform.sh).
// A 4-deep FIFO is filled, overflowed, drained and underflowed.
module tb_waveform;
    logic       arst_n = 1'b1, wclk = 1'b0, rclk = 1'b0, winc = 1'b0, rinc = 1'b0;
    logic [7:0] wdata = 8'h00;
    logic [7:0] rdata;
    logic       wfull, walmost_full, woverflow, rempty, ralmost_empty, runderflow;
    logic [2:0] wlevel, rlevel;

    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(2)) dut (.*);

    always #5 wclk = ~wclk;                     // 10 ns
    initial begin #3; forever #8 rclk = ~rclk; end // 16 ns

    int reads = 0, overflows = 0, underflows = 0, errors = 0;
    always @(posedge rclk) if (rinc && !rempty) begin
        if (rdata !== 8'hA1 + 8'(reads)) errors++;
        reads++;
    end
    always @(posedge woverflow)  overflows++;
    always @(posedge runderflow) underflows++;

    string vcd = "waveform.vcd";

    initial begin
        if ($value$plusargs("VCD=%s", vcd)) ;
        #1 arst_n = 0;
        #40 arst_n = 1;
        repeat (6) @(negedge rclk);

        @(negedge wclk);
        $dumpfile(vcd);
        $dumpvars(1, tb_waveform);
        @(negedge wclk);

        // Offer five words to a four-word FIFO: the fifth must be refused.
        for (int i = 0; i < 5; i++) begin
            winc = 1; wdata = 8'hA1 + 8'(i);
            @(negedge wclk);
        end
        winc = 0;
        repeat (3) @(negedge rclk);

        // Request five reads of four words: the fifth must be refused.
        rinc = 1;
        repeat (5) @(negedge rclk);
        rinc = 0;
        repeat (5) @(negedge wclk);

        if (errors != 0 || reads != 4 || overflows != 1 || underflows != 1 ||
            wfull !== 1'b0 || rempty !== 1'b1)
            $fatal(1, "waveform run FAILED: reads=%0d overflows=%0d underflows=%0d errors=%0d",
                   reads, overflows, underflows, errors);
        $display("waveform run PASSED: %0d words in order, %0d overflow, %0d underflow",
                 reads, overflows, underflows);
        $finish;
    end
endmodule
