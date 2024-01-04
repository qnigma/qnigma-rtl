// TCP SACK logic
// 1. keeps SACK updated by processing incomming packets
// 2. manages receive queue
// 3. decides if it's time to read data from queue if missing segment arrived
// 4. directly interfaces user's receive logic
module qnigma_tcp_sack
  import
    qnigma_pkg::*;
(
  input  logic          clk,
  input  logic          rst,
  input  logic          rcv,
  input  meta_tcp_t     meta_tcp,

  input logic [7:0]     pld_dat,
  input logic           pld_val,
  input logic           pld_sof,

  output logic [7:0]    dat_out,
  output logic          val_out,

  input  tcb_t          tcb,     // contains initial loc_ack
  input  logic          ini,     // initializa local ack with value from TCB 
  output logic [31:0]   loc_ack, // current local acknowledgement number. valid after ini
  output tcp_opt_sack_t sack     // current SACK (always valid)
);


  enum logic [5:0] {
    IDLE,
    CAL, // calculate new blk borders (only if concatenation occurs)
    CAT, // determine if concatenation may be performed (1 blk at a clock tick)
    OUT,
    UPD
  } state;

  logic [31:0] 
    start_gap, // the gap between current minimal storable sequence and received packet's first byte's seq
    stop_gap,  // the gap between current minimal storable sequence and received packet's last byte's seq
    start_dif, 
    stop_dif,  // these values determine if concatenation of current received packet and current blk is possible      
    left_dif,
    right_dif, // these values determine which borders will be used for new concatenated blk if concatenation is being performed
    max_seq,
    min_seq; // current minimum and maximum allowed sequence number (refers to byte number, not pkt's seq)
    
  logic [31:0] cur_ack; // the current Acknowledgement number of TCP

  tcp_opt_sack_t cur_sack, new_sack;
  logic [2:0] blk_ctr;
  logic in_order;
  tcp_sack_blk_t cur_blk, new_blk;

  logic out_en; // a ger used to delay valid signal
  logic store; // indicate RAM to store current packet

//                   
//                             idle
//                               |
//                           new packet
//                               |
//                               v 
//                            in order?
//                     +-no-- upd ack? -yes-+
//                     |                    |     
//                     v                    v      
//                    pkt                 update
//                  storable?            ack 
//                     |
//                    yes
//
//

//
  logic [7:0]                  rx_buf_d_a;
  logic [TCP_RX_RAM_DEPTH-1:0] rx_buf_a_a;
  logic                        rx_buf_w_a;
  logic [7:0]                  rx_buf_q_a;

  logic [7:0]                  rx_buf_d_b;
  logic [TCP_RX_RAM_DEPTH-1:0] rx_buf_a_b;
  logic                        rx_buf_w_b;
  logic [7:0]                  rx_buf_q_b;

  // receive data buffer
  qnigma_ram_dp #(
    .AW (TCP_RX_RAM_DEPTH), 
    .DW (8)
  ) rx_buf_inst (
    .rst   (rst),
    .clk_a (clk), 
    .clk_b (clk),
    .d_a   (rx_buf_d_a), 
    .a_a   (rx_buf_a_a),
    .w_a   (rx_buf_w_a),
    .q_a   (rx_buf_q_a),

    .d_b   (rx_buf_d_b), 
    .a_b   (rx_buf_a_b),
    .w_b   (rx_buf_w_b),
    .q_b   (rx_buf_q_b)
  );

  logic proc;
  logic choose;
  logic out_reg;

  assign proc = rcv && 
                   (meta_tcp.src == tcb.rem_port) &&
                   (meta_tcp.dst == tcb.loc_port) &&
                   (meta_tcp.pld.lng != 0) &&
                    meta_tcp.flg.ack; // Received packet's ports match current connection, contains payload and ACK flag

  always_ff @ (posedge clk) choose <= proc; // delayed 1 tick

  always_ff @ (posedge clk) begin
    rx_buf_d_a <= pld_dat;
    rx_buf_w_a <= pld_val && store; 
    if (pld_sof)       rx_buf_a_a <= new_blk.left;
    else if (pld_val)  rx_buf_a_a <= rx_buf_a_a + 1;
    //else if (!pld_val) rx_buf_w_a <= 0;
  end

  ///////////////
  // Read blks //
  ///////////////

  assign rx_buf_a_b = cur_ack[TCP_RX_RAM_DEPTH-1:0];

  always_comb out_en = (cur_ack != loc_ack) && (tcb.status == tcp_connected); // and output stored data 1 byte per tick

  always_ff @ (posedge clk) begin
    if (ini)         cur_ack <= tcb.loc_ack;
    else if (out_en) cur_ack <= cur_ack + 1;
  end
  
  // actual receive user data interface
  always_ff @ (posedge clk) begin
    out_reg <= out_en;
    val_out <= out_reg; 
    dat_out <= rx_buf_q_b;
  end

  always_ff @ (posedge clk) begin
    if (pld_sof) in_order  <= meta_tcp.pld.start == loc_ack; // determin if packet received is in order
    start_gap <= meta_tcp.pld.start - min_seq;               // ensure packet's start is AFTER minimum requred
    stop_gap  <= max_seq - meta_tcp.pld.stop;                //        packet's end is BEFORE maximum available
  end

  always_comb begin
    store = !start_gap[31] && !stop_gap[31];                 // look at msb to avoid wraparound issues
  end

  // calculate minimum and maximum sequence number of a packet's 
  always_comb begin
    max_seq = loc_ack + 2**(TCP_RX_RAM_DEPTH); // maximum sequence number that can be stroed in rx buffer
    min_seq = loc_ack;                         // we don't write data that has seq < loc_ack
  end

  ////////////////////////
  // Manage SACK option //
  ////////////////////////

  always_ff @ (posedge clk) begin
    if (rst) begin
      sack     <= 0;
      blk_ctr  <= 0;
      state <= IDLE;
    end
    else begin
      case (state)
        IDLE : begin
          new_sack <= 0;                                       // set new SACK to be zero
          blk_ctr  <= 0;                                       // reset block counter
          new_blk  <= {meta_tcp.pld.start, meta_tcp.pld.stop}; // initialize new blk with packet's borders
          cur_sack <= sack;                                    // cur_sack is a shiftreg, load it
          if (ini) loc_ack <= tcb.loc_ack;                     // initialize once
          if (choose && store) state <= CAL;                   // packet received and we are storing it's payload
        end
        /////////////////////////
        // Concatenation logic //
        /////////////////////////
        CAL : begin // calculate values necessary for concatenation
          cur_blk <= cur_sack.blk[3];
          // calculate differences
          left_dif  <= new_blk.left  - cur_sack.blk[3].left;   // bit[31] means start below left -> concat using pkt's start
          right_dif <= cur_sack.blk[3].right - new_blk.right;  // bit[31] means stop  above right -> concat using pkt's stop
          start_dif <= cur_sack.blk[3].right - new_blk.left;   // ------[sack]---- bit[31] means packet's start is within current sack
          stop_dif  <= new_blk.right - cur_sack.blk[3].left;   // ---[++++++++[---- bit[31] means packet's stop  is within current sack
                                                               // ------]+++++++]-- both conditions met -> packet will be concatenated with sack blk
          blk_ctr <= blk_ctr + 1;
          if (blk_ctr == TCP_SACK_BLOCKS) begin
            state <= in_order ? OUT : UPD;
            if (in_order) loc_ack <= new_blk.right; // update local Ack ack as this packet's last seq if it's in order. this may be more then 1 packet jump
          end
          else if (cur_sack.val[3]) // looking at current block, if it's present...
            state <= CAT; // try to concatenate it with new_sack.blk[3] 
          cur_sack.val[3:1] <= cur_sack.val[2:0]; // shift the current SACK to update [3] with all blocks sequentially
          cur_sack.blk[3:1] <= cur_sack.blk[2:0];
        end
        CAT : begin // concatenate blks
          state <= CAL;
          if (!start_dif[31] && !stop_dif[31]) begin // packet and block boundaries cross, concatenating
            new_blk.left  <= ( left_dif[31]) ? new_blk.left  : cur_blk.left; // if (left_dif[31] )
            new_blk.right <= (right_dif[31]) ? new_blk.right : cur_blk.right;
          end
          else begin
            new_sack.blk[2:0] <= {cur_blk, new_sack.blk[2:1]};
            new_sack.val[2:0] <= {1'b1,    new_sack.val[2:1]};
          end
        end
        OUT : begin // check if received packet fills missing gap
          sack.val[3:0] <= {new_sack.val[2:0], 1'b0};
          sack.blk[3:1] <= {new_sack.blk[2:0]      };
          state <= IDLE;
        end
        UPD : begin
          sack.blk[3:0] <= (in_order) ? {new_sack.blk[2:0], 64'h0} : {new_blk, new_sack.blk[2:0]};
          sack.val[3:0] <= (in_order) ? {new_sack.val[2:0],  1'b0} : {1'b1,    new_sack.val[2:0]};
          state <= IDLE;
        end
        default :;
      endcase
    end
  end

endmodule : qnigma_tcp_sack
