module qnigma_tcp_rx_ctl
  import
    qnigma_pkg::*;
(
  input logic           clk,
  input logic           tick_ms,
  input logic           rst,
  input tcb_t           tcb,      // engine's current transmission control blk

  input  meta_tcp_t     meta_tcp,
  input  logic          rcv,
  input logic [7:0]     pld_dat,
  input logic           pld_val,
  input logic           pld_sof,
  input logic           ini,      // engine's sigal to initialize local ack from tcb
  input logic           flush,    // engine request to flush buffer todo
  output logic          flushed,  // rx_ctl response that RAM flush is complete todo
  output logic [31:0]   loc_ack,  // current value reported by rx_ctl
  output tcp_opt_sack_t loc_sack, // local SACK blks reported by rx_ctl
  output logic          send_ack, // rx_ctl's signal to send ack
  input logic           ack_sent, // rx_ctl response that ack was sent
  
  output logic [7:0]    dat_out,
  output logic          val_out
);
  // 1. generates pure Acks (w/o payload) if either:
  //   - timeout has passed
  //   - unacked packet count exceeded threshold 
  //   - sack was updated
  // 2. reports lng of packets to be read from rx queue 
  // these Acks are the TCP informative logic
  // they do not carry data nor increase sequence number
  qnigma_tcp_rep qnigma_tcp_rep_inst (
    .clk      (clk),
    .rst      (rst),
    .tick_ms  (tick_ms),
    .tcb      (tcb),
    .ini      (ini),
    .pld_sof  (pld_sof),
    .loc_ack  (loc_ack),
    .loc_sack (loc_sack),
    .send     (send_ack),    // send pure ack upon ack timeout, exceeding unacked received packets count or 
    .sent     (ack_sent)    // tx logic will confirm as soon as packet is sent
  );

  qnigma_tcp_sack qnigma_tcp_sack_inst (
    .clk      (clk),
    .rst      (rst),
    .rcv      (rcv),
    .meta_tcp (meta_tcp),
    .pld_dat  (pld_dat),
    .pld_val  (pld_val),
    .pld_sof  (pld_sof),
    .dat_out  (dat_out),
    .val_out  (val_out),
    .tcb      (tcb),
    .ini      (ini),
    .loc_ack  (loc_ack),  // current local ack number
    .sack     (loc_sack) // current SACK option to be reported
  );

endmodule : qnigma_tcp_rx_ctl
