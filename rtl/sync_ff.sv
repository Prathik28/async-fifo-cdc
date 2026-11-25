// Multi-flop synchronizer for a Gray-coded bus crossing into the clk domain.
// Safe for multi-bit use only because the source changes one bit per source edge.
module sync_ff #(
    parameter int WIDTH  = 5,
    parameter int STAGES = 2
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    // ASYNC_REG keeps the chain together and unoptimised in Vivado.
    (* ASYNC_REG = "TRUE" *) logic [STAGES*WIDTH-1:0] chain;

    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) chain <= '0;
        else        chain <= {chain[(STAGES-1)*WIDTH-1:0], d};

    assign q = chain[STAGES*WIDTH-1 -: WIDTH];
endmodule
