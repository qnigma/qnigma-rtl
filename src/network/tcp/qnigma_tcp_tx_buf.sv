// Hold raw TCP data to be transmitted, free space when ack received
// The logic here resembles a FIFO, but:
// 1. Read address is an input rather then an automatically incremented value
// 2. Space is freed by incrementing 'ack' input
// 
module qnigma_tcp_tx_buf
  import
    qnigma_pkg::*;
#(
  parameter D = 16,
  parameter W = 8
)
(
  input  logic         rst,
  input  logic         clk,
  
  input  logic         write,
  input  logic [W-1:0] data_in,

  input  logic [D-1:0] addr, // address to read from 
  output logic [W-1:0] data_out,

  input  logic [31:0]  seq, // local seq
  input  logic [31:0]  ack, // remote ack

  output logic         full,
  output logic         empty
);

logic [D-1:0] space; // space left in buffer
logic [D-1:0] addr_wr; // 

logic [32:0] dif;
reg [W-1:0] mem[(1<<D)-1:0];

assign  space = (dif[D]) ? 0 : ~dif[D-1:0]; // overflow condition accounted

always_comb begin
  dif   = seq - ack; // remote ack is always < local seq
  empty = (dif == 0);
  full  = (space[D-1:1] == {(D-1){1'b0}}); // space =< 1
end

// write
assign addr_wr = seq[D-1:0];
always_ff @ (posedge clk) if (write) mem[addr_wr] <= data_in;
// read
always_ff @ (posedge clk) data_out <= mem[addr];

endmodule : qnigma_tcp_tx_buf
