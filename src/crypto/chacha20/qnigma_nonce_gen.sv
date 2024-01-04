// Genetate nonce value
// ChaCha20 nonce is 96-bit
// Genetation of next nonce is performed by incrementing 
//   previous value by INC
// Adder width is 32 bits, addition is performed with carry
//   in 3 clock cycles
//
module qnigma_nonce_gen
  import
    qnigma_chacha20_pkg::*;
#(
  parameter cha_non_t NONCE_INI = 1234,
  parameter int   INC_VALUE = 1
)
(
  input  logic clk,
  input  logic rst,
  input  logic inc,
  output cha_non_t non,
  output logic val
);

  logic ci, co;
  logic [1:0] ctr;
  logic [31:0] q;

  // process carry

  always_ff @ (posedge clk) begin
    if (rst) begin
      non <= NONCE_INI;
      ctr <= 0;
      val <= 0;
    end
    else if (inc) begin // 1-tick strobe
      ctr <= 0; // reset counter
      val <= 0; // nonce output not valid anymore
      ci <= 0;
    end
    else if (!val) begin
      ci <= co;
     // $display("ctr %x a %x b %x ci %x co %x q %x", ctr, non[ctr], (ctr == 0) ? INC_VALUE : 0, ci, co, q);
      ctr <= ctr + 1;
      non[ctr] <= q;
      if (ctr == 2) val <= 1;
    end
  end
    
  // qnigma_add #(.W (32), .R (0)) add_inst (
  //   .clk (clk),
  //   .a   (non[ctr]),
  //   .b   ((ctr == 0) ? INC_VALUE : 0),
  //   .ci  (ci),
  //   .q   (q),
  //   .co  (co)
  // );

endmodule
