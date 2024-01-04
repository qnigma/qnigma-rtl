module qnigma_add #(
  parameter int W = 16, // operand width
  parameter int C = 1,  // carry width
  parameter int O = W + 1 + $clog2(C+1), // todo check width
  parameter bit R = 0   // register
)
(
  input  logic         clk,
  input  logic [W-1:0] a,
  input  logic [W-1:0] b,
  input  logic [C-1:0] c,
  output logic [O-1:0] q
);

  generate
    if (R == 0) begin : gen_comb
      assign q = a + b + c;
    end
    else if (R == 1) begin : gen_ff
      always_ff @ (posedge clk) q <= a + b + c;
    end
  endgenerate


endmodule
