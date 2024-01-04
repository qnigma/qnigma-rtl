  // Scheme:
  //       +------+
  //       |engine|=========+
  //       +------+         |       
  //========================|=================
  //   +----------+   _     |   _
  //   |keep-alive|=>| \    |  | \
  //   +----------+  |  \   +=>|0 \ 
  //      +-------+  |   \     |   |===> to tx
  //      |payload|=>|arb |===>|1 /
  //      +-------+  |   /     |_/
  //   +----------+  |  /       ^
  //   |forced ack|=>|_/   [connected]  
  //   +----------+

module qnigma_tcp_tx_arb
  import
    qnigma_pkg::*;
(
  input  logic            clk,
  input  logic            rst,
  input  tcb_t            tcb,
  // controls and replies
  // Keep-alive
  input  logic            send_ka,
  output logic            ka_sent,
  // Payload
  input  logic            send_pld,
  input  tcp_pld_info_t   pld_info,
  output logic            pld_sent,
  // Pure Ack
  input  logic            send_ack,
  output logic            ack_sent,
  // Port from engine
  input  meta_mac_t       meta_mac_eng,
  input  meta_ip_t        meta_ip_eng,
  input  meta_tcp_t       meta_tcp_eng,
  input  meta_tcp_pres_t  meta_tcp_eng_pres,
  input  logic            tx_val_eng,
  
  output meta_mac_t       meta_mac,
  output meta_ip_t        meta_ip,
  output meta_tcp_t       meta_tcp,
  output meta_tcp_pres_t  meta_tcp_pres,
  output logic            acpt_eng,
  output logic            tx_pend,
  input  logic            tx_acpt,
  input  logic            tx_done,
  // from rx_ctl
  input tcp_opt_sack_t    sack,
  // from tx_ctl
  output logic [31:0]     last_seq,
  input  logic [31:0]     loc_ack,  // current local ack number
  output logic [31:0]     rep_ack   // local ack actually reported

);
  logic [31:0] dif; // last sequence number reported
  logic cal_dif;
  enum logic [3:0] {
    /*0*/ tx_none,
    /*1*/ tx_ka,
    /*2*/ tx_ack,
    /*3*/ tx_pld
  } tx_type;

  enum logic [2:0] {
    /*0*/ idle_s,
    /*1*/ active_s,
    /*2*/ sent_s
  } state;

  logic tx_val_arb, acc_arb;
  meta_tcp_t meta_arb_tcp; 
  meta_tcp_pres_t meta_arb_tcp_val; 
  meta_mac_t meta_arb_mac; 
  meta_ip_t  meta_arb_ip; 

  always_ff @ (posedge clk) begin
    if (rst) begin
      pld_sent     <= 0;
      ka_sent      <= 0;
      ack_sent     <= 0;
      tx_type      <= tx_none;
      tx_val_arb   <= 0;
      meta_arb_tcp <= 0;
      meta_arb_mac <= 0;
      meta_arb_ip  <= 0;
      rep_ack      <= 0;
      state        <= idle_s;
    end
    else begin
      case (state)
        idle_s : begin
          rep_ack                   <= loc_ack;
          pld_sent                  <= 0;
          ka_sent                   <= 0; 
          ack_sent                  <= 0;
          meta_arb_tcp_val.opt_sack <= (sack.val != 0);
          meta_arb_ip.loc_ref       <= tcb.loc_ref;
          meta_arb_ip.rem           <= tcb.rem_ip;
          meta_arb_ip.pro           <= TCP;
          meta_arb_ip.hop           <= 64;
          meta_arb_mac.rem          <= tcb.mac;
          meta_arb_tcp.src          <= tcb.loc_port;
          meta_arb_tcp.dst          <= tcb.rem_port;
          meta_arb_tcp.wnd          <= TCP_DEFAULT_WINDOW_SIZE;
          meta_arb_tcp.cks          <= 0;
          meta_arb_tcp.ptr          <= 0;
          meta_arb_tcp.ack          <= loc_ack;
          meta_arb_tcp.opt_sack     <= sack;
          case (sack.val)
            4'b0000 : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET;
            4'b1000 : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET + 2 + 1;
            4'b1100 : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET + 4 + 1;
            4'b1110 : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET + 6 + 1;
            4'b1111 : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET + 8 + 1;
            default : meta_arb_tcp.ofs <= TCP_DEFAULT_OFFSET;
          endcase
          if (tx_type != tx_none) state <= active_s;
          if (send_pld) begin
            tx_type <= tx_pld;
            tx_val_arb <= 1;
            meta_arb_tcp.flg <= TCP_FLAG_PSH ^ TCP_FLAG_ACK;
            meta_arb_tcp.seq <= pld_info.start;
            meta_arb_tcp.pld_len <= pld_info.lng;
            meta_arb_tcp.pld_cks <= pld_info.cks;
            meta_arb_ip.lng <= (meta_arb_tcp.ofs << 2) + meta_arb_tcp.pld_len;
          end
          else if (send_ka) begin
            tx_type <= tx_ka;
            tx_val_arb <= 1;
            meta_arb_tcp.flg <= TCP_FLAG_ACK;
            meta_arb_tcp.seq <= last_seq - 1;
            meta_arb_tcp.pld_len <= 0;
            meta_arb_tcp.pld_cks <= 0;
            meta_arb_ip.lng <= (meta_arb_tcp.ofs << 2);
          end
          else if (send_ack) begin
            tx_type <= tx_ack;
            tx_val_arb <= 1;
            meta_arb_tcp.flg <= TCP_FLAG_ACK;
            meta_arb_tcp.seq <= last_seq;
            meta_arb_tcp.pld_len <= 0;
            meta_arb_tcp.pld_cks <= 0;
            meta_arb_ip.lng <= (meta_arb_tcp.ofs << 2);
          end
        end
        // active transmission state
        active_s : begin
          if (acc_arb) tx_val_arb <= 0;
          if (tx_done) begin
            case (tx_type)
              tx_pld  : pld_sent <= 1;
              tx_ka   : ka_sent  <= 1;
              tx_ack  : ack_sent <= 1;
              default :;
            endcase
            tx_type <= tx_none;
            state   <= sent_s;
          //  meta_arb.ip_pkt_id <= meta_arb.ip_pkt_id + 1;
          end
        end
        sent_s : begin
          state <= idle_s;
          pld_sent <= 0;
          ka_sent  <= 0;
          ack_sent <= 0;
        end
        default :;
      endcase
    end
  end


  // Last repoted sequence number update
  always_ff @ (posedge clk) begin
    if (rst) last_seq <= tcb.loc_seq;                 // Load the initial sequence number
    if (send_pld) dif <= last_seq - pld_info.stop;    // 
    cal_dif <= send_pld;
    if (cal_dif & dif[31]) last_seq <= pld_info.stop;
  end

  // While connected, Engine passes tx control to other logic
  always_comb begin
    case (tcb.status)
      tcp_connected : begin
        tx_pend         = tx_val_arb;
        meta_tcp        = meta_arb_tcp;
        meta_tcp_pres   = meta_arb_tcp_val;
        meta_ip         = meta_arb_ip;
        meta_mac        = meta_arb_mac;
        acc_arb         = tx_acpt;
        acpt_eng        = 0;
      end
      default : begin
        tx_pend         = tx_val_eng;
        meta_tcp        = meta_tcp_eng;
        meta_tcp_pres    = meta_tcp_eng_pres;
        meta_ip         = meta_ip_eng;
        meta_mac        = meta_mac_eng;
        acc_arb         = 0;
        acpt_eng        = tx_acpt;
      end
    endcase
  end

endmodule : qnigma_tcp_tx_arb
