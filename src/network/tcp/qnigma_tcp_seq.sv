// local sequence number tracker 
module qnigma_tcp_seq
  import
    qnigma_pkg::*;
(
  input  logic        clk,
  input  tcb_t        tcb,
  input  logic        ini,
  input  logic        val,  
  output logic [31:0] seq
);

  always_ff @ (posedge clk) begin
    if (ini) seq <= tcb.loc_seq;
    else if (val) seq <= seq + 1;
  end
 
endmodule : qnigma_tcp_seq
