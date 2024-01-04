// Serial-in Parallal-out shiftregister
module qnigma_shiftreg #(
  parameter int WIDTH  = 8,
  parameter int LENGTH = 8,
  parameter bit RIGHT  = 0
)
(
  input  logic                         clk,
  input  logic                         rst,
  // parallel load
  input  logic                         load,
  input  logic [LENGTH-1:0][WIDTH-1:0] par_i,
  // serial shift
  input  logic                         shift,
  input  logic             [WIDTH-1:0] ser_i,
  output logic [LENGTH-1:0][WIDTH-1:0] ser_o,
  output logic [LENGTH-1:0][WIDTH-1:0] par_o
);

  logic [LENGTH-1:0][WIDTH-1:0] sreg;

  assign par_o = sreg;

  generate 
    if (RIGHT) begin : gen_right // >>
      always_ff @(posedge clk) begin
        if      (load)  sreg <= par_i;
        else if (shift) sreg <= {ser_i, sreg[LENGTH-1:1]};
      end
    end
    else begin : gen_left // <<
      always_ff @(posedge clk) begin
        if      (load)  sreg <= par_i;
        else if (shift) sreg <= {sreg[LENGTH-2:0], ser_i};
      end
    end
  endgenerate

endmodule : qnigma_shiftreg