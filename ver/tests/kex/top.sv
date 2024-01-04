module top (
  input  logic        clk,
  input  logic        rst,
  output logic [31:0] res,
  output logic        don
);

  wrap dut (
    .clk (clk),
    .rst (rst),
    .res (res),
    .don (don)
  );

endmodule
