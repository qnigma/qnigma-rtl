// Transmitted packet information RAM
module qnigma_tcp_tx_info 
  import
    qnigma_pkg::*;
#(
  parameter int D = 4
)
(
  input logic clk,
  input logic rst,
  // New packets
  input  logic         add,   // add 'new_pkt'
  input  tcp_pkt_t     new_pkt,
  input  logic [D-1:0] ptr,   // update pointer
  input  logic         upd,   // uddate packet at 'ptr' with 'pkt_w'
  input  logic         free,  // release (remove from queue) a packet at 'ptr'
  input  tcp_pkt_t     pkt_w, // packet to write
  output tcp_pkt_t     pkt_r, // read packet
  output logic         full   // no more packets can be stored
);

  // Might be too wide RAM for some tools. Careful!
  parameter int W = $bits(tcp_pkt_t);
  
  logic [D-1:0] space;
  logic [D-1:0] add_ptr;
  
  logic [W-1:0] info_d_a;
  logic [D-1:0] info_a_a;
  logic         info_w_a;
  logic [W-1:0] info_q_a;

  logic [W-1:0] info_d_b;
  logic [D-1:0] info_a_b;
  logic         info_w_b;
  logic [W-1:0] info_q_b;

  // todo: check if synthesises well with wide data bus 
  qnigma_ram_dp #(
    .AW (D),
    .DW (W)
  ) data_ram_inst (
    .rst   (rst),
    .clk_a (clk), 
    .clk_b (clk),
    .d_a   (info_d_a), 
    .a_a   (info_a_a),
    .w_a   (info_w_a),
    .q_a   (info_q_a),

    .d_b   (info_d_b), 
    .a_b   (info_a_b),
    .w_b   (info_w_b),
    .q_b   (info_q_b)
  );

  // `Add new packet` port
  assign info_a_a = add_ptr[D-1:0];
  assign info_d_a = new_pkt;
  assign info_w_a = add;
  // `Update of remove existing packet`
  assign info_a_b = ptr[D-1:0];
  assign info_d_b = pkt_w;
  assign info_w_b = upd;
  assign pkt_r    = info_q_b;

  // difference between push and pop ptr indicates the space left for
  // individual packets that may be stored in packet info RAM
  always @ (posedge clk) begin : ff_space
    if (rst) begin
      space <= '1;
      add_ptr <= 0;
    end
    else begin
      case ({add, free})
        2'b10 : space <= space - 1;
        2'b01 : space <= space + 1;
        2'b00, 
        2'b11 : space <= space;
      endcase
      if (add) add_ptr <= add_ptr + 1; // add pointer is simply increased with each new packet 
      // It is assured that packets will be also freed in order 
    end
  end

  // full condition with last entry left look-ahead
  assign full = (space == 0) | (add && space == 1);

endmodule : qnigma_tcp_tx_info
