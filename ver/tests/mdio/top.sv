module top (
  input  logic        clk,
  input  logic        rst,
  output logic        don
);

  wrap dut (
    .clk (clk),
    .rst (rst),
    .don (don)
  );

endmodule
