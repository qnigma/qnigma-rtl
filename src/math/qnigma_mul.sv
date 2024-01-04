module qnigma_mul #(
  parameter int W = 16,
  parameter bit R = 0
)
(
  input  logic           clk,
  input  logic [W-1:0]   a,
  input  logic [W-1:0]   b,
  output logic [2*W-1:0] q
);
  
  generate
    if (R == 0) begin : gen_comb
      assign q = a * b;
    end
    else if (R == 1) begin : gen_ff
      always_ff @ (posedge clk) q <= a * b;
    end
  endgenerate

  // always_comb begin
  //   c = s[2*W-1:0];
  //   z = s[  W-1:0];
  // end

endmodule
