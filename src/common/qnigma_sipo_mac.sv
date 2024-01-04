// Pass-through shiftregister
module qnigma_sipo_mac #(
  parameter int WIDTH  = 8,
  parameter int LENGTH = 8
)
(
  input  logic                         clk,
  input  logic                         rst,
  input  logic             [WIDTH-1:0] ser_i,
  input  logic                         shift,
  output logic [LENGTH-1:0][WIDTH-1:0] par_o
);

  // Internal shift register
  logic [LENGTH-2:0][WIDTH-1:0] sreg;

  always_ff @(posedge clk) begin
    if (rst) sreg <= 0;
    else if (shift) begin
      sreg <= {sreg[LENGTH-3:0], ser_i};
    end
  end
  assign par_o = {sreg[LENGTH-2:0], ser_i}; // todo qnigma_rx phy delay to avoid this comb output


endmodule