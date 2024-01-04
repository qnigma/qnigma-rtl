module qnigma_cla #(
  parameter int N = 16
)
(
  input  logic         clk,
  input  logic         e,
  input  logic [N-1:0] g,
  input  logic [N-1:0] p,
  output logic [N-1:0] c,
  input  logic         ci // first carry in
);


always_ff @ (posedge clk) begin
  c[0] = e & ci;
  for (int i = 1; i < N; i = i + 1) begin
    c[i] = e & ((c[i-1] & p[i-1]) | g[i-1]);
  end
end
endmodule
