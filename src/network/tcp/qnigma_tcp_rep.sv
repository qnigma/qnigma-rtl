// Acknowledgement packet generation is sourced from this logic:
// These packets alled Pure Ack do not contain payload, but are used to report
// current state of connection to the remote host: Seq/Ack numbers, SACK oprion
// There are several events that trigger such Pure Acks:
// - Number of unacked (not reported to be received) packets received exceeds TCP_FORCE_ACK_PACKETS
// - There are unacknowledged packets and ack timer has timed out
// - SACK option was updated. - Currently disabled
module qnigma_tcp_rep
  import
    qnigma_pkg::*;
(
  input  logic          clk,
  input  logic          rst,
  input  logic          tick_ms,
  input  tcb_t          tcb,
  input  tcb_t          pld_sof,
  input  logic          ini,
  input  logic [31:0]   loc_ack, // send pure ack upon ack timeout or exceeding unacked received packets count 
  input  tcp_opt_sack_t loc_sack, // send pure ack upon ack timeout or exceeding unacked received packets count 
  output logic          send,    // send pure ack upon ack timeout or exceeding unacked received packets count 
  input  logic          sent     // tx logic will confirm as soon as packet is sent
);

  logic [$clog2(TCP_ACK_TIMEOUT_MS+1)-1:0] timer;
  logic [$clog2(TCP_FORCE_ACK_PACKETS+1)-1:0] unacked_pkts;
  logic acked; // data is acked, no need to do anything

  logic timeout_ack, pkts_ack;
  tcp_opt_sack_t rep_sack;
  
  // means packet with local ack was actually sent (ack indeed reported)
  // if 'acked', avoid sending pure acks as last ack was already reported 
  
  always_ff @ (posedge clk) acked <= (tcb.loc_ack == tcb.rem_seq);// && (loc_sack == tcb.loc_sack);
  //always_ff @ (posedge clk) sack_reported <= (rep_sack == tcb.loc_sack);

  /////////////////////////////
  // Unacked packets tracker //
  /////// for forced ack //////
  /////////////////////////////
	
  // Do not ack every single packet. 
  // Keep
  always_ff @ (posedge clk) begin
    if (rst) begin
      unacked_pkts <= 0;
    end
    else begin
      if (acked || sent) unacked_pkts <= 0;
      else begin
        if (send) unacked_pkts <= 0; // reset unacked packet counter as Ack was just sent.
        // If maximum amount of unacked packets was reached, stop counting. Indicating force ack condition
        else if (pld_sof) unacked_pkts <= pkts_ack ? unacked_pkts : unacked_pkts + 1;
      end
    end
  end
  assign pkts_ack = (unacked_pkts == TCP_FORCE_ACK_PACKETS); // Ack due to unacked packet count

  ///////////////
  // Ack timer //
  ///////////////

  always_ff @ (posedge clk) begin
    if (rst) begin
      timer <= 0;
    end
    else begin
      if (tcb.status == tcp_connected) begin
        // keep timer reset if acked
        // or reset timer after receiving unacked packet
        if (acked/*|| (pld_sof && (meta.seq + meta.pld_len) != loc_ack)*/) timer <= TCP_ACK_TIMEOUT_MS;
        // keep timer at TCP_ACK_TIMEOUT_MS until 
        else if (tick_ms) timer <= (timer == 0) ? 0 : timer - 1;
      end 
    end
  end

  assign timeout_ack = (timer == 1); // Ack due to timeout

  /////////////
  // Ack mux //
  /////////////

  logic timeout_ack_send;
  
  always_ff @ (posedge clk) begin
    if (rst | acked) begin
      timeout_ack_send <= 0;
    end 
    else begin
      if (timeout_ack) timeout_ack_send <= 1; 
       else if (sent)  timeout_ack_send <= 0;
    end
  end

  logic pkts_ack_send;
  
  always_ff @ (posedge clk) begin
    if (rst) begin
      pkts_ack_send <= 0;
    end 
    else begin
      if (pkts_ack)  pkts_ack_send <= 1; 
      else if (sent) pkts_ack_send <= 0;
    end
  end

  logic sack_upd_pend;
  logic sack_upd_send;
/*  
  always_ff @ (posedge clk) begin
    if (rst) begin
      sack_upd_pend <= 0; 
      sack_upd_send <= 0;
    end 
    else begin
      if (sack_upd) sack_upd_pend <= 1; 
      else if (sack_upd_pend) begin
        if (sent) begin
           sack_upd_send <= 0;
           sack_upd_pend <= 0;
        end
        else sack_upd_send <= 1;
      end
    end
  end
*/
  assign send = (timeout_ack_send & !acked) | pkts_ack_send | sack_upd_send;

endmodule : qnigma_tcp_rep
