// Parallele in serial out shiftregister
module qnigma_piso #(
  parameter int WIDTH  = 8,
  parameter int LENGTH = 8,
  parameter bit RIGHT  = 0
)
(
  input  logic                         clk,
  input  logic                         set,
  input  logic                         shift,
  input  logic [LENGTH-1:0][WIDTH-1:0] par_i,
  output logic             [WIDTH-1:0] ser_o
);

  // Internal shift register
  logic [LENGTH-1:0][WIDTH-1:0] sreg;

  generate 
    if (RIGHT) begin : gen_right // >>
      always_ff @ (posedge clk) begin
        if      (set  ) sreg <= par_i;
        else if (shift) sreg <= sreg >> WIDTH;
      end
      assign ser_o = sreg[0];
    end
    else begin : gen_left // <<
      always_ff @ (posedge clk) begin
        if      (set  ) sreg <= par_i;
        else if (shift) sreg <= sreg << WIDTH;
      end
      assign ser_o = sreg[LENGTH-1];
    end
  endgenerate


endmodule