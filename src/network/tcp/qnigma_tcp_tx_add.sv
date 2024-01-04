// This module is responsible for adding packet entries
module qnigma_tcp_tx_add 
  import
    qnigma_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  input  logic [15:0] mss, // variable MSS setting
  input  logic [31:0] seq, // current sequence number
  output tcp_pkt_t    pkt, // generated TCP packet 
  output logic        add, // add the 'pkt' as a packet for transission
  output logic        pend, // add is pending and will happen on next clock tick
  input  logic        full,  // data ram full
  input  logic        flush, // request to flush tcp related RAMs
  input  logic        val,   // user inteface data valid input (raw TCP stream)
  input  logic [7:0]  dat,   // user inteface data valid output
  input  logic        frc    // force sending a packet (don't wait to concat) 
);

  enum logic [1:0] {IDLE, PEND} state;
  
  logic [31:0] cks; // current checksum

  logic [7:0] dat_reg;
  logic add_timeout;
  logic add_mss;
  logic add_pend;

  logic [31:0] seq_reg; 
  logic [31:0] start;

  logic [$clog2(TCP_WAIT_TICKS+1)-1:0] timeout;
  logic [$clog2(   MTU_DEFAULT+1)-1:0] ctr; 

  // clear to send flag is set if:
  // 1. TCP is connected
  // 2. packet info RAM isn't full (check msb)
  // 3. transmission data buffer isn't full
  // New data for transmission didn't arrive for TCP_WAIT_TICKS
  
  // Pending add if either:
  //  - Payload data RAM is full. Can't store more payload
  //  - Nagle's algorithm timed out
  //  - Payload reached MSS size
  //  - Nagle algorithm is skipped and current data is forced to form a packet
  assign add_pend = full || add_timeout || add_mss || frc;

  always_comb begin : comb_logic
    // todo remove -1 below
    add_mss      = (ctr == mss - 1); // 60 for tcp header (with options) and another 20 for ip. todo: check for correctness
    add_timeout  = (timeout == TCP_WAIT_TICKS && !val);
    pend         = (state == PEND) && (add_pend); // adding packet at next tick
  end
  always_comb begin : comb_new_pkt
    pkt.lng      = ctr;                                    // lng equals byte count for current packet
    pkt.cks      = ctr[0] ? cks + {dat_reg, 8'h00} : cks; // this is how payload checksum is calculated
    pkt.exists   = 1;                                    // Every new entry in packet info table is valid
    pkt.tries    = 0;                                     // The packet hasn't been transmittd yet
    pkt.norm_rto = 0;                                     // 
    pkt.sack_rto = 0;
    pkt.start    = start; // equals expected ack for packet
    pkt.stop     = seq;   // equals expected ack for packet. seq is incremented with new bytes in other module
  end

  // Packet creation FSM
  always_ff @ (posedge clk) if (val) dat_reg <= dat; // If valid, remember current dat

  always_ff @ (posedge clk) begin : ff_new_pkt
    if (rst) begin
      ctr     <= 0;
      timeout <= 0;
      state   <= IDLE;
    end
    else begin
      case (state)
        IDLE : begin
          if (val) begin // user data detected
            ctr   <= 1; // at least 1 byte received
            state <= PEND;
          end
          start   <= seq; // packet's start is set to current tx sequence number
          cks     <= 0;   // checksum is initialized with 0
          timeout <= 0;   // timer is reset 
        end
        PEND : begin
         // pend <= 0;
         // start <= seq_reg;
          if (val) begin 
            ctr <= ctr + 1; // Increment counter for each new payload byte 
            cks <= (ctr[0]) ? cks + {dat_reg, dat} : cks; // checksum calculation for odd/even length
          end
          timeout <= (val) ? 0 : timeout + 1; // reset timeout if new byte arrives (Nagle's algorithm)
          // either of three conditions to add new packet
          if (add_pend) state <= IDLE;
        end
        default :;
      endcase
    end
  end
  
  always_ff @ (posedge clk) add <= (pend && !flush); // if flush request received, don't add any more packets

endmodule : qnigma_tcp_tx_add
