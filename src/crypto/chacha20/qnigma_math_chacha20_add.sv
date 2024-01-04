module qnigma_math_chacha20_add #(
  parameter bit R = 0,
  parameter int W = 16
)
(
  input  logic         clk,
  input  logic [W-1:0] a,
  input  logic [W-1:0] b,
  output logic [W-1:0] q
);

  generate
    if (R == 0) begin : gen_comb
      assign q = a + b;
    end
    else if (R == 1) begin : gen_ff
      always_ff @ (posedge clk) q <= a + b;
    end
  endgenerate

endmodule
