`timescale 1ns/1ps
// Self-checking testbench. Clock periods are set at run time in picoseconds:
//   +WPER=10000 +RPER=23000 +SEED=1
// Runs on Verilator (with the bound assertions in sva/) and on Icarus Verilog.
module tb_async_fifo #(
    parameter int DATA_WIDTH  = 8,
    parameter int ADDR_WIDTH  = 4,
    parameter int SYNC_STAGES = 2
);
    localparam int DEPTH  = 1 << ADDR_WIDTH;
    localparam int AFULL  = DEPTH - 2;
    localparam int AEMPTY = 2;
    localparam int RANDOM_CYCLES = 4000;

    logic arst_n = 1'b1, wclk = 1'b0, rclk = 1'b0, winc = 1'b0, rinc = 1'b0;
    logic [DATA_WIDTH-1:0] wdata = '0;
    logic [DATA_WIDTH-1:0] rdata;
    logic wfull, walmost_full, woverflow, rempty, ralmost_empty, runderflow;
    logic [ADDR_WIDTH:0] wlevel, rlevel;

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .SYNC_STAGES(SYNC_STAGES),
        .AFULL_THRESH(AFULL), .AEMPTY_THRESH(AEMPTY)
    ) dut (.*);

    int wper = 10000, rper = 10000, seed = 1;
    int errors = 0;

    initial begin
        int unused;
        if ($value$plusargs("WPER=%d", wper)) ;
        if ($value$plusargs("RPER=%d", rper)) ;
        if ($value$plusargs("SEED=%d", seed)) ;
        begin
            int s;
            s = seed; // some simulators update the seed argument in place
            unused = $urandom(s);
        end
        fork
            forever #(wper / 2000.0) wclk = ~wclk;
            begin
                #3.3; // phase offset between the domains
                forever #(rper / 2000.0) rclk = ~rclk;
            end
        join
    end

    task automatic check(input bit ok, input string what);
        if (!ok) begin
            errors++;
            if (errors <= 20) $display("ERROR @%0t: %s", $time, what);
        end
    endtask

    // ---- Scoreboard: an independent reference queue --------------------------
    logic [DATA_WIDTH-1:0] model [0:DEPTH-1];
    int pushes = 0, pops = 0;
    int n_over = 0, n_under = 0, n_full = 0, n_empty_after_data = 0;
    bit expect_over = 0, expect_under = 0;

    always @(posedge wclk) if (arst_n) begin
        if (winc && !wfull) begin
            check(pushes - pops < DEPTH, "write accepted while FIFO truly full");
            model[pushes % DEPTH] = wdata;
            pushes = pushes + 1;
        end
        expect_over = winc && wfull;
        if (wfull) n_full++;
    end

    always @(posedge rclk) if (arst_n) begin
        if (rinc && !rempty) begin
            check(pushes - pops > 0, "read accepted while FIFO truly empty");
            check(rdata === model[pops % DEPTH], "read data mismatch or out of order");
            pops = pops + 1;
            if (pushes == pops) n_empty_after_data++;
        end
        expect_under = rinc && rempty;
    end

    // Flags are sampled on falling edges, after all register updates have settled.
    // The reference model is cleared by reset, so these hold only out of reset.
    always @(negedge wclk) if (arst_n && dut.wrst_n) begin
        check(woverflow === expect_over, "woverflow does not match refused write");
        if (woverflow) n_over++;
        check(int'(wlevel) >= pushes - pops, "wlevel below true fill level");
        check(int'(wlevel) <= DEPTH, "wlevel above depth");
        if (!wfull) check(walmost_full === (int'(wlevel) >= AFULL), "walmost_full wrong");
    end

    always @(negedge rclk) if (arst_n && dut.rrst_n) begin
        check(runderflow === expect_under, "runderflow does not match refused read");
        if (runderflow) n_under++;
        check(int'(rlevel) <= pushes - pops, "rlevel above true fill level");
        if (!rempty) check(ralmost_empty === (int'(rlevel) <= AEMPTY), "ralmost_empty wrong");
    end

    // ---- Stimulus --------------------------------------------------------------
    int w_pct = 0, r_pct = 0; // request probability per cycle

    function automatic bit chance(input int pct);
        return int'($urandom % 100) < pct;
    endfunction

    function automatic logic [DATA_WIDTH-1:0] random_data();
        logic [95:0] r;
        r = {$urandom, $urandom, $urandom};
        return r[DATA_WIDTH-1:0];
    endfunction

    always @(negedge wclk) begin
        winc  <= chance(w_pct);
        wdata <= random_data();
    end
    always @(negedge rclk) rinc <= chance(r_pct);

    task automatic wcycles(input int n); repeat (n) @(posedge wclk); endtask
    task automatic rcycles(input int n); repeat (n) @(posedge rclk); endtask

    // Let both pointer crossings finish.
    task automatic settle();
        rcycles(SYNC_STAGES + 4);
        wcycles(SYNC_STAGES + 4);
        rcycles(SYNC_STAGES + 4);
    endtask

    task automatic apply_reset();
        int longest;
        // Change reset between clock edges so the testbench cannot race the DUT.
        @(negedge wclk);
        #0.001;
        w_pct = 0; r_pct = 0;
        winc = 0; rinc = 0;
        arst_n = 0;
        pushes = 0; pops = 0; expect_over = 0; expect_under = 0;
        longest = (wper > rper) ? wper : rper;
        #(longest * 3 / 1000.0 + 0.001);
        check(wfull === 1'b1 && rempty === 1'b1, "flags wrong during reset");
        check(wlevel === '0 && rlevel === '0, "levels not cleared by reset");
        arst_n = 1;
        settle();
        check(wfull === 1'b0, "wfull stuck after reset");
        check(rempty === 1'b1, "rempty low after reset");
    endtask

    task automatic fill_and_overflow();
        r_pct = 0; w_pct = 100;
        wcycles(DEPTH + 10);
        w_pct = 0;
        settle();
        check(pushes - pops == DEPTH, "FIFO did not accept exactly DEPTH words");
        check(wfull === 1'b1 && walmost_full === 1'b1, "full flags not set when full");
        check(int'(wlevel) == DEPTH && int'(rlevel) == DEPTH, "levels wrong when full");
        check(rempty === 1'b0 && ralmost_empty === 1'b0, "empty flags set when full");
    endtask

    task automatic drain_and_underflow();
        w_pct = 0; r_pct = 100;
        rcycles(DEPTH + 10);
        r_pct = 0;
        settle();
        check(pushes == pops, "FIFO did not drain");
        check(rempty === 1'b1 && ralmost_empty === 1'b1, "empty flags not set when empty");
        check(wfull === 1'b0 && walmost_full === 1'b0, "full flags set when empty");
        check(wlevel === '0 && rlevel === '0, "levels wrong when empty");
    endtask

    task automatic random_traffic(input int wp, input int rp);
        w_pct = wp; r_pct = rp;
        wcycles(RANDOM_CYCLES);
        w_pct = 0; r_pct = 0;
        settle();
    endtask

    initial begin
        #1;
        apply_reset();
        repeat (3) begin
            fill_and_overflow();
            drain_and_underflow();
        end
        random_traffic(90, 30);  // pressure toward full
        random_traffic(30, 90);  // pressure toward empty
        random_traffic(60, 60);
        random_traffic(100, 100);

        // Reset in the middle of traffic, then prove the FIFO recovers.
        w_pct = 80; r_pct = 50;
        wcycles(57);
        apply_reset();
        random_traffic(70, 70);
        drain_and_underflow();
        fill_and_overflow();
        drain_and_underflow();

        // The run only counts if the corner cases were actually reached.
        check(n_full > 0,             "coverage: never reached full");
        check(n_empty_after_data > 0, "coverage: never drained to empty");
        check(n_over > 0,             "coverage: overflow never exercised");
        check(n_under > 0,            "coverage: underflow never exercised");
        check(pushes > DEPTH * 4,     "coverage: pointers did not wrap");

        $display("DW=%0d AW=%0d STAGES=%0d WPER=%0d RPER=%0d SEED=%0d: %0d writes since last reset, %0d overflows, %0d underflows, %0d errors",
                 DATA_WIDTH, ADDR_WIDTH, SYNC_STAGES, wper, rper, seed, pushes, n_over, n_under, errors);
        if (errors == 0) $display("TEST PASSED");
        else             $fatal(1, "TEST FAILED");
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "TEST FAILED: watchdog timeout");
    end
endmodule
