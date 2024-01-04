// see rfc3517 p.2 duplicate duplicate acknowledgments
module qnigma_tcp_fast_rtx
  import
    qnigma_pkg::*;
(
  input  logic        clk,
  input  logic        rst,
  input  tcb_t        tcb,
  input  meta_tcp_t   meta,
  input  logic        val,
  output logic        dup_det, // duplicate acknowledge detected
  output logic [31:0] dup_ack,  // last detected ack
  input  logic [31:0] last_seq  // last detected ack
);

  logic [$clog2(TCP_DUP_ACKS+1)-1:0] dup_ack_ctr;
  logic fsm_rst;
  logic rep_ack_updated;

  // keep logic off
  // if local seq is equal to remote ack
  // meaning that all data is acked
  always_ff @ (posedge clk) fsm_rst <= (last_seq == tcb.rem_ack) || rst;
  always_ff @ (posedge clk) dup_det <= (dup_ack_ctr == TCP_DUP_ACKS);

  //////////////
  // Dup acks //
  //////////////
  // Fast retransmit a packet that contains dup_ack
  // As the segment just after dup_ack is probably lost
  always_ff @ (posedge clk) begin
    if (fsm_rst) begin
      dup_ack_ctr <= 0;
      rep_ack_updated <= 0;
    end
    else begin
      if (tcb.status == tcp_connected && val && meta.flg.ack) begin // Receiving an ACK packet
        rep_ack_updated <= 1; // increment dup_ack_ctr.
        if (!rep_ack_updated) begin // deassert after 1 tick
          dup_ack <= meta.ack;
          if (dup_ack == meta.ack) dup_ack_ctr <= (dup_ack_ctr == TCP_DUP_ACKS) ? dup_ack_ctr : dup_ack_ctr + 1;
          else dup_ack_ctr <= 0;
        end
      end
      else rep_ack_updated <= 0;
    end
  end

endmodule : qnigma_tcp_fast_rtx
