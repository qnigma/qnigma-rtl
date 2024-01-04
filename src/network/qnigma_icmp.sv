module qnigma_icmp
  import
    qnigma_pkg::*;
#(
  parameter mac_t  MAC_ADDR   = 48'h0
)
(
  input  logic            clk,
  input  logic            rst,
  input  logic            tick_ms,
  input  logic            tick_s,
  output iid_t            iid,

  output pfx_t            pfx,
  output logic            pfx_avl,

  output ip_t             dns_ip,
  output logic            dns_pres,
  output logic            dns_avl,
  input  logic            dns_rs_send,

  output ip_t             rtr_ip,
  output mac_t            rtr_mac,
  output logic            rtr_det,

  output logic [15:0]     mtu,

  input  meta_mac_t       rx_meta_mac,
  input  meta_ip_t        rx_meta_ip,
  input  meta_icmp_t      rx_meta_icmp,
  input  meta_icmp_pres_t rx_meta_icmp_pres,
  input  logic            rcv,
  output meta_mac_t       tx_meta_mac,
  output meta_ip_t        tx_meta_ip,
  output meta_icmp_t      tx_meta_icmp,
  output meta_icmp_pres_t tx_meta_icmp_pres,
  output logic            tx_pend,
  input  logic            tx_acpt,
  input  logic            tx_done,
  input  logic [7:0]      pld_dat_rx,
  input  logic            pld_val_rx,
  input  logic            echo_req_tx,
  output logic [7:0]      pld_dat_tx,
  output logic            pld_val_tx,
  // ICMP NS requests (for TCP)
  input  logic            ns_req,
  output logic            ns_err,
  output logic            ns_acc,
  input  ip_t             ip_req,
  output mac_t            mac_rsp,
  output logic            rsp_ok
);

  logic tmr_rst;
  logic send;
  
  logic [23:0] rnd;
  ip_t lla;
  ip_t glb;
  
  // Echo checksum
  logic [31:0] cks;

  
  // Try counters
  logic [$clog2(DAD_TRIES      +1)-1:0]    dad_try;
  logic [$clog2(MLD_TRIES      +1)-1:0]    mld_try;
  logic [$clog2(NDP_TRIES      +1)-1:0]    ndp_try;
  logic [$clog2(RTR_TRIES      +1)-1:0]    rs_try;

  // Timers (1ms per bit)
  logic [$clog2(DAD_TIMEOUT_MS +1)-1:0]    dad_tmr;
  logic [$clog2(MLD_RETRANSMIT_MS +1)-1:0] mld_tmr;
  logic [$clog2(NDP_TIMEOUT_MS +1)-1:0]    ndp_tmr;
  logic [$clog2(RTR_TIMEOUT_MS +1)-1:0]    rs_tmr;
  
  logic [7:0] [7:0] def_iid; // Default Interface ID
  logic [7:0] [7:0] rnd_iid; // Random Interface ID
  logic [15:0][7:0] sol_mcs; // Solicited Multicast
  logic [15:0][7:0] mld_mcs; // MLD multicast
  
  logic dad_fail;
    
  logic ns_run;
  logic ns_tx;
  // addemble MLD record
  icmp_mld_t mld_rec;
  qnigma_prng #(
    .W    (24),
    .POLY (24'b100000000010000000000011),
    .SEED (24'hdeadbe)
  ) prng_inst (
    .clk (clk),
    .rst (tmr_rst),
    .in  (),
    .res (rnd)
  );
  
  logic fifo_full, fifo_empty;

  // Echo payload FIFO
  qnigma_fifo_sc #(
    .D (ICMP_ECHO_FIFO_DEPTH),
    .W ($bits(byte))
  ) fifo_inst(
    .clk       (clk),
    .rst       (rst || tx_done),

    .write     (pld_val_rx && !fifo_full),
    .data_in   (pld_dat_rx),

    .read      (echo_req_tx && !fifo_empty),
    .data_out  (pld_dat_tx),
    .valid_out (pld_val_tx),

    .full      (fifo_full),
    .empty     (fifo_empty)
  );


  enum logic [6:0] {
  /*00*/ GEN_LLA,
  /*01*/ MLD_SEND,
  /*02*/ MLD_SENDING,
  /*03*/ MLD_WAIT,
  /*04*/ DAD_SEND,
  /*05*/ DAD_SENDING,
  /*06*/ DAD_WAIT,
  /*07*/ RA_WAIT,
  /*08*/ RS_SEND,
  /*09*/ RS_SENDING,
  /*0A*/ IDLE,
  /*0B*/ WAIT_TX
  } state;

  // Assemble IPs
  always_comb begin
    def_iid = {MAC_ADDR[5][7:2], 1'b1, MAC_ADDR[5][0], MAC_ADDR[4:3], 16'hfffe, MAC_ADDR[2:0]};
    rnd_iid = {MAC_ADDR[5][7:2], 1'b1, MAC_ADDR[5][0], MAC_ADDR[4:3], 16'hfffe, rnd          };
    sol_mcs = {16'hff02, 72'h0, 8'h01, 8'hff, lla[2:0]     };
    mld_mcs = {16'hff02, 88'h0              , MLD_MULTICAST};
    iid     = lla[7:0];
    glb     = {pfx, lla[7:0]};
  end

  // If reply detected for DAD NS, consider DAD attempt failed
  always_ff @ (posedge clk) begin
    if (rst) begin
      dad_fail <= 0;
    end
    else begin
      if (rcv && 
      rx_meta_icmp.typ == ICMP_NA && 
      rx_meta_icmp.tar_ref == ref_ip_loc) dad_fail <= 1;
      else if (state == DAD_WAIT) dad_fail <= 0;
    end
  end

  // Asser pending reg and release it once packet is sent
  always_ff @ (posedge clk) if (send) tx_pend <= 1; else if (tx_acpt) tx_pend <= 0;
  
  /////////////////////////
  // Metadata structures //
  /////////////////////////
  meta_mac_t       
    tx_meta_mac_dad,
    tx_meta_mac_mld,
    tx_meta_mac_rs,
    tx_meta_mac_ns,
    tx_meta_mac_na,
    tx_meta_mac_echo;
  meta_ip_t        
    tx_meta_ip_dad,
    tx_meta_ip_mld,
    tx_meta_ip_rs,
    tx_meta_ip_ns,
    tx_meta_ip_na,
    tx_meta_ip_echo;
  meta_icmp_t      
    tx_meta_icmp_dad,
    tx_meta_icmp_mld,
    tx_meta_icmp_rs,
    tx_meta_icmp_ns,
    tx_meta_icmp_na,
    tx_meta_icmp_echo;
  meta_icmp_pres_t 
    tx_meta_icmp_pres_dad,
    tx_meta_icmp_pres_mld,
    tx_meta_icmp_pres_rs,
    tx_meta_icmp_pres_ns,
    tx_meta_icmp_pres_na,
    tx_meta_icmp_pres_echo;

  // Compose metadata fields based on packet type
  always_comb begin
    // DAD NS request
    tx_meta_mac_dad                    = 0;
    tx_meta_ip_dad                     = 0;
    tx_meta_icmp_dad                   = 0;
    tx_meta_icmp_pres_dad              = 0;
    tx_meta_mac_dad.rem                = {MAC_SOLICITED_MULTICAST, lla[2:0]};
    tx_meta_ip_dad.pro                 = ICMPV6;
    tx_meta_ip_dad.loc_ref             = ref_ip_uns;
    tx_meta_ip_dad.rem                 = sol_mcs;
    tx_meta_ip_dad.lng                 = ICMP_NS_LEN + IP_BYTES;
    tx_meta_ip_dad.hop                 = 255;
    tx_meta_icmp_dad.typ               = ICMP_NS;
    tx_meta_icmp_dad.cod               = 0;
    tx_meta_icmp_dad.tar               = lla;
    // MLD update
    tx_meta_mac_mld                    = 0;
    tx_meta_ip_mld                     = 0;
    tx_meta_icmp_mld                   = 0;
    tx_meta_icmp_pres_mld              = 0;
    tx_meta_mac_mld.rem                = {MAC_ALL_NODES_MULTICAST, MLD_MULTICAST};
    tx_meta_ip_mld.pro                 = ICMPV6;
    tx_meta_ip_mld.loc_ref             = ref_ip_loc;
    tx_meta_ip_mld.rem                 = mld_mcs;
    tx_meta_ip_mld.lng                 = ICMP_MLDV2_LEN + IP_BYTES;
    tx_meta_ip_mld.hop                 = 255;
    tx_meta_ip_mld.rtr_alert           = 1;
    tx_meta_icmp_mld.typ               = ICMP_MLDV2;
    tx_meta_icmp_mld.cod               = 0;
    tx_meta_icmp_mld.tar               = sol_mcs;  // MLD uses tar field to indicate group. Pass 
    tx_meta_icmp_mld.mld               = mld_rec;  // MLD uses tar field to indicate group
    // RS
    tx_meta_mac_rs                     = 0;
    tx_meta_ip_rs                      = 0;
    tx_meta_icmp_rs                    = 0;
    tx_meta_icmp_pres_rs               = 0;
    tx_meta_mac_rs.rem                 = {MAC_ALL_NODES_MULTICAST, MAC_ALL_RTR};
    tx_meta_ip_rs.pro                  = ICMPV6;
    tx_meta_ip_rs.loc_ref              = ref_ip_loc;
    tx_meta_ip_rs.rem                  = IP_MULTICAST_ALL_RTR;
    tx_meta_ip_rs.lng                  = ICMP_RS_LEN + ICMP_OPT_SOURCE_LEN;
    tx_meta_ip_rs.hop                  = 255;
    tx_meta_icmp_rs.typ                = ICMP_RS;
    tx_meta_icmp_rs.cod                = 0;
    tx_meta_icmp_rs.opt_lnk_src        = MAC_ADDR;
    tx_meta_icmp_pres_rs.opt_lnk_src   = 1;
    // NA reply
    tx_meta_mac_na                     = 0;
    tx_meta_ip_na                      = 0;
    tx_meta_icmp_na                    = 0;
    tx_meta_icmp_pres_na               = 0;
    tx_meta_mac_na.rem                 = rx_meta_mac.rem; // Reply to requesting device MAC 
    tx_meta_ip_na.pro                  = ICMPV6;
    tx_meta_ip_na.loc_ref              = (rx_meta_icmp.tar_ref == ref_ip_glb) ? ref_ip_glb : ref_ip_loc;
    tx_meta_ip_na.rem                  = rx_meta_ip.rem;
    tx_meta_ip_na.lng                  = ICMP_NA_LEN + IP_BYTES + ICMP_OPT_TARGET_LEN;
    tx_meta_ip_na.hop                  = 255;
    tx_meta_icmp_na.typ                = ICMP_NA;
    tx_meta_icmp_na.pld_cks            = 0;
    tx_meta_icmp_na.tar                = (rx_meta_icmp.tar_ref == ref_ip_glb) ? glb : lla;
    tx_meta_icmp_na.nbr.flags.sol      = 1;
    tx_meta_icmp_na.nbr.flags.ovr      = (rx_meta_icmp.tar_ref != ref_ip_glb);
    tx_meta_icmp_na.opt_lnk_tar        = MAC_ADDR;
    tx_meta_icmp_pres_na.opt_lnk_tar   = 1;
    // NS request
    tx_meta_mac_ns                     = 0;
    tx_meta_ip_ns                      = 0;
    tx_meta_icmp_ns                    = 0;
    tx_meta_icmp_pres_ns               = 0;
    tx_meta_mac_ns.rem                 = {MAC_ALL_NODES_MULTICAST, MAC_ALL_DEV};
    tx_meta_ip_ns.pro                  = ICMPV6;
    tx_meta_ip_ns.loc_ref              = ref_ip_loc;
    tx_meta_ip_ns.rem                  = {16'hff02, 80'h1, 8'hff, ip_req[2:0]};
    tx_meta_ip_ns.lng                  = ICMP_NS_LEN + IP_BYTES + ICMP_OPT_SOURCE_LEN;
    tx_meta_ip_ns.hop                  = 255;
    tx_meta_icmp_ns.typ                = ICMP_NS;
    tx_meta_icmp_ns.pld_cks            = 0;
    tx_meta_icmp_ns.tar                = ip_req;
    tx_meta_icmp_ns.opt_lnk_src        = MAC_ADDR;
    tx_meta_icmp_pres_ns.opt_lnk_src   = 1;
    // Echo reply
    tx_meta_mac_echo                   = 0;
    tx_meta_ip_echo                    = 0;
    tx_meta_icmp_echo                  = 0;
    tx_meta_icmp_pres_echo             = 0;
    tx_meta_mac_echo.rem               = rx_meta_mac.rem;
    tx_meta_ip_echo.pro                = ICMPV6;
    tx_meta_ip_echo.loc_ref            = rx_meta_ip.loc_ref;
    tx_meta_ip_echo.rem                = rx_meta_ip.rem;
    tx_meta_ip_echo.lng                = ICMP_ECHO_LEN + rx_meta_icmp.echo.lng;
    tx_meta_ip_echo.hop                = 255;
    tx_meta_icmp_echo.typ              = ECHO_REPLY;
    tx_meta_icmp_echo.pld_cks          = cks;
    tx_meta_icmp_echo.echo.seq         = rx_meta_icmp.echo.seq;
    tx_meta_icmp_echo.echo.id          = rx_meta_icmp.echo.id;
    tx_meta_icmp_echo.echo.lng         = rx_meta_icmp.echo.lng;
  end

  // Simple MLD logic. Just send MLD once
  always_comb begin
    mld_rec.rec_typ     = CHANGE_TO_INCLUDE_MODE; // ?
    mld_rec.aux_dat_len = 0; // ?
    mld_rec.num_src     = 0; // ?
  end


  always_ff @ (posedge clk) begin
    if (rst) begin
      state   <= DAD_SEND;
      tmr_rst <= 1;
		  rs_tmr  <= 0;
		  dad_tmr <= 0;
		  rs_try  <= 0;
		  dad_try <= 0;
		  mld_try <= 0;
      lla     <= {16'hfe80, 48'h0, def_iid};
    end
    else begin
      case (state)
        /////////////////////////
        // Node initialization //
        /////////////////////////
        GEN_LLA : begin /* Generate default LLA */
          state   <= DAD_SEND;
          rs_try  <= 0;
          dad_try <= 0;
          lla     <= {16'hfe80, 48'h0, rnd_iid};
        end
        /////////////////////////////////
        // Duplicate Address Detection //
        /////////////////////////////////
        DAD_SEND : begin /* Send NDP - test for LLA uniqueness. aka DAD */
          send               <= 1;
          state              <= DAD_SENDING;
          tmr_rst            <= 1;
          dad_try            <= dad_try + 1;
          dad_tmr            <= 0;
          tx_meta_mac        <= tx_meta_mac_dad;
          tx_meta_ip         <= tx_meta_ip_dad;
          tx_meta_icmp       <= tx_meta_icmp_dad;
          tx_meta_icmp_pres  <= tx_meta_icmp_pres_dad;
        end
        DAD_SENDING : begin
          send <= 0;
          if (tx_done) state <= DAD_WAIT;
        end
        DAD_WAIT : begin
          tmr_rst <= 0;
          if (tick_ms) dad_tmr <= dad_tmr + 1;
          if (dad_fail) state <= GEN_LLA;
          else if (dad_tmr == DAD_TIMEOUT_MS) state <= (dad_try == DAD_TRIES) ? MLD_SEND : DAD_SEND; // Tried several times, but no reply -> continue
        end
        /////////////////////////////////////////
        // Multicast Listener Discovery Report //
        /////////////////////////////////////////
        MLD_SEND : begin /* Send NDP - test for LLA uniqueness. aka DAD */
          send                  <= 1;
          state                 <= MLD_SENDING;
          tmr_rst               <= 1;
          mld_try               <= mld_try + 1;
          mld_tmr               <= 0;
          tx_meta_mac           <= tx_meta_mac_mld;
          tx_meta_ip            <= tx_meta_ip_mld;
          tx_meta_icmp          <= tx_meta_icmp_mld;
          tx_meta_icmp_pres     <= tx_meta_icmp_pres_mld;
        end
        MLD_SENDING : begin
          send <= 0;
          if (tx_done) state <= MLD_WAIT;
        end
        MLD_WAIT : begin
          tmr_rst <= 0;
          if (tick_ms) mld_tmr <= mld_tmr + 1;
          if (mld_tmr == MLD_RETRANSMIT_MS) state <= (mld_try == MLD_TRIES) ? RS_SEND : MLD_SEND;
        end
        //////////////////////
        // Router discovery //
        //////////////////////
        RS_SEND : begin /* Send NDP - test for LLA uniqueness. aka DAD */
          send               <= 1;
          state              <= RS_SENDING;
          tmr_rst            <= 1;
          rs_try             <= rs_try + 1;
          rs_tmr             <= 0;
          tx_meta_mac        <= tx_meta_mac_rs;
          tx_meta_ip         <= tx_meta_ip_rs;
          tx_meta_icmp       <= tx_meta_icmp_rs;
          tx_meta_icmp_pres  <= tx_meta_icmp_pres_rs;
        end
        RS_SENDING : begin
          send <= 0;
          if (tx_done) state <= RA_WAIT;
        end
        RA_WAIT : begin
          tmr_rst <= 0;
          if (tick_ms) rs_tmr <= rs_tmr + 1;
          if (rcv && rx_meta_icmp.typ == ICMP_RA) begin// Node with same IP found
            state <= IDLE;
          end
          else if (rs_tmr == RTR_TIMEOUT_MS) // DAD timed out
            state <= (rs_try == RTR_TRIES) ? IDLE : RS_SEND; // Tried several times, but no reply -> continue
        end
        IDLE : begin
          if (rcv) begin
            if (rx_meta_icmp.typ == ICMP_NS) begin
              send              <= 1;
              state             <= WAIT_TX;
              tx_meta_mac       <= tx_meta_mac_na;
              tx_meta_ip        <= tx_meta_ip_na;
              tx_meta_icmp      <= tx_meta_icmp_na;
              tx_meta_icmp_pres <= tx_meta_icmp_pres_na;
            end
            else if (rx_meta_icmp.typ == ICMP_ECHO_REQUEST) begin
              send              <= 1;
              state             <= WAIT_TX;
              tx_meta_mac       <= tx_meta_mac_echo;
              tx_meta_ip        <= tx_meta_ip_echo;
              tx_meta_icmp      <= tx_meta_icmp_echo;
              tx_meta_icmp_pres <= tx_meta_icmp_pres_echo;
            end
          end
          else if (ns_tx) begin
            send              <= 1;
            state             <= WAIT_TX;
            tx_meta_mac       <= tx_meta_mac_ns;
            tx_meta_ip        <= tx_meta_ip_ns;
            tx_meta_icmp      <= tx_meta_icmp_ns;
            tx_meta_icmp_pres <= tx_meta_icmp_pres_ns;
          end
          else if (dns_rs_send) begin
            send              <= 1;
            state             <= WAIT_TX;
            tx_meta_mac       <= tx_meta_mac_rs;
            tx_meta_ip        <= tx_meta_ip_rs;
            tx_meta_icmp      <= tx_meta_icmp_rs;
            tx_meta_icmp_pres <= tx_meta_icmp_pres_rs;
          end
        end
        WAIT_TX : begin
          send <= 0;
          if (tx_done) state <= IDLE;
        end
        default :;
      endcase
    end
  end


  // Set and reset NS runnning status
  always_ff @ (posedge clk) begin
    if (ns_req) ns_run <= 1;
    else if (rsp_ok || ns_err) ns_run <= 0;
  end

  // NS retransmit and timeout
  always_ff @ (posedge clk) begin
    if (ns_run) begin
      ns_acc <= 1;
      if (tick_ms) begin
        if (ndp_tmr == 0) begin
          ns_tx <= 1;
          ndp_tmr <= DAD_TIMEOUT_MS;
          ndp_try <= ndp_try + 1;
          if (ndp_try == NDP_TRIES) ns_err <= 1;
        end
        else ndp_tmr <= ndp_tmr - 1;
      end
      else ns_tx <= 0;
    end
    else begin
      ns_acc <= 0;
      ndp_try <= 0;
      ns_err <= 0;
      ns_tx <= 0;
      ndp_tmr <= 0;
    end
  end

  // ICMP NS reply processing
  always_ff @ (posedge clk) begin
    if (ns_run &&
        rcv && 
        rx_meta_icmp.typ == ICMP_NA && 
        rx_meta_icmp_pres.opt_lnk_tar && 
        rx_meta_ip.rem == ip_req) begin
      rsp_ok <= 1;
      mac_rsp <= rx_meta_icmp.opt_lnk_tar;
    end
    else rsp_ok <= 0;
  end

  qnigma_rtr_inf rtr_inf_inst (
    .clk            (clk), 
    .rst            (rst),
    .tick_ms        (tick_ms),
    .tick_s         (tick_s),
    .rcv            (rcv && rx_meta_icmp.typ == ICMP_RA), // RA received

    .meta_ip        (rx_meta_ip), // Router IP
    .meta_mac       (rx_meta_mac), // Router MAC
    .meta_icmp      (rx_meta_icmp), // Router online in local network
    .meta_icmp_pres (rx_meta_icmp_pres), // Router online in local network

    .pfx            (pfx),
    .pfx_avl        (pfx_avl),

    .dns_ip         (dns_ip),
    .dns_pres       (dns_pres),
    .dns_avl        (dns_avl),

    .rtr_ip         (rtr_ip),
    .rtr_mac        (rtr_mac),
    .rtr_det        (rtr_det),
    .mtu            (mtu)
  );  

  qnigma_icmp_echo_cks qnigma_icmp_echo_cks_inst (

    .clk (clk),
    .rst (tx_done), // tx_done
    .ful (fifo_full), // fifo_full

    .vin (pld_val_rx), // 
    .din (pld_dat_rx), // 

    .cks (cks)
  ); 

endmodule : qnigma_icmp
