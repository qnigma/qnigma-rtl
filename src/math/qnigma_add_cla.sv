module qnigma_add_cla #(
  parameter int WA = 16, // Adder width
  parameter int WL = 16, // Look-ahead bit index
  parameter bit R = 0  
)
(
  input  logic          clk,
  input  logic [WA-1:0] a,
  input  logic [WA-1:0] b,
  output logic [WA-1:0] q,
  input  logic          c,
  output logic          g,
  output logic          p
);
  
  logic [WA:0] s;

  assign s = a + b;


  generate
    if (R == 0) begin : gen_comb
      assign q = s + c;
      assign p  = s[WL-1:0] == '1; // propagate carry if all bits are 1
      assign g  = s[WL];           // generate if adder overflows (ignore MSbits)
    end
    else if (R == 1) begin : gen_ff
      always_ff @ (posedge clk) q <= s + c;
      always_ff @ (posedge clk) p <= s[WL-1:0] == '1; // propagate carry if all bits are 1
      always_ff @ (posedge clk) g <= s[WL];           // generate if adder overflows (ignore MSbits)
    end
  endgenerate


endmodule
