// Serial-in Parallal-out shiftregister
module qnigma_sipo #(
  parameter int WIDTH  = 8,
  parameter int LENGTH = 8,
  parameter bit RIGHT  = 0
)
(
  input  logic                         clk,
  input  logic                         rst,
  input  logic             [WIDTH-1:0] ser_i,
  input  logic                         shift,
  output logic [LENGTH-1:0][WIDTH-1:0] par_o
);

  // Internal shift register
  logic [LENGTH-1:0][WIDTH-1:0] sreg;


  generate 
    if (RIGHT) begin : gen_right // >>
      always_ff @(posedge clk) begin
        if      (rst  ) sreg <= 0;
        else if (shift) sreg <= {ser_i, sreg[LENGTH-1:1]};
      end
    end
    else begin : gen_left // <<
      always_ff @(posedge clk) begin
        if      (rst  ) sreg <= 0;
        else if (shift) sreg <= {sreg[LENGTH-2:0], ser_i};
      end
    end
  endgenerate
  assign par_o = sreg;

endmodule