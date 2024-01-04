module qnigma_tcp_engine
  import
    qnigma_pkg::*;
(
  input logic               clk,
  input logic               rst,
  input logic               tick_ms,

  input logic               rtr_det, // Router detected
  input logic               dns_avl, // Router detected
  input logic               pfx_avl, // Prefix information available
  input logic [15:0]        mtu,     // MTU value
  
  output tcb_t              tcb,
  output logic              logic_rst, // logic reset
  // Metadata receive
  input  meta_mac_t         rx_meta_mac,
  input  meta_ip_t          rx_meta_ip,
  input  meta_tcp_t         rx_meta_tcp,
  input  meta_tcp_pres_t    rx_meta_tcp_pres,
  input  logic              rcv,
  input  logic              flt_src_port,
  input  logic              flt_dst_port,
  // Metadata transmit
  output meta_mac_t         tx_meta_mac,
  output meta_ip_t          tx_meta_ip,
  output meta_tcp_t         tx_meta_tcp,
  output meta_tcp_pres_t    tx_meta_tcp_pres,
  output logic              tx_pend,
  input  logic              tx_acpt,
  input  logic              tx_done,

  output logic              ini,            // engine's sigal to initialize local ack from tcb
  output logic              flush,          // engine request to flush tx buffer
  input  logic              flushed,        // rx_ctl response that RAM flush is complete
  input  logic              val_in,         // user TCP data valid
  // Flow numbers report to engine
  input  logic [31:0]       loc_ack,        // Current value by rx_ctl
  input  tcp_opt_sack_t     loc_sack,       // Current value by rx_ctl
  output logic [31:0]       last_seq,
  output logic              soft_rst,       // engine's request to reset transmission control
  input  logic              force_dcn,      // tx_ctl requests connection abort if retransmissions failed to increase remote seq
  input  logic              ka_dcn,
  input  logic              connect_addr,
  input  logic              connect_name,
  input  logic              listen,
  input  logic              disconnect,
  input  ip_t               rem_ip,
  input  logic [15:0]       rem_port,
  input  logic [15:0]       loc_port,
  output logic [15:0]       con_port,
  output ip_t               con_ip,
  // ICMP NS interface
  output logic              icmp_ns_req,
  input  logic              icmp_ns_err,
  input  logic              icmp_ns_acc,
  output ip_t               icmp_ip_req,
  input  mac_t              icmp_mac_rsp,
  input  logic              icmp_rsp_ok,
  // DNS hostname resolution
  output logic              dns_host_req,   // DNS request to resolvs address 
  input  logic              dns_host_acc,   // DNS request accepted by DNS logic
  input  ip_t               dns_host_addr,  // target host address
  input  logic              dns_val,        // dns_host_addr valid
  input  logic              dns_err,        // dns_host_addr invalid

  input  logic              send_ka,
  output logic              ka_sent,
  input  logic              send_pld,
  input  tcp_pld_info_t     pld_info,
  output logic              pld_sent,
  input  logic              send_ack,
  output logic              ack_sent
);
  logic fsm_rst;

  // Locally defined types
  // Connection type
  enum logic {
    tcp_client,
    tcp_server
  } con_type;

  // Connection closure type
  enum logic [3:0] {
    close_none,
    close_active,
    close_passive,
    close_reset
  } close;

  // main TCP state machine 
  enum logic [16:0] {
  /*00*/ CLOSED,
  /*01*/ LISTEN,
  /*02*/ CON_DNS_QUERY,
  /*03*/ CON_DNS_WAIT,
  /*04*/ CON_MAC_REQ,
  /*05*/ CON_MAC_WAIT,
  /*06*/ CON_SEND_SYN,
  /*07*/ CON_SYN_SENT,
  /*08*/ CON_SEND_ACK,
  /*09*/ CON_ACK_SENT,
  /*0A*/ CON_SEND_SYNACK,
  /*0B*/ CON_SYNACK_SENT,
  /*0C*/ CON_INIT,
  /*0D*/ ESTABLISHED,
  /*0E*/ FLUSH,
  /*0F*/ DCN_SEND_FIN,
  /*10*/ DCN_FIN_SENT,
  /*11*/ DCN_SEND_ACK,
  /*12*/ DCN_ACK_SENT,
  /*13*/ DCN_SEND_RST
  } state;

  logic rep_ack_sent, last_ack_rec, fin_rst;

  logic [31:0] seq_num_prng;

  logic tmr, tmr_en, tmr_rst;
  tcp_scl_t scl; // raw wnddow scale (max is 14)
  logic [31:0] rem_ack_dif;
  logic [31:0] rem_seq_dif;
  logic flt_port, syn_rec, ack_rec, rst_rec, dcn_fin_rec, syn_ack_rec;
  logic cal_dif;

  tcp_wnd_scl_t rem_wnd;
  logic set_scl;

  qnigma_prng #(.W (32), .POLY(32'hdeadbeef)) prng_seq_inst (
    .clk (clk),
    .rst (rst),
    .in  (1'b0),
    .res (seq_num_prng)
  );

  /////////////////////////////////////
  // Connect and disconnect timeouts //
  /////////////////////////////////////
  qnigma_tmr #(
    .TICKS (TCP_CONNECTION_TIMEOUT_MS),
    .AUTORESET (1))
  tmr_inst (
    .clk     (clk),
    .rst     (tmr_rst),
    .en      (tmr_en && tick_ms),
    .tmr_rst (1'b0),
    .tmr     (tmr)
  );

  always_ff @ (posedge clk) logic_rst <= state != CON_INIT && state != ESTABLISHED;

  // Reset FSM if either:
  // - connection failed to establish in time
  // - disconnect sequence failed to complete in time
  // - FSM has finished disconnecting or received RST flag
  always_ff @ (posedge clk) begin
    if (rst) fsm_rst <= 1;
    else fsm_rst <= tmr || fin_rst;
  end
  

  // Always request MAC for IP we want to connect to
  assign icmp_ip_req = rem_ip;
  // Filter packets for convenience
  assign flt_port     = rcv && flt_dst_port && flt_src_port; // Received packet's ports match current connection

  assign syn_rec      = rcv && flt_dst_port && rx_meta_tcp.flg == TCP_FLAG_SYN;                                               // SYN received for open local port
  assign syn_ack_rec  = rcv && flt_dst_port && rx_meta_tcp.flg == (TCP_FLAG_SYN | TCP_FLAG_ACK) && rx_meta_tcp.ack == tcb.loc_seq;                          // SYN ACK received for open local port
  
  assign ack_rec      =            flt_port && rx_meta_tcp.flg == TCP_FLAG_ACK                  && rx_meta_tcp.seq == tcb.rem_seq && rx_meta_tcp.ack == tcb.loc_seq;         // ACK received for 3WHS
  assign dcn_fin_rec  =            flt_port && rx_meta_tcp.flg.fin;                                                    // FIN received for current connection
  assign rst_rec      =            flt_port && rx_meta_tcp.flg.rst;                                                        // RST received for current connection

  //always_comb begin
  //  rem_ack_dif = rx_meta_tcp.ack      - tcb.rem_ack;    // bit[31] means value in tcb is higher
  //  rem_seq_dif = rx_meta_tcp.pld.stop - tcb.rem_seq;
  //end

  always_ff @ (posedge clk) cal_dif <= flt_port;
  
  logic [15:0] mtu_dif;
  logic [15:0] mss;
  
  logic pld_sending;
  logic ka_sending;
  logic ack_sending;
  
  // Limit MTU to MTU_DEFAULT
  assign mtu_dif = mtu - MTU_MSS_DIFFERENCE; // mtu_dif[15] if 
  assign mss = mtu_dif[15] ? MTU_DEFAULT : mtu_dif; 

  always_ff @ (posedge clk) begin
    if (fsm_rst) begin
      state         <= FLUSH;
      tcb.status    <= tcp_closed;
      soft_rst      <= 1;
      con_type      <= tcp_server;
      close         <= close_none;
      tmr_en        <= 0;
      tmr_rst       <= 1;
      last_ack_rec  <= 0;
      rep_ack_sent  <= 0;
      fin_rst       <= 0;
      scl           <= 0;
      tx_pend       <= 0;
      tx_meta_tcp   <= 0;
      ini           <= 0;
      icmp_ns_req   <= 0;
    end
    else begin
      case (state)
        FLUSH : begin
          //tcb.loc_seq <= tcb.rem_ack; // force local seq to remote ack, discard unacked data
          flush <= 1;          // flush transmission RAM as memory cannot be reset
          soft_rst <= 0;
          if (flushed) state <= CLOSED;
        end
        CLOSED : begin
          set_scl             <= 0;
          tcb.status          <= tcp_closed;
          tcb.rem_wnd         <= TCP_DEFAULT_WINDOW_SIZE;
          tmr_en              <= 0;
          tmr_rst             <= 0;
          flush               <= 0;
          tx_meta_tcp.pld_len <= 0;
          tx_meta_tcp.pld_cks <= 0;
          if (listen) begin
            con_type <= tcp_server; // passive open (server)
            state    <= LISTEN;
          end
          else if (connect_addr) begin
            con_type <= tcp_client; // active open (client)
            state    <= CON_MAC_REQ;
          end
          else if (connect_name) begin
            con_type <= tcp_client; // active open (client)
            if (dns_avl && rtr_det && pfx_avl) state <= CON_DNS_QUERY;
          end
        end
        CON_DNS_QUERY : begin
          tcb.loc_ref <= ref_ip_glb; // todo
          tx_meta_ip.loc_ref <= ref_ip_glb;
          dns_host_req <= 1;
          state <= CON_DNS_WAIT;
        end
        CON_DNS_WAIT : begin
          tcb.status <= tcp_wait_dns;
          tcb.rem_ip  <= dns_host_addr;
          if (dns_host_acc) dns_host_req <= 0;
          if (dns_val) begin
            //tcb.mac <= rtr_mac;
            state <= CON_SEND_SYN;
          end
          else if (dns_err) state <= CLOSED;
        end
        CON_MAC_REQ : begin
          tcb.loc_ref <= ref_ip_loc; // todo
          tx_meta_ip.loc_ref <= ref_ip_loc;
          icmp_ns_req <= 1;
          state <= CON_MAC_WAIT;
        end
        CON_MAC_WAIT : begin
          tcb.rem_ip <= rem_ip;
          if (icmp_ns_acc) icmp_ns_req <= 0;
          if (icmp_rsp_ok) begin
            tcb.mac <= icmp_mac_rsp;
            state <= CON_SEND_SYN;
          end
          else if (icmp_ns_err) state <= CLOSED;
        end
        /////////////////
        // Active Open //
        /////////////////
        CON_SEND_SYN : begin
          tmr_en                         <= 1;
          tx_pend                        <= 1;
          tcb.status                     <= tcp_connecting;
          tcb.rem_port                   <= rem_port;
          tcb.loc_port                   <= loc_port;
          tcb.loc_ack                    <= 0; // Set local ack to 0 before acquiring remote seq
          tcb.loc_seq                    <= seq_num_prng + 1;
          tx_meta_ip.rem                 <= tcb.rem_ip;
          tx_meta_ip.lng                 <= 32;
          tx_meta_ip.pro                 <= TCP;
          tx_meta_mac.rem                <= tcb.mac;
          tx_meta_tcp_pres.opt_sack_perm <= 1;
          tx_meta_tcp_pres.opt_scale     <= 1;
          tx_meta_tcp_pres.opt_mss       <= 1;
          tx_meta_tcp.opt_scale          <= 8;
          tx_meta_tcp.opt_mss            <= mss;
          tx_meta_tcp.ofs                <= 8;
          tx_meta_tcp.dst                <= rem_port;
          tx_meta_tcp.src                <= loc_port;
          tx_meta_tcp.flg                <= TCP_FLAG_SYN;
          tx_meta_tcp.wnd                <= TCP_DEFAULT_WINDOW_SIZE;
          tx_meta_tcp.cks                <= 0;
          tx_meta_tcp.ptr                <= 0;
          tx_meta_tcp.seq                <= seq_num_prng;
          tx_meta_tcp.ack                <= 0;
          state                          <= CON_SYN_SENT;
        end
        CON_SYN_SENT : begin
          if (tx_acpt) tx_pend <= 0;            // release rdy after confirmation from tx module
          if (syn_ack_rec && !tx_pend) begin    // when syn-ack received...
            // Fill TCB fields
            tcb.rem_seq <= rx_meta_tcp.seq + 1; // set remote seq num tracker as received + 1 
            tcb.rem_ack <= rx_meta_tcp.ack    ; // set remote ack num tracker as eq. to pkt ack num
            tcb.loc_ack <= rx_meta_tcp.seq + 1; // set local ack to packet's seq +
            // If scaling option present, capture it, otherwise set scale to 1 (no scale)
            if (rx_meta_tcp_pres.opt_scale) scl <= rx_meta_tcp.opt_scale;
            set_scl      <= 1;
            state <= CON_SEND_ACK;
          end
        end
        CON_SEND_ACK : begin
          set_scl                        <= 0;
          tx_pend                        <= 1;
          tx_meta_tcp.flg                <= TCP_FLAG_ACK; // ACK
          tx_meta_tcp.seq                <= tcb.loc_seq;
          tx_meta_tcp.ack                <= tcb.loc_ack;
          tx_meta_tcp.ofs                <= 5;
          tx_meta_tcp_pres.opt_sack_perm <= 0;
          tx_meta_tcp_pres.opt_scale     <= 0;
          tx_meta_tcp_pres.opt_mss       <= 0;
          tx_meta_mac.rem                <= tcb.mac;
          tx_meta_ip.lng                 <= 20;
          tx_meta_ip.pro                 <= TCP;
          tx_meta_ip.rem                 <= tcb.rem_ip;
          state                          <= CON_ACK_SENT;
        end
        CON_ACK_SENT : begin
          if (tx_acpt) tx_pend           <= 0;
          if (tx_done) state             <= CON_INIT;
        end
        //////////////////
        // Passive Open //
        //////////////////
        LISTEN : begin
         tcb.status                     <= tcp_listening;
          if (syn_rec) begin // connection request
            // create TCB for incoming connection
            tcb.mac                     <= rx_meta_mac.rem;
            tcb.rem_ip                  <= rx_meta_ip.rem;
            tcb.loc_ref                 <= rx_meta_ip.loc_ref;
            tcb.rem_port                <= rx_meta_tcp.src;
            tcb.loc_port                <= loc_port;
            tcb.loc_seq                 <= seq_num_prng;
            tcb.loc_ack                 <= rx_meta_tcp.seq + 1; // set local ack as remote seq + 1
            tcb.rem_seq                 <= rx_meta_tcp.seq + 1;
            tcb.rem_ack                 <= rx_meta_tcp.ack;
            if (rx_meta_tcp_pres.opt_scale) scl <= rx_meta_tcp.opt_scale;
            set_scl      <= 1;
            state        <= CON_SEND_SYNACK;
          end
        end
        CON_SEND_SYNACK : begin
          set_scl                       <= 0;
          tx_pend                       <= 1;
          tmr_en                        <= 1; // start connection timeout timer
          tcb.status                    <= tcp_connecting;
          tx_meta_mac.rem               <= tcb.mac;
          tx_meta_tcp.ofs               <= 8;
          tx_meta_tcp.src               <= tcb.loc_port;
          tx_meta_tcp.dst               <= tcb.rem_port;
          tx_meta_tcp.flg               <= TCP_FLAG_SYN ^ TCP_FLAG_ACK;
          tx_meta_tcp.wnd               <= TCP_DEFAULT_WINDOW_SIZE;
          tx_meta_tcp.cks               <= 0;
          tx_meta_tcp.ptr               <= 0;
          tx_meta_tcp.seq               <= tcb.loc_seq;
          tx_meta_tcp.ack               <= tcb.loc_ack;
          tx_meta_tcp_pres.opt_sack_perm <= 1;
          tx_meta_tcp_pres.opt_scale    <= 1;
          tx_meta_tcp_pres.opt_mss      <= 1;
          tx_meta_tcp.opt_scale         <= 8;
          tx_meta_tcp.opt_mss           <= mss;
          tx_meta_ip.rem                <= tcb.rem_ip;
          tx_meta_ip.loc_ref            <= tcb.loc_ref;
          tx_meta_ip.lng                <= 32;
          tx_meta_ip.pro                <= TCP;
          tx_meta_mac.rem               <= tcb.mac;
          tcb.loc_seq                   <= tcb.loc_seq + 1;
          state                         <= CON_SYNACK_SENT;
        end
        CON_SYNACK_SENT : begin
          if (tx_acpt) tx_pend <= 0; // release rdy after confirmation from tcp_tx
          if (ack_rec && !tx_pend) begin
            tcb.rem_ack <= rx_meta_tcp.ack;
            tcb.rem_seq <= rx_meta_tcp.seq;
            state       <= CON_INIT;
          end
        end
        /////////////////////
        // Pre-established //
        /////////////////////
        CON_INIT : begin
          tmr_en          <= 0;
          tx_pend         <= 0;
          ini             <= 1;
          tx_meta_tcp.cks <= 0;
          tx_meta_tcp.ptr <= 0;
          if (ini) state <= ESTABLISHED;
        end
        /////////////////
        // Established //
        /////////////////
        ESTABLISHED : begin
          /////
          /////
          /////
          /////
          tx_meta_mac.rem           <= tcb.mac;
          tx_meta_ip.loc_ref        <= tcb.loc_ref;
          tx_meta_ip.rem            <= tcb.rem_ip;
          tx_meta_ip.pro            <= TCP;
          tx_meta_ip.hop            <= 64;
          tx_meta_tcp.src           <= tcb.loc_port;
          tx_meta_tcp.dst           <= tcb.rem_port;
          tx_meta_tcp.wnd           <= TCP_DEFAULT_WINDOW_SIZE;
          tx_meta_tcp.cks           <= 0;
          tx_meta_tcp.ptr           <= 0;
          tx_meta_tcp.ack           <= loc_ack;
          tx_meta_tcp.opt_sack      <= loc_sack;
          tx_meta_tcp_pres.opt_mss       <= 0;
          tx_meta_tcp_pres.opt_scale     <= 0;
          tx_meta_tcp_pres.opt_sack_perm <= 0;
          tx_meta_tcp_pres.opt_tim       <= 0;
          tx_meta_tcp_pres.opt_sack      <= (loc_sack.val != 0);
          case (loc_sack.val)
            4'b0000 : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET;
            4'b1000 : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET + 2 + 1;
            4'b1100 : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET + 4 + 1;
            4'b1110 : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET + 6 + 1;
            4'b1111 : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET + 8 + 1;
            default : tx_meta_tcp.ofs <= TCP_DEFAULT_OFFSET;
          endcase
          if (!pld_sending && !ka_sending && !ack_sending) begin // None are being transmitted (tx_pend low)
            // sometimes ACK to SYN-ACK is lost and remote end does not 
            // know that the connection is established
            // we retransmit these ACKs if we See SYN-ACK
            if (send_pld && !pld_sent) begin
              pld_sending         <= 1;
              tx_pend             <= 1;
              tx_meta_tcp.flg     <= TCP_FLAG_PSH ^ TCP_FLAG_ACK;
              tx_meta_tcp.seq     <= pld_info.start;
              tx_meta_tcp.pld_len <= pld_info.lng;
              tx_meta_tcp.pld_cks <= pld_info.cks;
              tx_meta_ip.lng      <= (tx_meta_tcp.ofs << 2) + pld_info.lng;
            end
            else if (send_ka && !ka_sent)  begin
              ka_sending          <= 1;
              tx_pend             <= 1;
              tx_meta_tcp.flg     <= TCP_FLAG_ACK;
              tx_meta_tcp.seq     <= last_seq - 1;
              tx_meta_tcp.pld_len <= 0;
              tx_meta_tcp.pld_cks <= 0;
              tx_meta_ip.lng      <= (tx_meta_tcp.ofs << 2);
            end
            else if ((syn_ack_rec | send_ack) && !ack_sent) begin
              ack_sending         <= 1;
              tx_pend             <= 1;
              tx_meta_tcp.flg     <= TCP_FLAG_ACK;
              tx_meta_tcp.seq     <= last_seq;
              tx_meta_tcp.pld_len <= 0;
              tx_meta_tcp.pld_cks <= 0;
              tx_meta_ip.lng      <= (tx_meta_tcp.ofs << 2);
            end
          end
          else begin
            if (tx_acpt) tx_pend <= 0; // one of the packet types is being transmitted
            if (tx_done) begin
              pld_sending <= 0;
              ka_sending <= 0;
              ack_sending <= 0;
            end
          end
          // report requests fulfuleld for other logic
          pld_sent <= (pld_sending && tx_done);
          ka_sent  <= ( ka_sending && tx_done);
          ack_sent <= (ack_sending && tx_done);
          /////
          ini <= 0;
          // tx_meta_ip.lng   <= TCP_HEADER_LEN;
          ////////////////
          // Update TCB //
          ////////////////
          tcb.status       <= tcp_connected;
          if (tx_done) begin
            tcb.loc_ack  <= loc_ack; // loc_ack is updated upon sending packet with that Ack
            tcb.loc_sack <= loc_sack;
          end
          if (val_in) tcb.loc_seq <= tcb.loc_seq + 1; // loc_seq in tcb is constantly updated from tx control
          if (flt_port) begin
            rem_ack_dif  <= rx_meta_tcp.ack      - tcb.rem_ack;
            rem_seq_dif  <= rx_meta_tcp.pld.stop - tcb.rem_seq;
            tcb.rem_sack <= rx_meta_tcp.opt_sack;
          end
          if (cal_dif) begin
            if (!rem_ack_dif[31]) tcb.rem_ack <= rx_meta_tcp.ack;    
            if (!rem_seq_dif[31]) tcb.rem_seq <= rx_meta_tcp.pld.stop; // remote sequence of remote host is computed by adding payload lng
          end
          /////////////////////
          // Closure request //
          /////////////////////
          if      (ka_dcn || force_dcn || disconnect) close <= close_active;
          else if (dcn_fin_rec                      ) close <= close_passive;
          else if (rst_rec                          ) close <= close_reset;
          if (!tx_pend && !pld_sending && !ka_sending && !ack_sending) begin
            case (close)
              close_active  : state <= DCN_SEND_FIN;
              close_passive : state <= DCN_SEND_ACK;
              close_reset   : state <= DCN_SEND_RST;
              default       :;
            endcase
          end
        end
        ////////////////////////
        // Connection closure //
        ////////////////////////
        DCN_SEND_FIN : begin
          tcb.status          <= tcp_disconnecting;
          tx_pend             <= 1;           // 
          tmr_en              <= 1;           // start connecion timeout timer
          tx_meta_tcp.flg     <= (close == close_passive) ? TCP_FLAG_FIN ^ TCP_FLAG_ACK : TCP_FLAG_FIN;
          tx_meta_tcp.ofs     <= 5;           // no options
          tx_meta_tcp.seq     <= tcb.loc_seq; // report current Seq/Ack numbers
          tx_meta_tcp.ack     <= tcb.loc_ack;
          tx_meta_tcp.pld_len <= 0;
          tx_meta_tcp.pld_cks <= 0;
          tx_meta_tcp_pres    <= 0;
          tx_meta_ip.lng      <= (tx_meta_tcp.ofs << 2);
          state               <= DCN_FIN_SENT;
        end
        DCN_FIN_SENT : begin // fin_wait_1 and fin_wait_2;
          if (tx_acpt) tx_pend <= 0;
          if (close == close_passive) begin
            if (flt_port && rx_meta_tcp.flg == TCP_FLAG_ACK) fin_rst <= 1;
          end
          else if (close == close_active) begin // Need to received 2 packets z
            if (flt_port) begin
              if      (rx_meta_tcp.flg ==                TCP_FLAG_ACK) last_ack_rec <= 1;
              else if (rx_meta_tcp.flg == TCP_FLAG_FIN ^ TCP_FLAG_ACK) fin_rst      <= last_ack_rec;
            end
            if (last_ack_rec && rx_meta_tcp.flg.fin) state <= DCN_SEND_ACK;
          end
        end
        DCN_SEND_ACK : begin
          tcb.status          <= tcp_disconnecting;
          tx_pend             <= 1;
          tmr_en              <= 1;
          tx_meta_tcp.flg     <= TCP_FLAG_ACK;
          tx_meta_tcp.ofs     <= 5;
          tx_meta_tcp.seq     <= (close == close_active) ? tcb.loc_seq + 1 : tcb.loc_seq;
          tx_meta_tcp.ack     <= tcb.loc_ack + 1;
          tx_meta_tcp.pld_len <= 0;
          tx_meta_tcp.pld_cks <= 0;
          tx_meta_tcp_pres    <= 0;
          tx_meta_ip.lng      <= (tx_meta_tcp.ofs << 2);
          state               <= DCN_ACK_SENT;
          tcb.loc_ack         <= tcb.loc_ack + 1;
        end
        DCN_ACK_SENT : begin
          if (tx_acpt) tx_pend <= 0;
          // check for tx_eng_tcp.done before sending FIN after ACK
          if (tx_done) begin
            if (close == close_passive) state   <= DCN_SEND_FIN;
            if (close == close_active ) fin_rst <= 1;
          end
        end
        DCN_SEND_RST : begin
          tx_pend              <= 1;
          tmr_en               <= 1;
          tx_meta_tcp.flg      <= TCP_FLAG_RST ^ TCP_FLAG_ACK;
          tx_meta_tcp.ofs      <= 5;
          tx_meta_tcp.seq      <= tcb.loc_seq;
          tx_meta_tcp.ack      <= tcb.loc_ack;
          tx_meta_tcp.pld_len  <= 0;
          tx_meta_tcp.pld_cks  <= 0;
          tx_meta_tcp_pres     <= 0;
          tx_meta_ip.lng       <= (tx_meta_tcp.ofs << 2);
          if (tx_done) fin_rst <= 1;
        end
      endcase
      // Not related to FSM
      tcb.rem_wnd <= rem_wnd;
      tcb.mss     <= mss;
      tx_meta_ip.hop <= 64;
    end
  end

  logic cal_last_seq;
  logic [31:0] last_seq_dif;

  always_ff @ (posedge clk) cal_last_seq <= send_pld;

  always_ff @ (posedge clk) if (send_pld) last_seq_dif <= last_seq - pld_info.stop;    // 
  // Last repoted sequence number update
  always_ff @ (posedge clk) begin
    if      (logic_rst)                       last_seq <= tcb.loc_seq;                 // Load the initial sequence number
    else if (cal_last_seq & last_seq_dif[31]) last_seq <= pld_info.stop;
  end

  // Provide current values remote host when connected 
  always_ff @ (posedge clk) begin
    con_ip   = tcb.rem_ip;
    con_port = tcb.rem_port;
  end

qnigma_tcp_wnd tcp_wnd_inst (
  .clk     (clk),
  .set_scl (set_scl),         // Update on 'scl'
  .scl     (scl),             // scale (as in TCP WS option) or 0 if none (1 to 15)
  .upd     (flt_port),        // ports match
  .raw     (rx_meta_tcp.wnd), // 
  .wnd     (rem_wnd)
);

endmodule : qnigma_tcp_engine
