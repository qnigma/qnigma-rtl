// Transmission queue scanning logic
// Manages retransmissions
// 
module qnigma_tcp_tx_scan
  import
    qnigma_pkg::*;
(
  input    logic clk,
  input    logic rst,
  input    tcb_t tcb,
  input    logic add_pend,
  // info ram interface
  output logic                    upd,
  output logic                    del,       // delete packets that were acked (in order)
  output logic [TCP_TX_PACKET_DEPTH-1:0] ptr,
  input  tcp_pkt_t                pkt_r,
  output tcp_pkt_t                pkt_w,

  output tcp_pld_info_t           pld_info,  // payload info for tx module
  output logic                    pend,
  output logic                    force_dcn, // request to abort connection (failed rtx)
  input  logic                    flush,     // engine's request to flush info ram
  output logic                    flushed,   // indicates that info ram is flushed
  // Dup Ack
  input  logic                    dup_det,   // duplicate ack detected
  input  logic [31:0]             dup_ack,   // duplicate ack number
  input  logic                    tx_idle
);

  enum logic [8:0] {
  /*0*/  SCAN,
  /*1*/  CHOICE,
  /*2*/  DUP,
  /*3*/  SACK_SHIFT,
  /*4*/  SACK_DIF,
  /*5*/  UPD,
  /*6*/  NEXT,
  /*7*/  READ,
  /*8*/  FLUSH
  } state;

  logic [TCP_TX_PACKET_DEPTH-1:0] flush_ctr, next_ptr;
  logic sacked;
  logic acked;
  tcp_opt_sack_t sack;
  logic [31:0] start_dif; 
  logic [31:0] stop_dif; 
  logic [31:0] dup_start_dif; 
  logic [31:0] dup_stop_dif;
  logic [31:0] ack_dif; 
  logic [31:0] end_seq; // Last sent 
  logic [1:0]  sack_ctr;
  logic sack_rtx;
  logic norm_tx; 
  logic long_rtx;
  logic dup_det_reg;
  logic fast_rtx;
  logic norm_rtx;
  
  logic transmit;

  logic sack_match; // fully sacked packet detected
  logic dup_match; // fully sacked packet detected
  
  // todo: use less subtractors by muxing 
  assign sack_match = !start_dif[31] && !stop_dif[31];
  assign dup_match  = !dup_start_dif[31] && !dup_stop_dif[31]; 

  assign transmit = norm_tx | sack_rtx | fast_rtx | norm_rtx;

  always_ff @ (posedge clk) begin
    if (rst) begin // Engine has to close connection to reenable ctl
      state     <= SCAN;
      upd       <= 0;
      ptr       <= 0;
      next_ptr  <= 0;
      force_dcn <= 0;
      flushed   <= 0;
      flush_ctr <= 0;
      pld_info  <= 0;
      pkt_w     <= 0;
      del       <= 0;
      ack_dif   <= 0;
      sack_ctr  <= 0;
      pend      <= 0;
      norm_tx   <= 0;
      fast_rtx  <= 0;
      sack_rtx  <= 0;
      norm_rtx  <= 0;
      long_rtx  <= 0;
      end_seq   <= tcb.loc_seq;
    end
    else begin
      case (state)
        SCAN : begin
          sack_ctr <= 0;
          sack     <= tcb.rem_sack; // load current remote sack
          pkt_w    <= pkt_r;        // packet to update is currently read packet
          sacked   <= 0;            // assume packet pkt_r is unsacked
          pend     <= 0;
          upd      <= 0;
          flushed  <= 0;
          del      <= 0;
          norm_tx  <= 0; 
          sack_rtx <= 0;
          fast_rtx <= 0;
          norm_rtx <= 0;
          // continiously scan for unacked packets. If present flag found, check if it's acked and if it's ready for transmission
          // if packet at current address is not present, read next one and so on
          // this difference defines if packed is acked
          ack_dif <= tcb.rem_ack - pkt_r.stop; // bit[31] means packet is acked (pkt's last seq < remote_ack)
          state <= (flush) ? FLUSH : DUP;
        end
        // choose 
        DUP : begin
          acked         <= pkt_w.exists && !ack_dif[31];// !ack_dif[31] means packet is acked by remote host completely and may be removed (free space)
          state         <= SACK_DIF;
          dup_det_reg   <= dup_det;
          dup_start_dif <= dup_ack - pkt_w.start; // dup_start_dif[31] means packet start is after dup_ack
          dup_stop_dif  <= pkt_w.stop - dup_ack;  // dup_stop_dif [31] means packet stop is before dup_ack
        end
        // calculate 
        SACK_DIF : begin
          sack.blk[3:1] <= sack.blk[2:0];
          start_dif     <= sack.blk[3].right - pkt_w.stop;
          stop_dif      <= pkt_w.start - sack.blk[3].left; 
          state         <= SACK_SHIFT;
        end
        // choose to fast retransmit if packet isn't SACKed
        // retransmit a packet if at least part of it is not contained within any sack blk.
        // the decision is made if the packet exceeds any border of any SACK_SHIFT block.
        // if no sack blks are present, 'sacked' stays 0 and will SACK retranmssion will not happen 
        SACK_SHIFT : begin 
          sack.val[3:0] <= {sack.val[2:0], 1'b0};
          if (sack.val[3] && sack_match) 
            sacked <= 1;                           // if packet is not contained within any present sack blk.
          if (sack_ctr == 3)                       // All SACK_SHIFT blocks processed 
            state <= CHOICE;                       // Choose what to do with the packet
          else begin
            sack_ctr <= sack_ctr + 1; // next SACK_SHIFT block
            state <= SACK_DIF;        // 
          end
        end
        // choose what to do with an entry
        CHOICE : begin
          // Only transmit if packet isn't acked, timer reached timeout and there are no pending transmissions
          if (pkt_w.exists && (tcb.rem_wnd >= tcb.mss) && tx_idle) begin
  		      norm_tx  <= !dup_det &&                                      // no duplucate ack detected ()
                        (ptr == next_ptr) &&                             // current point is equal to next in-order pointer 
                        (pkt_w.tries == 0);                              // normal transmission is forced in-order
  		      sack_rtx <= (pkt_w.sack_rto >= TCP_SACK_RETRANSMIT_TICKS) && // SACK retransmssion timer out
                        !sacked &&                                       // Packet is currently sacked
                        (pkt_w.tries != 0);                              // will retransmit due to SACK_SHIFT blk received
            fast_rtx <= dup_det &&                                       // duplicate ack detected
                        dup_match &&                                     // loss of this packet caused to dup ack on other side
                        (pkt_w.tries == 1);                              // only fast retransmit once
            norm_rtx <= (pkt_w.norm_rto >= TCP_RETRANSMIT_TICKS); // last resort retransmission
          end
          if (pkt_w.tries == TCP_RETRANSMIT_TRIES) force_dcn <= 1; // force disconnect if there were too many retransmission attempts
          if (!add_pend) begin // avoid collision with port A that adds packets to info ram
            state <= UPD; 
            del <= (acked && pkt_w.start == end_seq); // remove one after another
          end
        end
        // update entry
        UPD : begin
          upd <= pkt_w.exists; // update packed info if the packet exists in queue
          del <= 0;            // deassert delete
          if (del) begin                // will delete packet 
            end_seq      <= pkt_w.stop; // Current last held
            pkt_w.exists <= 0;
          end
          else if (transmit) begin // will be transmitting packet
            pld_info.start <= pkt_w.start;
            pld_info.stop  <= pkt_w.stop;
 	          pld_info.lng   <= pkt_w.lng;
       	    pld_info.cks   <= pkt_w.cks;
            if (norm_tx) next_ptr <= ptr + 1; // next packet to be transmitted in order
            pend <= 1;
            pkt_w.exists   <= 1;               // packet is still stored
            pkt_w.tries    <= pkt_w.tries + 1; // transmission try count incremented
            pkt_w.norm_rto <= 0;               // reset the rto timers beacuse packet is being sent
            pkt_w.sack_rto <= 0;
          end
          else begin // will increment timers
            pkt_w.tries <= pkt_w.tries;
            pkt_w.exists <= pkt_w.exists; // packet still stored
            if (pkt_w.norm_rto != TCP_RETRANSMIT_TICKS)      pkt_w.norm_rto <= pkt_w.norm_rto + 1; // increment
            if (pkt_w.sack_rto != TCP_SACK_RETRANSMIT_TICKS) pkt_w.sack_rto <= pkt_w.sack_rto + 1; // increment
          end
          state <= NEXT;
        end
        NEXT : begin
          ptr <= ptr + 1; 
          upd <= 0;
          state <= READ;
        end
        READ : begin
          state <= SCAN; // Wait 1 tick to get new entry at 'ptr'
        end
        // Flush only info RAM
        // Data RAM may be kept intact and will be discarded anyway (todo: safe?)
        FLUSH : begin
          pend         <= 0;
          pkt_w.exists <= 0; // resetting present flag in all entries is sufficient to flush info RAM
          upd          <= 1; // coutinously 'delete' all packets pending for transmission
          ptr          <= ptr + 1; // 
          flush_ctr    <= flush_ctr + 1;
          if (flush_ctr == 0 && upd && tx_idle) begin
            flushed <= 1; // wait for tx to finish 
            state <= SCAN;
          end
        end
        default :;
      endcase
    end
  end

endmodule
