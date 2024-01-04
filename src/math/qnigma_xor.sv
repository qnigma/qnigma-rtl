module qnigma_xor #(
  parameter int W = 16
) 
(
  input  logic [W-1:0] a, // Operand A
  input  logic [W-1:0] b, // Operand B
  output logic [W-1:0] q
);
  
  assign q = a ^ b;

endmodule
