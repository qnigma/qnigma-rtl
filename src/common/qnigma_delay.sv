// Delay data of W width for for D ticks
module qnigma_delay #(
  parameter int W = 8,
  parameter int D = 8
)
(
  input  logic         clk,         
  input  logic [W-1:0] in,   
  output logic [W-1:0] out 
);

  logic [D-1:0][W-1:0] shiftreg;

  always_ff @ (posedge clk) shiftreg <= {shiftreg[D-2:0], in};

  assign out = shiftreg[D-1];

endmodule : qnigma_delay
