// Controls payload readout from data RAM
module qnigma_tcp_tx_strm
  import
    qnigma_pkg::*;
#(
  parameter int D = 10
)
(
  input  logic          clk,
  input  logic          rst,
  input  logic          pend, // Data pending for transmission
  output logic          send, // Request to send a packet
  input  logic          sent, // TCP packet competely sent by qnigma_tx
  input  logic          req,  // qnigma_tx request for payload data
  output logic [D-1:0]  addr, // address to data RAM
  output logic          val,  // 
  output logic          idle, // Payload transmission idle
  input  [31:0]         seq,  // Payload first byte sequence number to be transmitted
  input  [15:0]         len   // Payload length to be trasnmitted in the packet
);

  enum logic [2:0] {IDLE, WAIT, STREAM} state;

  logic [D-1:0] next_addr;
  logic [D-1:0] ctr_tx; // counter can't be wider then RAM

  assign next_addr = addr + 1;

  always_ff @ (posedge clk) begin
    if (rst) begin
      state    <= IDLE;
      send     <= 0;
      idle     <= 1;
      val      <= 0;
      ctr_tx   <= 0;
    end
    else begin
      case (state)
        IDLE : begin
          ctr_tx <= 0;
          addr <= seq[D-1:0]; // set RAM adderss to 1st byte sequence number LSBits 
          if (pend) begin  // Packet transmission requested
            idle <= 0;     // Payload tranmsission active
            send <= 1;     // Request sending a TCP payload packet
            state <= WAIT;
          end
          else begin
            idle <= 1;
            send <= 0; // ???
          end
        end
        WAIT : begin
          if (req) begin // If req is seen, qnigma_tx handled the TCP header and options and requests payload
            send  <= 0;         // request accepted, deassert
            val   <= 1;         // payload valid
            addr  <= next_addr; // prepare next byte for readout
            state <= STREAM;    // start streaming
          end
        end
        STREAM : begin
          ctr_tx <= ctr_tx + 1; // transmission counter 
          addr   <= next_addr;  // read bytes sequentially from RAM
          if (ctr_tx == len) val <= 0; // All bytes read, done with payload
          if (sent) state <= IDLE; // wait till packet is completely send and return to IDLE
        end
        default :;
      endcase
    end
  end
  
endmodule : qnigma_tcp_tx_strm
