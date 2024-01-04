// Controls packet creation and tranmsssion
// 
module qnigma_tx 
  import 
    qnigma_pkg::*;
#(
  parameter mac_t  MAC_ADDR   = '0
)
(
  input logic            clk,
  input logic            rst,
  input iid_t            iid,            // Interface ID
  input pfx_t            pfx,            // Prefix (64 bits)
  input mac_t            rtr_mac,        // Router MAC
  // Phy (serialized packet sent by RTL)
  output logic [7:0]     phy_dat,        // Serial data
  output logic           phy_val,        // Serial data valid
  // Metadata (define the packet)
  input meta_mac_t       meta_mac,       // MAC matadata
  input meta_ip_t        meta_ip,        // IP metadata
  input meta_icmp_t      meta_icmp,      // ICMP metadata
  input meta_icmp_pres_t meta_icmp_pres, // ICMP present fields in meta_icmp
  input meta_tcp_t       meta_tcp,       // TCP metadata
  input meta_tcp_pres_t  meta_tcp_pres,  // TCP present fields in meta_tcp
  input meta_udp_t       meta_udp,       // UDP maradata
  input meta_dns_t       meta_dns,       // DNS query metadata
  // ControlPpkg
  input  logic           send,           // request to send packet
  input  proto_t         proto,          // set packet's protocol 
  output logic           busy,           // transmission busy
  output logic           done,            // transmission done
  // echo optional data  
  input  logic [7:0]     icmp_pld_dat,   // ICMP payload data input
  input  logic           icmp_pld_val,   // ICMP payload data valid
  output logic           icmp_pld_req,   // Request ICMP payload. Expect to output at next tick
  // tcp payload
  input  logic [7:0]     tcp_pld_dat,    // TCP payload data input
  input  logic           tcp_pld_val,    // TCP payload data valid
  output logic           tcp_pld_req     // Request TCP payload. Expect to output at next tick
);


  // Select PISO len based on which is larger
  localparam PISO_LEN = (HOST_LEN > TCP_HEADER_LEN) ? HOST_LEN : TCP_HEADER_LEN;

  meta_mac_t       meta_mac_reg;
  meta_ip_t        meta_ip_reg;
  meta_icmp_t      meta_icmp_reg;
  meta_icmp_pres_t meta_icmp_pres_reg;
  meta_tcp_t       meta_tcp_reg;
  meta_tcp_pres_t  meta_tcp_pres_reg;
  meta_tcp_pres_t  meta_tcp_pres_done;
  meta_tcp_pres_t  meta_tcp_pres_nxt;
  meta_udp_t       meta_udp_reg;
  meta_dns_t       meta_dns_reg;

  // Register data to be trasnmitted once 'send' trigger received
  always_ff @ (posedge clk) begin
    if (send) begin
      meta_mac_reg       <= meta_mac;
      meta_ip_reg        <= meta_ip;
      meta_icmp_reg      <= meta_icmp;
      meta_icmp_pres_reg <= meta_icmp_pres;
      meta_tcp_reg       <= meta_tcp;
      meta_tcp_pres_reg  <= meta_tcp_pres;
      meta_udp_reg       <= meta_udp;
      meta_dns_reg       <= meta_dns;
      proto_reg          <= proto;
    end
  end

  // Define FSM. Each state defines transmission of a certain part of the packet
  enum logic [20:0] {
  /*0*/  idle_s,            // Waiting for transmission
  /*1*/  pre_s,             // Ethernet preamble
  /*2*/  eth_hdr_s,         // Ethernet header 
  /*3*/  ip_hdr_s,          // IP header except source address
  /*4*/  ip_dst_s,          // IP header's destination IP
  /*5*/  ip_src_s,          // IP header's source IP
  /*6*/  ip_opt_rtr_alert_s,// IP header alert option
  /*7*/  hdr_ip_pseudo_s,   // Pseudo header for checksum calculation
  /*8*/  icmp_hdr_s,        // ICMP header
  /*9*/  icmp_opt_lnk_src_s,// ICMP option source link adderess
  /*A*/  icmp_opt_lnk_tar_s,// ICMP option target link adderess
  /*B*/  icmp_tar_s,        // ICMP target IP 
  /*C*/  icmp_pld_s,        // ICMP payload 
  /*D*/  tcp_hdr_s,         // TCP header
  /*E*/  tcp_opt_mss_s,     // TCP MSS option
  /*F*/  tcp_opt_scale_s,   // TCP windows scale option
  /*10*/ tcp_opt_sack_perm_s, // TCP SACK permitted option
  /*11*/ tcp_opt_sack_s,      // TCP SACK info (option except block data)
  /*12*/ tcp_opt_sack_blk_s,  // TCP SACK block data
  /*13*/ tcp_opt_nop_s,       // NOP 
  /*14*/ tcp_opt_tim_s,
  /*15*/ tcp_pld_s,
  /*16*/ udp_hdr_s,
  /*17*/ dns_hdr_s,
  /*18*/ dns_qry_str_s,
  /*19*/ dns_qry_inf_s,
  /*1A*/ crc_s,             
  /*1B*/ ifg_s              // Inter-frame gap delay for next transmission
  } state, state_nxt_tcp, state_nxt_ip;

  logic fsm_rst;
  logic load;     // load contents to shiftregs
  logic reload;   // reload after checksum computed

  logic [7:0] dat;
  logic       val;

  logic [15:0] cks;
  logic cks_cal;
  logic crc_val;
  logic crc_done;
  // sr_pdat outputs
  logic [7:0] hdr_eth_reg;
  logic [7:0] hdr_ip_reg;
  logic [7:0] hdr_ip_pseudo_reg;
  logic [7:0] hdr_icmp_reg;
  logic [7:0] ip_src_reg;
  logic [7:0] ip_dst_reg;
  logic [7:0] crc_reg;

  // TCP options
  logic [3:0] [7:0] tcp_opt_mss;
  logic [3:0] [7:0] tcp_opt_scl;
  logic [3:0] [7:0] tcp_opt_sack_perm;
  logic [1:0] [7:0] tcp_opt_sack;
  logic [7:0] [7:0] tcp_opt_sack_block;
  logic [11:0][7:0] tcp_opt_tim;
  logic [7:0] tcp_opt_sack_tot_len;
  logic [7:0] tcp_opt_sack_blk_len;
  logic [1:0] tcp_sack_blk;
  
  ///////////////////////////
  // Packet field counters //
  ///////////////////////////
  logic [                                                           2:0] ctr_pre;
  // IP
  logic [$clog2(PSEUDO_LEN                                        )-1:0] ctr_hdr_ip_pseudo;
  logic [$clog2(IP_HEADER_LEN-2*IP_BYTES                          )-1:0] ctr_hdr_ip;
  // Ethernet
  logic [$clog2(ETH_HEADER_LEN                                    )-1:0] ctr_hdr_eth;
  logic [$clog2(CRC_LEN+1                                         )-1:0] ctr_crc;
  logic [$clog2(ICMP_HEADER_TX_LEN                                )-1:0] ctr_hdr_icmp;
  logic [$clog2(TCP_HEADER_LEN                                    )-1:0] ctr_hdr_tcp;
  logic [$clog2(IP_BYTES                                          )-1:0] ctr_ip_src;
  logic [$clog2(IP_BYTES                                          )-1:0] ctr_ip_dst;
  logic [$clog2(IP_OPT_RTR_ALERT_BYTES                            )-1:0] ctr_ip_opt_rtr_alert;
  // ICMP
  logic [$clog2(IP_BYTES                                          )-1:0] ctr_icmp_tar;
  logic [$clog2(ICMP_OPT_SOURCE_LEN                               )-1:0] ctr_icmp_opt_lnk_src;
  logic [$clog2(ICMP_OPT_TARGET_LEN                               )-1:0] ctr_icmp_opt_lnk_tar;
  logic [      (ICMP_ECHO_FIFO_DEPTH                              )-1:0] ctr_icmp_pld;
  // TCP
  logic [$clog2(40)                                                -1:0] ctr_tcp_opt;
  logic [                                                           1:0] ctr_tcp_opt_nop;
  logic [$clog2($bits(byte)*TCP_OPT_MSS_LEN                       )-1:0] ctr_tcp_opt_mss;
  logic [$clog2($bits(byte)*TCP_OPT_SCL_LEN                       )-1:0] ctr_tcp_opt_scl;
  logic [$clog2($bits(byte)*TCP_OPT_SACK_PERM_LEN                 )-1:0] ctr_tcp_opt_sack_perm;
  logic [$clog2($bits(byte)*TCP_OPT_SACK_LEN                      )-1:0] ctr_tcp_opt_sack;
  logic [$clog2($bits(byte)*TCP_OPT_SACK_BLOCK_LEN*TCP_SACK_BLOCKS)-1:0] ctr_tcp_opt_sack_blk;
  logic [$clog2($bits(byte)*TCP_OPT_TIM_LEN                       )-1:0] ctr_tcp_opt_tim;
  logic [                                                          15:0] ctr_tcp_pld;
  
  logic [$clog2(UDP_HEADER_LEN                                    )-1:0] ctr_hdr_udp;
  logic [$clog2(DNS_HEADER_LEN                                    )-1:0] ctr_hdr_dns;
  logic [$clog2(DNS_QUERY_INFO_LEN                                )-1:0] ctr_dns_qry_inf;
  logic [$clog2(HOST_LEN                                          )-1:0] ctr_dns_qry_str;
  logic [$clog2(HOST_LEN                                          )-1:0] ctr_dns_qry_raw;
  logic [                                                           1:0] cur_sack_block;
  logic [$clog2(IFG                                               )-1:0] ctr_ifg;

  logic cks_done;
  logic [3:0][7:0] cur_crc;

  logic [7:0] icmp_hlen;
  logic [ICMP_HEADER_TX_LEN-1:0][7:0] hdr_icmp;
  hdr_eth_t hdr_eth;
  hdr_ip_t  hdr_ip;
  hdr_tcp_t  hdr_tcp;
  hdr_udp_t  hdr_udp;
  hdr_dns_t  hdr_dns;
 // hdr_icmp_t  hdr_icmp;
  logic shift;
  logic [ICMP_OPT_TARGET_LEN-1:0][7:0] opt_icmp_lnk_tar;
  logic [ICMP_OPT_SOURCE_LEN-1:0][7:0] opt_icmp_lnk_src;

  logic [HOST_LEN-1:0][7:0] dns_qry_str_raw;

  dns_inf_t             dns_qry_inf;

  logic [PISO_LEN-1:0][7:0] sr_pdat;

  logic [7:0] dat_reg;

  proto_t proto_reg;
  
  logic cks_ini;
  logic dns_qry_str_det;

  logic [PISO_LEN-1:0][7:0] sr;

  logic [31:0] cks_pld;
  logic val_reg;
  
  logic cks_val;
  logic cks_add;

  // Reset field counters
  logic rst_ctr;
  logic tcp_opt_aligned;
  
  // After checksum calc, reload goes '1' 
  //assign load = send || reload;

  ///////////////////
  // State machine //
  ///////////////////

  assign shift = (state != idle_s); //todo 

  always_ff @ (posedge clk) cks_ini <= (state == idle_s);
  assign busy = (state != idle_s);
  always_ff @ (posedge clk) crc_val <= (cks_done && (state != idle_s && state != pre_s && state != crc_s));
  
  // Combinationally Compute next TCP option
  // This is needed to assemble TCP packet real-time with unarranged options (bubbles in meta_tcp_pres)
  qnigma_onehot #(
    .MSB (1),
    .W ($bits(meta_tcp_pres_reg))
  ) tcp_opt_sel_inst (
    .i ({
      meta_tcp_pres_reg ^ meta_tcp_pres_done // (present and not sending)
    }),
    .o ({
      meta_tcp_pres_nxt
    })
  );              


  // select next actual TCP option based on next 
  always_comb begin
    if      (meta_tcp_pres_nxt.opt_mss      ) state_nxt_tcp = tcp_opt_mss_s;
    else if (meta_tcp_pres_nxt.opt_scale    ) state_nxt_tcp = tcp_opt_scale_s;
    else if (meta_tcp_pres_nxt.opt_sack_perm) state_nxt_tcp = tcp_opt_sack_perm_s;
    else if (meta_tcp_pres_nxt.opt_sack     ) state_nxt_tcp = tcp_opt_sack_s;
    else if (meta_tcp_pres_nxt.opt_tim      ) state_nxt_tcp = tcp_opt_tim_s;
    else begin
      if (meta_tcp_pres_reg != 0 && ctr_tcp_opt[1:0] != '1) state_nxt_tcp = tcp_opt_nop_s; 
      else state_nxt_tcp = (cks_done) ? (meta_tcp_reg.pld_len == 0) ? crc_s : tcp_pld_s : pre_s;
    end
  end

  always_comb begin
    case (proto_reg)
      tcp     : state_nxt_ip = tcp_hdr_s;
      icmp    : state_nxt_ip = icmp_hdr_s;
      dns     : state_nxt_ip = udp_hdr_s;
      default : state_nxt_ip = tcp_hdr_s;
    endcase
  end

  assign tcp_opt_aligned = ctr_tcp_opt[1:0] == 2'b11;
  
  // Tranmsit the packet
  // Handle timers and what data is shifted out later to PHY
  always_ff @ (posedge clk) begin
    if (fsm_rst || rst) begin
      state           <= idle_s;
      fsm_rst         <= 0;
      cks_done        <= 0;
      meta_tcp_pres_done <= 0;
    end
    else begin
      case (state)
        idle_s : begin
          dns_qry_str_det <= 0;
          cur_sack_block <= 0;
			    crc_done <= 0;
          if (send || cks_done) begin // either send is requested or checksum is done and we run the FSM once more with checksum enabled
            // Go through header part of the FSM twice: first to calculate checksum, then to actually transmit
            state <= (cks_done) ? pre_s : ip_src_s; // skip preamble for ckechosum calc
          end
        end
        pre_s : begin
          meta_tcp_pres_done <= 0;
          cur_sack_block <= 0;
          if (ctr_pre == 7) 
            state <= eth_hdr_s;
        end
        eth_hdr_s : begin
          if (ctr_hdr_eth == ETH_HEADER_LEN-1) 
            state <= ip_hdr_s;
        end
        ip_hdr_s : begin
          if (ctr_hdr_ip == (IP_HEADER_LEN - 2*IP_BYTES-1)) 
            state <= ip_src_s;
        end
        ip_src_s : begin
          if (ctr_ip_src == IP_BYTES-1) 
            state <= ip_dst_s;
        end
        ip_dst_s : begin
          if (ctr_ip_dst == IP_BYTES-1) // IP packet counter reached header length
            state <= (meta_ip_reg.rtr_alert) ? ip_opt_rtr_alert_s : // set router alert option 
                     (cks_done             ) ? state_nxt_ip       : // only go to hdr_ip_pseudo_s if checksum is not yet calculated
                     hdr_ip_pseudo_s;
        end
        ip_opt_rtr_alert_s : begin
          if (ctr_ip_opt_rtr_alert == IP_OPT_RTR_ALERT_BYTES-1)
            state <= (cks_done) ? state_nxt_ip : hdr_ip_pseudo_s;
        end
        hdr_ip_pseudo_s : begin
          if (ctr_hdr_ip_pseudo == PSEUDO_LEN-1) state <= state_nxt_ip;
        end
        /////////
        // TCP //
        /////////
        tcp_hdr_s : begin
          if (ctr_hdr_tcp == TCP_HEADER_LEN-1) begin
            state <= state_nxt_tcp;
            if (meta_tcp_pres_reg == 0) cks_done <= 1;
          end 
        end
        // 3WHS options
        tcp_opt_mss_s      : begin
          meta_tcp_pres_done.opt_mss <= 1;
          if (ctr_tcp_opt_mss == TCP_OPT_MSS_LEN-1) begin
            state <= state_nxt_tcp;
            if (meta_tcp_pres_nxt == 0 && tcp_opt_aligned) cks_done <= 1;
          end
        end
        // 
        tcp_opt_scale_s      : begin
          meta_tcp_pres_done.opt_scale <= 1;
          if (ctr_tcp_opt_scl == TCP_OPT_SCL_LEN-1) begin
            state <= state_nxt_tcp;
            if (meta_tcp_pres_nxt == 0 && tcp_opt_aligned) cks_done <= 1;
          end
        end
        tcp_opt_sack_perm_s : begin
          meta_tcp_pres_done.opt_sack_perm <= 1;
          if (ctr_tcp_opt_sack_perm == TCP_OPT_SACK_PERM_LEN-1) begin
            state <= state_nxt_tcp;
            if (meta_tcp_pres_nxt == 0 && tcp_opt_aligned) cks_done <= 1;
          end
        end
        // Runtime options
        tcp_opt_sack_s     : begin
          if (ctr_tcp_opt_sack == TCP_OPT_SACK_LEN-1) begin
            state <= tcp_opt_sack_blk_s;
          end          
        end
        tcp_opt_sack_blk_s     : begin
          for (int i = 0; i < TCP_SACK_BLOCKS; i = i + 1) begin
            if (ctr_tcp_opt_sack_blk == TCP_OPT_SACK_BLOCK_LEN*i-1) begin // 8 bytes for L and R
              cur_sack_block <= cur_sack_block + 1;
            end
          end
          meta_tcp_pres_done.opt_sack <= 1;
          if (ctr_tcp_opt_sack_blk == tcp_opt_sack_blk_len-1) begin // 2 for NOP
            if (meta_tcp_pres_nxt == 0 && tcp_opt_aligned) cks_done <= 1;
            state <= state_nxt_tcp;
          end
        end
        tcp_opt_tim_s      : begin
          if (ctr_tcp_opt_tim == TCP_OPT_TIM_LEN-1) begin
            if (ctr_tcp_opt[1:0] == '1) cks_done <= 1;
            state <= state_nxt_tcp;
          end
        end
        tcp_opt_nop_s      : begin
          if (ctr_tcp_opt[1:0] == '1) begin
            cks_done <= 1;
            state <= state_nxt_tcp;
          end
        end
        tcp_pld_s : begin
          if (ctr_tcp_pld == meta_tcp_reg.pld_len-1) begin
            cks_done <= 1;
            state <= crc_s;
          end
        end
        //////////
        // ICMP //
        //////////
        icmp_hdr_s : begin
          if (ctr_hdr_icmp == icmp_hlen-1) begin
            case (meta_icmp_reg.typ)
              ICMP_ECHO_REQUEST, 
              ECHO_REPLY : begin
                if (cks_done) state <= (meta_icmp_reg.echo.lng != 0) ? icmp_pld_s : crc_s;
                else state <= pre_s;
                cks_done   <= 1;
              end
              ICMP_RS    : begin
                state <= icmp_opt_lnk_src_s;
              end
              ICMP_NS    , 
              ICMP_NA    : state <= icmp_tar_s;
              ICMP_MLDV2 : state <= icmp_tar_s;
              default :;
            endcase
          end
        end
        icmp_tar_s : begin
          if (ctr_icmp_tar == IP_BYTES-1) begin
            if (!(meta_icmp_pres_reg.opt_lnk_src ||
                  meta_icmp_pres_reg.opt_lnk_tar)) begin
              cks_done <= 1;
            end
            state <= (meta_icmp_pres_reg.opt_lnk_src) ? icmp_opt_lnk_src_s :
                     (meta_icmp_pres_reg.opt_lnk_tar) ? icmp_opt_lnk_tar_s : 
                     (cks_done)                       ? crc_s : pre_s;
          end
        end
        icmp_opt_lnk_src_s : begin
          if (ctr_icmp_opt_lnk_src == ICMP_OPT_SOURCE_LEN-1) begin
            cks_done <= 1;
            state <= (cks_done) ? crc_s : pre_s;
          end
        end
        icmp_opt_lnk_tar_s : begin
          if (ctr_icmp_opt_lnk_tar == ICMP_OPT_TARGET_LEN-1) begin
            cks_done <= 1;
            state <= (cks_done) ? crc_s : pre_s;
          end
        end
        icmp_pld_s : begin
          if (ctr_icmp_pld == meta_icmp_reg.echo.lng-1) begin
            cks_done <= 1;
            state <= (cks_done) ? crc_s : pre_s;
          end
        end
        /////////
        // UDP //
        /////////
        udp_hdr_s : begin
          if (ctr_hdr_udp == UDP_HEADER_LEN-1) begin
            state <= dns_hdr_s;
          end
        end
        /////////
        // DNS //
        /////////
        dns_hdr_s : begin
          if (ctr_hdr_dns == DNS_HEADER_LEN-1) begin
            state <= dns_qry_str_s;
          end
        end
        dns_qry_str_s : begin
          if (ctr_dns_qry_str == meta_dns_reg.hst.lng) begin
            state <= dns_qry_inf_s;
          end
        end
        dns_qry_inf_s : begin
          if (ctr_dns_qry_inf == DNS_QUERY_INFO_LEN-1) begin
            cks_done <= 1;
            state <= (cks_done) ? crc_s : pre_s;
          end
        end
        /////////
        // CRC //
        /////////
        crc_s : begin
          if (ctr_crc == CRC_LEN) begin
            state <= ifg_s;			 
				    crc_done <= 1;
          end
        end
        ifg_s : begin
          if (ctr_ifg == IFG) fsm_rst <= 1;
        end
        default : fsm_rst <= 1;
      endcase
    end
  end
  
  assign done = fsm_rst;

  // Reset all counters:
  // Reload 
  assign rst_ctr = (reload || (send && !busy));

  // Increment timers related to states
  always_ff @ (posedge clk) begin
    if (rst_ctr) begin
      ctr_hdr_eth             <= 0;
      ctr_hdr_ip              <= 0;
      ctr_ip_dst              <= 0;
      ctr_ip_src              <= 0;
      ctr_ip_opt_rtr_alert    <= 0;
      ctr_hdr_ip_pseudo       <= 0;
      ctr_hdr_icmp            <= 0;
      ctr_hdr_tcp             <= 0;
      ctr_hdr_udp             <= 0;
      ctr_hdr_dns             <= 0;
      ctr_tcp_pld             <= 0;
      ctr_icmp_tar            <= 0;
      ctr_icmp_opt_lnk_src    <= 0;
      ctr_icmp_opt_lnk_tar    <= 0;
      ctr_icmp_pld            <= 0;
      ctr_tcp_opt             <= 0;
      ctr_tcp_opt_mss         <= 0;
      ctr_tcp_opt_scl         <= 0;
      ctr_tcp_opt_sack_perm   <= 0;
      ctr_tcp_opt_sack        <= 0;
      ctr_tcp_opt_sack_blk    <= 0;
      ctr_tcp_opt_tim         <= 0;
      ctr_tcp_opt_nop         <= 0;
      ctr_hdr_dns             <= 0;
      ctr_dns_qry_str         <= 0;
      ctr_dns_qry_inf         <= 0;
      ctr_crc                 <= 0;
      ctr_ifg                 <= 0;
    end
    else begin
      case (state)
        pre_s                : ctr_pre                 <= ctr_pre                 + 1;
        eth_hdr_s            : ctr_hdr_eth             <= ctr_hdr_eth             + 1;
        ip_hdr_s             : ctr_hdr_ip              <= ctr_hdr_ip              + 1;
        ip_src_s             : ctr_ip_src              <= ctr_ip_src              + 1;
        ip_dst_s             : ctr_ip_dst              <= ctr_ip_dst              + 1;
        ip_opt_rtr_alert_s   : ctr_ip_opt_rtr_alert    <= ctr_ip_opt_rtr_alert    + 1;
        hdr_ip_pseudo_s      : ctr_hdr_ip_pseudo       <= ctr_hdr_ip_pseudo       + 1;
        tcp_hdr_s            : ctr_hdr_tcp             <= ctr_hdr_tcp             + 1;
        tcp_opt_mss_s        : begin
                               ctr_tcp_opt_mss         <= ctr_tcp_opt_mss         + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_scale_s        : begin
                               ctr_tcp_opt_scl         <= ctr_tcp_opt_scl         + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_sack_perm_s   : begin
                               ctr_tcp_opt_sack_perm   <= ctr_tcp_opt_sack_perm   + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_sack_s       : begin
                               ctr_tcp_opt_sack        <= ctr_tcp_opt_sack        + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_sack_blk_s   : begin
                               ctr_tcp_opt_sack_blk    <= ctr_tcp_opt_sack_blk    + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_tim_s        : begin
                               ctr_tcp_opt_tim         <= ctr_tcp_opt_tim         + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_opt_nop_s        : begin
                               ctr_tcp_opt_nop         <= ctr_tcp_opt_nop         + 1;
                               ctr_tcp_opt             <= ctr_tcp_opt             + 1;
        end
        tcp_pld_s            : ctr_tcp_pld             <= ctr_tcp_pld             + 1;
        icmp_hdr_s           : ctr_hdr_icmp            <= ctr_hdr_icmp            + 1;
        icmp_tar_s           : ctr_icmp_tar            <= ctr_icmp_tar            + 1;
        icmp_opt_lnk_src_s   : ctr_icmp_opt_lnk_src    <= ctr_icmp_opt_lnk_src    + 1;
        icmp_opt_lnk_tar_s   : ctr_icmp_opt_lnk_tar    <= ctr_icmp_opt_lnk_tar    + 1;
        icmp_pld_s           : ctr_icmp_pld            <= ctr_icmp_pld            + 1;
        udp_hdr_s            : ctr_hdr_udp             <= ctr_hdr_udp             + 1;
        dns_hdr_s            : ctr_hdr_dns             <= ctr_hdr_dns             + 1;
        dns_qry_str_s        : ctr_dns_qry_str         <= ctr_dns_qry_str         + 1;
        dns_qry_inf_s        : ctr_dns_qry_inf         <= ctr_dns_qry_inf         + 1;
        crc_s                : ctr_crc                 <= ctr_crc                 + 1;
        ifg_s                : ctr_ifg                 <= ctr_ifg                 + 1;
        default :;
      endcase
    end
  end

  always_comb begin
    icmp_pld_req = state == icmp_pld_s && cks_done;
    tcp_pld_req = state == tcp_pld_s && cks_done;
  end

  
  logic cks_done_reg;

  always_ff @ (posedge clk) cks_done_reg <= cks_done;
  
  assign reload = ~cks_done_reg && cks_done;
  
  // Compose source IP as 
  // Can only be only few
  ip_t src_ip;
  always_comb begin
    case (meta_ip_reg.loc_ref)
      ref_ip_loc : src_ip = {16'hfe80, 48'h0, iid};
      // ref_ip_glb : src_ip = {pfx[PREFIX_LENGTH-1:0], {(($bits(ip_t)) - $bits(iid_t) - PREFIX_LENGTH){1'B0}}, iid};
      ref_ip_glb : src_ip = {pfx[PREFIX_LENGTH-1:0], iid};
      ref_ip_uns : src_ip = 0;
      default : src_ip = 0;
    endcase
  end
  
  // Router Alert option
  logic [IP_OPT_RTR_ALERT_BYTES-1:0][7:0] ip_opt_rtr_alert;

  assign ip_opt_rtr_alert = {
    meta_ip_reg.pro,
    8'h0,
    IP_OPT_RTR_ALERT,
    IP_OPT_RTR_ALERT_LEN,
    IP_OPT_RTR_ALERT_MLD,
    IP_OPT_PADN,
    IP_OPT_HOP_BY_HOP
  };

  logic [15:0] ip_pld_len;
  // Calculate IP payload length, include Router Alert case. todo: test
  assign ip_pld_len = (meta_ip_reg.rtr_alert) ? meta_ip_reg.lng - IP_OPT_RTR_ALERT_BYTES : meta_ip_reg.lng;

  // Assemble packet to be passed to shiftreg
  always_comb begin
    case (state)
      // Ethernet
      pre_s     : begin
        sr_pdat = {PREAMBLE, {(PISO_LEN-8){8'h00}}};
        load    = ctr_pre == 0;
        cks_cal = 0;
      end
      eth_hdr_s : begin
        sr_pdat = {hdr_eth,  {(PISO_LEN-$bits(hdr_eth_t)/$bits(byte)){8'h00}}};
        load    = ctr_hdr_eth == 0;
        cks_cal = 0;
      end
      // IP
      ip_hdr_s  : begin
        sr_pdat = {hdr_ip,  {(PISO_LEN-$bits(hdr_ip_t)/$bits(byte)){8'h00}}};
        load    = ctr_hdr_ip == 0;
        cks_cal = 1;
      end
      ip_src_s  : begin
        sr_pdat = {src_ip, {(PISO_LEN-IP_BYTES){8'h00}}};
        load    = ctr_ip_src == 0;
        cks_cal = 1;
      end
      ip_dst_s  : begin
        sr_pdat = {meta_ip_reg.rem, {(PISO_LEN-IP_BYTES){8'h00}}};
        load    = ctr_ip_dst == 0;
        cks_cal = 1;
      end
      ip_opt_rtr_alert_s : begin
        sr_pdat = {ip_opt_rtr_alert, {(PISO_LEN-IP_OPT_RTR_ALERT_BYTES){8'h00}}};
        load    = ctr_ip_opt_rtr_alert == 0;
        cks_cal = 0;
      end
      hdr_ip_pseudo_s : begin
        sr_pdat = {{2{8'h00}}, ip_pld_len, {3{8'h00}}, meta_ip_reg.pro, {(PISO_LEN-8){8'h00}}};
        load    = ctr_hdr_ip_pseudo == 0;
        cks_cal = 1;
      end
      // ICMP
      icmp_tar_s : begin
        sr_pdat = {meta_icmp_reg.tar, {(PISO_LEN-ICMP_HEADER_TX_LEN){8'h00}}};
        load    = ctr_icmp_tar == 0;
        cks_cal = 1;
      end
      icmp_hdr_s : begin
        sr_pdat = {hdr_icmp, {(PISO_LEN-ICMP_HEADER_TX_LEN){8'h00}}};
        load    = ctr_hdr_icmp == 0;
        cks_cal = 1;
      end
      icmp_opt_lnk_src_s : begin
        sr_pdat = {opt_icmp_lnk_src, {(PISO_LEN-ICMP_OPT_SOURCE_LEN){8'h00}}};
        load    = ctr_icmp_opt_lnk_src == 0;
        cks_cal = 1;
      end
      icmp_opt_lnk_tar_s : begin
        sr_pdat = {opt_icmp_lnk_tar, {(PISO_LEN-ICMP_OPT_TARGET_LEN){8'h00}}};
        load    = ctr_icmp_opt_lnk_tar == 0;
        cks_cal = 1;
      end
      // TCP
      tcp_hdr_s : begin
        sr_pdat = {hdr_tcp, {(PISO_LEN-TCP_HEADER_LEN){8'h00}}};
        load    = ctr_hdr_tcp == 0;
        cks_cal = 1;
      end
      tcp_opt_mss_s : begin
        sr_pdat = {tcp_opt_mss, {(PISO_LEN-TCP_OPT_MSS_LEN){8'h00}}};
        load    = ctr_tcp_opt_mss == 0;  
        cks_cal = 1;
      end
      tcp_opt_scale_s : begin
        sr_pdat = {tcp_opt_scl, {(PISO_LEN-TCP_OPT_SCL_LEN-1){8'h00}}};
        load    = ctr_tcp_opt_scl == 0;  
        cks_cal = 1;
      end
      tcp_opt_sack_perm_s : begin
        sr_pdat = {tcp_opt_sack_perm, {(PISO_LEN-TCP_OPT_SACK_PERM_LEN-2){8'h00}}};
        load    = ctr_tcp_opt_sack_perm == 0;
        cks_cal = 1;
      end
      tcp_opt_sack_s : begin
        sr_pdat = {tcp_opt_sack, {(PISO_LEN-TCP_OPT_SACK_LEN){8'h00}}};
        load    = ctr_tcp_opt_sack == 0;
        cks_cal = 1;
      end
      tcp_opt_sack_blk_s : begin
        sr_pdat = {tcp_opt_sack_block, {(2){TCP_OPT_NOP}}, {(PISO_LEN-TCP_OPT_SACK_BLOCK_LEN-2){8'h00}}};
        load    = (ctr_tcp_opt_sack_blk == TCP_OPT_SACK_BLOCK_LEN*0 || 
                   ctr_tcp_opt_sack_blk == TCP_OPT_SACK_BLOCK_LEN*1 ||
                   ctr_tcp_opt_sack_blk == TCP_OPT_SACK_BLOCK_LEN*2 ||
                   ctr_tcp_opt_sack_blk == TCP_OPT_SACK_BLOCK_LEN*3);
        cks_cal = 1;
      end
      tcp_opt_nop_s : begin
        sr_pdat = {{(3){TCP_OPT_NOP}} , {(PISO_LEN-3){8'h00}}};
        load    = ctr_tcp_opt_nop == 0;
        cks_cal = 1;
      end
      tcp_opt_tim_s : begin
        sr_pdat = {tcp_opt_tim, {(PISO_LEN-TCP_OPT_TIM_LEN){8'h00}}};
        load    = ctr_tcp_opt_tim == 0;
        cks_cal = 1;
      end
      // UDP
      udp_hdr_s : begin
        sr_pdat = {hdr_udp, {(PISO_LEN-UDP_HEADER_LEN){8'h00}}};
        load    = ctr_hdr_udp == 0;
        cks_cal = 1;
      end
      // DNS
      dns_hdr_s : begin
        sr_pdat = {hdr_dns, {(PISO_LEN-DNS_HEADER_LEN){8'h00}}};
        load    = ctr_hdr_dns == 0;
        cks_cal = 1;
      end
      dns_qry_str_s : begin
        for (int i = 0; i < PISO_LEN; i = i + 1) 
          sr_pdat[i] = host_rev[PISO_LEN-i-1];
        load = ctr_dns_qry_str == 0;
        cks_cal = 1;
      end
      dns_qry_inf_s : begin
        sr_pdat = {meta_dns_reg.inf.typ, meta_dns_reg.inf.cls, {(PISO_LEN-DNS_QUERY_INFO_LEN){8'h00}}};
        load = ctr_dns_qry_inf == 0;
        cks_cal = 1;
      end
      // FCS
      crc_s : begin
        sr_pdat = {~cur_crc[0], ~cur_crc[1], ~cur_crc[2], ~cur_crc[3], {(PISO_LEN-4){8'h00}}};
        load = ctr_crc == 1;
        cks_cal = 0;
      end  
      default : begin
        sr_pdat = 0;
        load = 0;
        cks_cal = 0;
      end  
    endcase
  end

  logic [PISO_LEN-1:0][7:0] host_rev;
  assign host_rev = meta_dns_reg.hst.str;//, {(PISO_LEN-HOST_LEN){8'h00}}};

  // On-link determination
  logic on_link;
  assign on_link = (meta_ip_reg.rem[IP_BYTES-1-:PREFIX_LENGTH/$bits(byte)] == pfx ||
                    meta_ip_reg.rem[IP_BYTES-1-:2]                         == 16'hfe80 || 
                    meta_ip_reg.rem[IP_BYTES-1]                            == 8'hff);
  
  // Header composition
  always_comb begin
    hdr_eth.etyp = IPV6;
    hdr_eth.src  = MAC_ADDR;
    hdr_eth.dst  = (on_link) ? meta_mac_reg.rem : rtr_mac;

    hdr_ip.ver   = 6;
    hdr_ip.pri   = meta_ip_reg.pri;
    hdr_ip.flo   = meta_ip_reg.flo;
    hdr_ip.lng   = meta_ip_reg.lng;
    hdr_ip.nxt   = (meta_ip_reg.rtr_alert) ? IP_OPT_HOP_BY_HOP : meta_ip_reg.pro;
    hdr_ip.hop   = meta_ip_reg.hop;

    hdr_tcp.src  = meta_tcp_reg.src;
    hdr_tcp.dst  = meta_tcp_reg.dst;
    hdr_tcp.seq  = meta_tcp_reg.seq;
    hdr_tcp.ack  = meta_tcp_reg.ack;
    hdr_tcp.ofs  = meta_tcp_reg.ofs;
    hdr_tcp.res  = 0;
    hdr_tcp.flg  = meta_tcp_reg.flg;
    hdr_tcp.wnd  = meta_tcp_reg.wnd;
    hdr_tcp.cks  = (cks_done) ? cks : 16'h0000;
    hdr_tcp.ptr  = meta_tcp_reg.ptr;

    hdr_udp.src  = meta_udp_reg.src;
    hdr_udp.dst  = meta_udp_reg.dst;
    hdr_udp.lng  = meta_udp_reg.lng;
    hdr_udp.cks  = (cks_done) ? cks : 16'h0000;

    hdr_dns.tid  = meta_dns_reg.tid;
    hdr_dns.flg  = meta_dns_reg.flg;
    hdr_dns.num  = meta_dns_reg.num;
    hdr_dns.ans  = meta_dns_reg.ans;
    hdr_dns.aut  = meta_dns_reg.aut;
    hdr_dns.add  = meta_dns_reg.add;  
  end

  // Assemble ICMP header based on type
  // MUX type-specific ICMP header and length
  always_comb begin
    case (meta_icmp_reg.typ)
      ICMP_ECHO_REQUEST, 
      ECHO_REPLY : begin
        icmp_hlen = 8;
        hdr_icmp  = {
          meta_icmp_reg.typ,
          meta_icmp_reg.cod,
          (cks_done) ? cks : 16'h0,
          meta_icmp_reg.echo.id,
          meta_icmp_reg.echo.seq,
          {(ICMP_HEADER_TX_LEN-8){8'h00}}
        };
      end
      ICMP_RS : begin
        icmp_hlen = 8;
        hdr_icmp  = {
          meta_icmp_reg.typ,
          meta_icmp_reg.cod,
          (cks_done) ? cks : 16'h0000,
          32'h0,
          {(ICMP_HEADER_TX_LEN-8){8'h00}}
        };
      end
      ICMP_RA : begin
        icmp_hlen = 16;
        hdr_icmp  = {
          meta_icmp_reg.typ,
          meta_icmp_reg.cod,
          (cks_done) ? cks : 16'h0000,
          meta_icmp_reg.rtr
        };
      end
      ICMP_NS : begin
        icmp_hlen = 8;
        hdr_icmp  = {
          meta_icmp_reg.typ,
          meta_icmp_reg.cod,
          (cks_done) ? cks : 16'h0000,
          32'h0,
          {(ICMP_HEADER_TX_LEN-8){8'h00}}
        };
      end
      ICMP_NA : begin
        icmp_hlen = 8;
        hdr_icmp  = {
          meta_icmp_reg.typ,
          meta_icmp_reg.cod,
          (cks_done) ? cks : 16'h0000,
          meta_icmp_reg.nbr,
          {(ICMP_HEADER_TX_LEN-8){8'h00}}
        };
      end
      ICMP_MLDV2 : begin
        icmp_hlen = 12;
        hdr_icmp  = {
          meta_icmp_reg.typ,            // 1
          meta_icmp_reg.cod,            // 1
          (cks_done) ? cks : 16'h0000,  // 2
          16'h0000,                     // 2
          16'h0001,                        // 1
          meta_icmp_reg.mld,            
          {(ICMP_HEADER_TX_LEN-12){8'h00}}
        };
      end
      default : begin
		    icmp_hlen = 0;
		    hdr_icmp = 0;
		  end
    endcase
  end

  always_comb begin
    opt_icmp_lnk_tar = {
      ICMP_OPT_TARGET,
      (ICMP_OPT_TARGET_LEN >> 3),
      meta_icmp_reg.opt_lnk_tar
    };
    opt_icmp_lnk_src = {
      ICMP_OPT_SOURCE,
      (ICMP_OPT_SOURCE_LEN >> 3),
      meta_icmp_reg.opt_lnk_src
    };
    
    tcp_opt_mss = {
      TCP_OPT_MSS,
      TCP_OPT_MSS_LEN,
      meta_tcp_reg.opt_mss
    };
    
    tcp_opt_scl = {
      TCP_OPT_SCL,
      TCP_OPT_SCL_LEN,
      meta_tcp_reg.opt_scale,
      TCP_OPT_NOP
    };
    
    tcp_opt_sack_perm = {
      TCP_OPT_SACK_PERM,
      TCP_OPT_SACK_PERM_LEN,
      TCP_OPT_NOP,
      TCP_OPT_NOP
    };
    
    // Count number of SACK block (assume only these possible poositions)
    case (meta_tcp_reg.opt_sack.val)
      4'b1000 : tcp_sack_blk = 0;
      4'b1100 : tcp_sack_blk = 1;
      4'b1110 : tcp_sack_blk = 2;
      4'b1111 : tcp_sack_blk = 3;
      default : tcp_sack_blk = 0;
    endcase 

    // Select current option length based on SACK blocks present
    case (tcp_sack_blk)
      0 : tcp_opt_sack_blk_len = 1*TCP_OPT_SACK_BLOCK_LEN;
      1 : tcp_opt_sack_blk_len = 2*TCP_OPT_SACK_BLOCK_LEN;
      2 : tcp_opt_sack_blk_len = 3*TCP_OPT_SACK_BLOCK_LEN;
      3 : tcp_opt_sack_blk_len = 4*TCP_OPT_SACK_BLOCK_LEN;
    endcase 

    tcp_opt_sack_tot_len = tcp_opt_sack_blk_len + TCP_OPT_SACK_LEN; 

    tcp_opt_sack = {
      TCP_OPT_SACK,
      tcp_opt_sack_tot_len
    };

    tcp_opt_sack_block = meta_tcp_reg.opt_sack.blk[TCP_SACK_BLOCKS - cur_sack_block - 1];

    tcp_opt_tim = {
      TCP_OPT_TIM,
      TCP_OPT_TIM_LEN,
      meta_tcp_reg.opt_tim.rec,
      meta_tcp_reg.opt_tim.snd,
      TCP_OPT_NOP,
      TCP_OPT_NOP
    };
  end

  always_ff @ (posedge clk) begin
    if (load) sr <= sr_pdat; 
    else if (shift) sr <= sr << $bits(byte);
  end

  always_comb begin
    if (proto_reg == tcp) cks_pld = meta_tcp_reg.pld_cks;
    else if (proto_reg == icmp) cks_pld = meta_icmp_reg.pld_cks;
    else cks_pld = 0;
  end
  
  always_comb begin
    if      (icmp_pld_val) dat = icmp_pld_dat;
    else if (tcp_pld_val)  dat = tcp_pld_dat;
    else                   dat = sr[PISO_LEN-1];
  end

  assign phy_dat = (ctr_crc[2:1] == 0) ? dat_reg : sr[PISO_LEN-1];
  
  // Send when not in val
  always_ff @ (posedge clk) val <= (state != idle_s && state != ifg_s);

  // Final valid register
  always_ff @ (posedge clk) begin
    dat_reg <= dat;
    val_reg <= val && cks_done && !reload && !crc_done;
  end

  always_ff @ (posedge clk) begin
    phy_val <= val_reg && state != ifg_s;
    cks_val <= cks_cal && !cks_done;
  end

  qnigma_cks cks_inst (
    .clk (clk),
    .rst (cks_ini),
    .dat (sr[PISO_LEN-1]),
    .val (cks_val),
    .nxt (0),
    .ini (cks_pld),
    .zer (),
    .cks (cks)
  );

  qnigma_crc32 crc32_inst (
    .clk (clk),
    .rst (fsm_rst),
    .dat (dat),
    .val (cks_done && crc_val),
    .ok  (),
    .crc (cur_crc)
  );

endmodule : qnigma_tx
