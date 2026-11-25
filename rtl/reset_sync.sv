// Reset synchronizer: asserts asynchronously, releases synchronously to clk.
module reset_sync #(
    parameter int STAGES = 2
) (
    input  logic clk,
    input  logic arst_n,
    output logic srst_n
);
    // False positive: the lower bits only feed the shift, and only the top bit
    // is used as an asynchronous reset. Verilator tracks the vector as a whole.
    /* verilator lint_off SYNCASYNCNET */
    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] chain;
    /* verilator lint_on SYNCASYNCNET */

    always_ff @(posedge clk or negedge arst_n)
        if (!arst_n) chain <= '0;
        else         chain <= {chain[STAGES-2:0], 1'b1};

    assign srst_n = chain[STAGES-1];
endmodule
