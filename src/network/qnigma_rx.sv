// Receive raw MAC packets, decode etyp, src/dst MAC and check FCS
module qnigma_rx
  import 
    qnigma_pkg::*;
#(
  parameter mac_t  MAC_ADDR   = '0
)
(
  input  logic            clk,
  input  logic            rst,

  input  iid_t            iid,
  input  pfx_t            pfx,
  input  logic [7:0]      dns_idx,
  input  logic [15:0]     tcp_loc_port,

  input  logic [7:0]      phy_dat,
  input  logic            phy_val,
  output meta_mac_t       meta_mac,
  output meta_ip_t        meta_ip,
  output meta_icmp_t      meta_icmp,
  output meta_icmp_pres_t meta_icmp_pres,
  output meta_tcp_t       meta_tcp,
  output meta_tcp_pres_t  meta_tcp_pres,
  output meta_udp_t       meta_udp,
  output meta_dns_t       meta_dns,
  output logic            rcv,
  output proto_t          proto,

  output logic [7:0]      icmp_pld_dat,
  output logic            icmp_pld_val,
 
  output logic [7:0]      tcp_pld_dat,
  output logic            tcp_pld_val,
  output logic            tcp_pld_sof
);

  // Calculate number shiftregister taps to be able to fit all fields 
  localparam SIPO_LEN = (HOST_LEN > TCP_HEADER_LEN) ? HOST_LEN : TCP_HEADER_LEN;

  logic rdy, hit, mcast, lla, glb;      
  
  logic crc_val;

  logic [7:0] dat;
  logic val, sof, eof;
  
  logic crc_ok;
  logic fsm_rst;
  
  logic val_reg;
  logic done;

  // Errors
  logic err_ver;
  logic err_pro;

  // Packet field counters
  logic [2:0]                                 ctr_pre;
  logic [$clog2(ETH_HEADER_LEN          +1)-1:0] ctr_hdr_eth;
  logic [$clog2(ICMP_HEADER_RX_LEN      +1)-1:0] ctr_hdr_icmp;
  logic [$clog2(IP_BYTES             +1)-1:0] ctr_icmp_tar;
  logic [$clog2(IP_BYTES             +1)-1:0] ctr_ip_src;
  logic [$clog2(IP_BYTES             +1)-1:0] ctr_ip_dst;
  logic [$clog2(IP_HEADER_LEN-2*IP_BYTES+1)-1:0] ctr_hdr_ip;
  logic [$clog2(UDP_HEADER_LEN          +1)-1:0] ctr_hdr_udp;
  logic [7                                :0] ctr_icmp_opt;
  logic [7                                :0] ctr_tcp_opt;
  logic [       ICMP_ECHO_FIFO_DEPTH    -1:0] ctr_icmp_dat;
  logic [$clog2(DNS_HEADER_LEN          +1)-1:0] ctr_dns_hdr; // max offset * 4
  logic [$clog2(TCP_MAX_LEN          +1)-1:0] ctr_tcp; // header (20) + options (40) = 60
  logic [15:0]                                ctr_ip;
  logic [$clog2(SIPO_LEN          +1)-1:0] ctr_dns_qry_str;
  logic [$clog2(IP_BYTES             +1)-1:0] ctr_dns_ans_adr;
  logic [$clog2(DNS_ANSWER_INFO_LEN  +1)-1:0] ctr_dns_ans_inf;
  logic [$clog2(DNS_QUERY_INFO_LEN   +1)-1:0] ctr_dns_qry_inf;
  logic [SIPO_LEN-1:0][7:0] sipo;
  
  opt_pri_t icmp_opt_fld, tcp_opt_fld;
  logic [1:0] tcp_sack_opt_cur_block;
  logic [7:0] icmp_hlen;
  logic [7:0] icmp_opt_len;
  logic [7:0] icmp_opt_typ;
  
  logic [7:0] tcp_hlen;
  logic [7:0] tcp_opt_len;
  logic [7:0] tcp_opt_typ;

  logic cks_done;
  logic icmp_hdr_done;
  logic mac_hit;
  logic icmp_hit;
  logic tcp_hit;
  logic ip_hit;
  logic icmp_tar_hit;
  logic udp_dns_hit;

  logic shift;                    // Shift the main SIPO
  
  // These signals are high when appropriate device IPv6 address is detected at SIPO output
  logic hit_ip_loc; // Link-Local adderss
  logic hit_ip_glb; // Global address with current prefix from RA
  logic hit_ip_mcs; // Multicast addres
  logic hit_ip_sol; // Solicited Node Multicast address

  // These signals are high when appropriate device MAC is detected at SIPO output
  logic hit_mac_dev; // Actual MAC address
  logic hit_mac_mcs; // Multicast MAC address
  logic hit_mac_sol; // Solicited Multicast MAC address

  logic [15:0] tcp_pld_len;
  
  logic [7:0] cur_dns_srv;

  logic is_ipv6;
  logic [5:0] tcp_ofs_bytes;

  logic [15:0] checksum;
  logic ip_pld;
    
  logic ip_pld_done; // IP payload fully received based on reported IP packet length in header
  
  logic [3:0] ctr_rdnss; // IP byte counter for each DNS IP. Automatically overflows

  logic tcp_pld_val_reg;
  logic [7:0] phy_dat_reg;
  
  logic cks_val; // when high, calculate incoming checksum to verify with reported
  
  logic [15:0] cks;
  logic cks_ok;

  enum logic [16:0] {
  /*0*/  idle_s       ,
  /*1*/  preamble_s   ,
  /*2*/  eth_hdr_s    ,
  /*3*/  ip_hdr_s     ,
  /*4*/  ip_src_s     ,
  /*5*/  ip_dst_s     ,
  /*6*/  icmp_hdr_s   ,
  /*7*/  icmp_opt_s   ,
  /*8*/  icmp_tar_s   ,
  /*9*/  data_write_s ,
  /*A*/  data_read_s  ,
  /*B*/  udp_hdr_s    ,
  /*C*/  tcp_hdr_s    ,
  /*D*/  tcp_opt_s    ,
  /*E*/  dns_hdr_s    ,
  /*F*/  dns_qry_str_s,
  /*10*/ dns_qry_inf_s,
  /*11*/ dns_ans_inf_s,
  /*12*/ dns_ans_adr_s,
  /*13*/ icmp_pld_s   ,
  /*15*/ tcp_pld_s
  } state;


  always @ (posedge clk) done <= crc_ok || rst || (val_reg & ~phy_val);
  always @ (posedge clk) fsm_rst <= done;
  always @ (posedge clk) val_reg <= phy_val;

  //////////////////////
  // Packet filtering //
  //////////////////////
  always_ff @ (posedge clk) begin
    // UDP DNS
    udp_dns_hit  <= (meta_udp.src      == DNS_QUERY_PORT);
    // MAC
    mac_hit      <= (meta_mac.loc_ref != ref_mac_non   ||
                     meta_icmp.typ    == ICMP_RA); // Router advertiesemnts are passed through  
    // IP
    ip_hit       <= (meta_ip.loc_ref   != ref_ip_non    );
    // ICMP
    case (meta_icmp.typ)
      (ICMP_NS)            : icmp_hit <= 
        (meta_icmp.tar_ref == ref_ip_loc ||
         meta_icmp.tar_ref == ref_ip_sol ||
         meta_icmp.tar_ref == ref_ip_glb ); 
      (ICMP_NA),
      (ICMP_RA),
      (ICMP_RS), 
      (ICMP_ECHO_REQUEST), 
      (ECHO_REPLY)         : icmp_hit <= 1;
      default              : icmp_hit <= 0;
    endcase
    // TCP
    tcp_hit      <= (meta_tcp.dst      == tcp_loc_port  );
  end

  // All events must be 
  always_ff @ (posedge clk) begin
    hit <= mac_hit && ip_hit && crc_ok && cks_ok;
  end

  // Select what protocols packet is currently being processed
  always_comb begin
    case (meta_ip.pro) 
      (ICMPV6) : proto = icmp;
      (TCP)    : proto = tcp;
      (UDP)    : proto = dns;
      default  : proto = icmp;
    endcase
  end
  
  // Based on current protocol, select what is the condition for passing the packet
  always_ff @ (posedge clk) begin
    case (proto) 
      (icmp)  : rcv <= hit && icmp_hit;
      (tcp)   : rcv <= hit && tcp_hit;
      (dns)   : rcv <= hit && udp_dns_hit;
      default : rcv <= 0;
    endcase
  end

  ///////////////////////////////////////////////
  // Main Serial-In Parallel-Out shiftregister //
  ///////////////////////////////////////////////
  qnigma_sipo_mac #(
    .WIDTH  (8),
    .LENGTH (SIPO_LEN)
  ) sipo_inst (
    .clk   (clk    ),
    .rst   (rst    ),
    .ser_i (phy_dat),
    .shift (shift  ),
    .par_o (sipo   )
  );

  ///////////////////////
  // Set packet fields //
  ///////////////////////

  /////////////////////////////////
  // Latch procol data (demux) //
  /////////////////////////////////
  // To keep sipo short, 'cut' packets and partially latch info with each step
  // This net controls when and where current contents of sipo are latched

  enum logic [4:0] {
  /*0*/  load_none,
  /*1*/  load_eth_hdr,
  /*2*/  load_ip_hdr,
  /*3*/  load_ip_src,
  /*4*/  load_ip_dst,      
  /*5*/  load_icmp_hdr_cmn, // common across all ICMP messages
  /*6*/  load_icmp_hdr_var, // differs across types
  /*7*/  load_icmp_tar,     // target (for NA/NS)
  /*8*/  load_icmp_opt_pfx_inf,      // options
  /*9*/  load_icmp_opt_pfx_val,     
  /*A*/  load_icmp_opt_lnk_src,
  /*B*/  load_icmp_opt_lnk_tar,
  /*C*/  load_icmp_opt_rdnss_inf,
  /*D*/  load_icmp_opt_rdnss_ip,
  /*E*/  load_icmp_opt_mtu,
  /*F*/  load_icmp_echo,
  /*10*/ load_tcp_hdr,
  /*11*/ load_udp_hdr,
  /*12*/ load_dns_hdr,
  /*13*/ load_dns_qry_str,
  /*14*/ load_dns_qry_inf,
  /*15*/ load_dns_ans_inf,
  /*16*/ load_dns_ans_adr,
  /*17*/ load_tcp_ofs,
  /*18*/ load_tcp_opt_mss,
  /*19*/ load_tcp_opt_tim,
  /*1A*/ load_tcp_opt_sack_perm,
  /*1B*/ load_tcp_opt_scl,
  /*1C*/ load_tcp_opt_sack,
  /*1D*/ load_tcp_opt_sack_blk
  } load;

  always_comb begin
    hit_ip_loc = sipo[IP_BYTES-1:0] == {16'hfe80, 48'h0, iid};
    // hit_ip_glb = sipo[IP_BYTES-1:0] == {pfx[PREFIX_LENGTH-1:0], {(($bits(ip_t)) - $bits(iid_t) - PREFIX_LENGTH){1'b0}}, iid}; // todo
    // hit_ip_glb = sipo[IP_BYTES-1:0] == {pfx[PREFIX_LENGTH-1:0], {(($bits(ip_t)) - $bits(iid_t) - PREFIX_LENGTH){1'b0}}, iid}; // todo
    hit_ip_glb = sipo[IP_BYTES-1:0] == {pfx[PREFIX_LENGTH-1:0], iid}; // todo
    hit_ip_sol = sipo[IP_BYTES-1:0] == {16'hff02, 64'h0, 16'h0001, 8'hff, iid[2:0]};
    hit_ip_mcs = sipo[IP_BYTES-1:0] == {16'hff02, 104'h0, 8'h01};
  end

  always_comb begin
    hit_mac_dev = sipo[13:8] == MAC_ADDR;
    hit_mac_mcs = sipo[13:8] == {8'h33, 8'h33, 8'h00, 8'h00, 8'h00, 8'h01};
    hit_mac_sol = sipo[13:8] == {8'h33, 8'h33, 8'hff, iid[2:0]};
  end

  always_ff @ (posedge clk) begin
    tcp_pld_len = meta_ip.lng - (meta_tcp.ofs << 2);
  end

  // Load metadata from SIPO...
  always_ff @ (posedge clk) begin
    if (fsm_rst) begin // Packet done, reset
      cur_dns_srv       <= 0;
      meta_icmp_pres    <= 0;
      meta_tcp_pres     <= 0;
      // Initially, all references to local addresses are None
      meta_mac.loc_ref  <= ref_mac_non;
      meta_ip.loc_ref   <= ref_ip_non;  
      meta_icmp.tar_ref <= ref_ip_non;
    end
    else begin
      case (load)
        load_none :;
        load_eth_hdr : begin /* Ethernet header */
          if      (hit_mac_dev) meta_mac.loc_ref <= ref_mac_dev;
          else if (hit_mac_mcs) meta_mac.loc_ref <= ref_mac_glb;
          else if (hit_mac_sol) meta_mac.loc_ref <= ref_mac_sol;
          else                  meta_mac.loc_ref <= ref_mac_non;
          meta_mac.rem  <= sipo[7:2];
          meta_mac.etyp <= sipo[1:0];
        end
        load_ip_hdr : begin /* IP header (except addresses) */
          err_ver     <= (sipo[7][7:4] != 4'h6);
          meta_ip.pri <= {sipo[7][3:0], sipo[6][7:4]};
          meta_ip.flo <= {sipo[6][3:0], sipo[5:4]};
          meta_ip.lng <= sipo[3:2];
          meta_ip.pro <= sipo[1];
          meta_ip.hop <= sipo[0];
        end
        load_ip_src : begin /* Source IP address */
          meta_ip.rem <= sipo;
        end
        load_ip_dst : begin /* Destination IP address */
          if      (hit_ip_loc) meta_ip.loc_ref <= ref_ip_loc;
          else if (hit_ip_glb) meta_ip.loc_ref <= ref_ip_glb;
          else if (hit_ip_sol) meta_ip.loc_ref <= ref_ip_sol;
          else if (hit_ip_mcs) meta_ip.loc_ref <= ref_ip_mcs;
          else                 meta_ip.loc_ref <= ref_ip_non;
        end
        load_icmp_hdr_cmn : begin /* ICMP Mandatory headers */
          meta_icmp.echo.lng <= 0;
          meta_icmp.typ      <= sipo[3];
          meta_icmp.cod      <= sipo[2];
          checksum           <= sipo[1:0];
        end
        load_icmp_hdr_var : begin /* ICMP Type-specific headers */
          case (meta_icmp.typ)
            ICMP_ECHO_REQUEST,
            ECHO_REPLY       : begin
              meta_icmp.echo.id   <= sipo[3:2];
              meta_icmp.echo.seq  <= sipo[1:0];
            end
           // ICMP_RS    : begin
           // end
            ICMP_RA   : begin
              meta_icmp.rtr.cur_hop_lim  <= sipo[11];
              meta_icmp.rtr.flags        <= sipo[10];
              meta_icmp.rtr.lifetime     <= sipo[9:8];
              meta_icmp.rtr.reach_time   <= sipo[7:4];
              meta_icmp.rtr.retrans_time <= sipo[3:0];
            end
            ICMP_NS  : begin

            end
            ICMP_NA : begin

            end
            default :;
          endcase
        end
        load_icmp_tar : begin /* ICMP Target field */
          meta_icmp_pres.tar   <= 1;
          //meta_icmp.tar_ref       <= sipo[IP_BYTES-1:0];
          if      (hit_ip_loc) meta_icmp.tar_ref <= ref_ip_loc;
          else if (hit_ip_glb) meta_icmp.tar_ref <= ref_ip_glb;
          else if (hit_ip_sol) meta_icmp.tar_ref <= ref_ip_sol;
          else if (hit_ip_mcs) meta_icmp.tar_ref <= ref_ip_mcs;
          else                 meta_icmp.tar_ref <= ref_ip_non;
        end
        load_icmp_echo : begin
          meta_icmp.echo.lng <= ctr_icmp_dat;
        end
        load_icmp_opt_lnk_src : begin /* ICMP Source link-local address option */
          meta_icmp_pres.opt_lnk_src <= 1;  
          meta_icmp.opt_lnk_src     <= sipo[$bits(mac_t)/8-1:0];
        end
        load_icmp_opt_lnk_tar : begin /* ICMP Target link-local address option */
          meta_icmp_pres.opt_lnk_tar <= 1;   
          meta_icmp.opt_lnk_tar     <= sipo[$bits(mac_t)/8-1:0];
        end
        load_icmp_opt_pfx_inf : begin /* ICMP Prefix information option (info) */
          meta_icmp_pres.opt_pfx_inf       <= 1;
          meta_icmp.opt_pfx_inf.lng        <= sipo[13];
          meta_icmp.opt_pfx_inf.flags      <= sipo[12];
          meta_icmp.opt_pfx_inf.pfx_life   <= sipo[11:8];
          meta_icmp.opt_pfx_inf.pref_life  <= sipo[7:4];
          meta_icmp.opt_pfx_inf.reserved   <= sipo[3:0];
        end
        load_icmp_opt_pfx_val  : begin /* ICMP Prefix information option (prefix value) */
          meta_icmp.opt_pfx_inf.pfx <= sipo[IP_BYTES-1-:$bits(pfx_t)/$bits(byte)];
        end
        load_icmp_opt_rdnss_inf : begin
          meta_icmp_pres.opt_rdnss      <= 1;
          meta_icmp.opt_rdnss.lifetime  <= sipo[1:0];
        end
        load_icmp_opt_rdnss_ip : begin
          cur_dns_srv <= cur_dns_srv + 1;
          meta_icmp_pres.dns_addr <= 1;
          if (cur_dns_srv <= dns_idx) 
            meta_icmp.opt_rdnss.dns_addr  <= sipo[15:0];
        end
        load_icmp_opt_mtu  : begin /* ICMP MTU option */
          meta_icmp_pres.opt_mtu <= 1;   
          meta_icmp.opt_mtu <= sipo[3:0];
        end
        load_tcp_ofs : begin
          meta_tcp.ofs <= sipo[0][7:4];
        end
        load_tcp_hdr : begin
          meta_tcp.src <= sipo[19:18];
          meta_tcp.dst <= sipo[17:16];
          meta_tcp.seq <= sipo[15:12];
          meta_tcp.ack <= sipo[11:8];
          meta_tcp.flg <= {sipo[7][3:0], sipo[6]};
          meta_tcp.wnd <= sipo[5:4];
          meta_tcp.cks <= sipo[3:2];
          meta_tcp.ptr <= sipo[1:0];
          meta_tcp.pld.lng   <= tcp_pld_len;
          meta_tcp.pld.start <= sipo[15:12];
          meta_tcp.pld.stop  <= sipo[15:12] + tcp_pld_len;
        end
        load_udp_hdr : begin
          meta_udp.src <= sipo[7:6];
          meta_udp.dst <= sipo[5:4];
          meta_udp.lng <= sipo[3:2];
          meta_udp.cks <= sipo[1:0];
        end
        load_tcp_opt_mss      : begin
          meta_tcp_pres.opt_mss <= 1;
          meta_tcp.opt_mss <= sipo[TCP_OPT_MSS_LEN-1:0];
        end
        load_tcp_opt_scl      : begin
          meta_tcp_pres.opt_scale <= 1;
          meta_tcp.opt_scale <= sipo[TCP_OPT_SCL_LEN-1:0];
        end
        load_tcp_opt_sack_perm      : begin
          meta_tcp.opt_sack_perm <= 1;
        end
        load_tcp_opt_sack      : begin
          meta_tcp_pres.opt_sack <= 1;
          case (tcp_opt_len) // Only SACK has variable lng
            8       : meta_tcp.opt_sack.val <= 4'b1000;
            16      : meta_tcp.opt_sack.val <= 4'b1100;
            24      : meta_tcp.opt_sack.val <= 4'b1110;
            32      : meta_tcp.opt_sack.val <= 4'b1111;
            default : meta_tcp.opt_sack.val <= 4'b0000;
          endcase
        end
        load_tcp_opt_sack_blk      : begin
          meta_tcp_pres.opt_sack <= 1;
          case (tcp_sack_opt_cur_block) // Only SACK has variable lng
            0 : meta_tcp.opt_sack.blk[3] <= sipo[TCP_OPT_SACK_BLOCK_LEN-1:0];
            1 : meta_tcp.opt_sack.blk[2] <= sipo[TCP_OPT_SACK_BLOCK_LEN-1:0];
            2 : meta_tcp.opt_sack.blk[1] <= sipo[TCP_OPT_SACK_BLOCK_LEN-1:0];
            3 : meta_tcp.opt_sack.blk[0] <= sipo[TCP_OPT_SACK_BLOCK_LEN-1:0];
          endcase
        end
        load_tcp_opt_tim      : begin
          meta_tcp_pres.opt_tim <= 1;
          meta_tcp.opt_tim <= sipo[TCP_OPT_TIM_LEN-1:0];
        end
        load_dns_hdr : begin
          meta_dns.tid <= sipo[11:10];
          meta_dns.flg <= sipo[9:8];
          meta_dns.num <= sipo[7:6];
          meta_dns.ans <= sipo[5:4];
          meta_dns.aut <= sipo[3:2];
          meta_dns.add <= sipo[1:0];
        end
        load_dns_qry_inf : begin

        end
        load_dns_qry_str : begin
          meta_dns.hst.str <= sipo[HOST_LEN-1:0];
        end
        load_dns_ans_adr : begin // AAAA address
          meta_dns.addr <= sipo[IP_BYTES-1:0];
        end
        load_dns_ans_inf : begin // AAAA address
          meta_dns.inf.typ <= sipo[9:8];
          meta_dns.inf.cls <= sipo[7:6];
          meta_dns.inf.ttl <= sipo[5:2];
          meta_dns.inf.lng <= sipo[1:0];
        end
 
        default : meta_icmp_pres.opt_mtu <= 0;
      endcase

    end
  end

  assign is_ipv6 = (meta_mac.etyp == IPV6);

  ///////////////////////////////
  // ICMP header length decode //
  ///////////////////////////////
  always_comb begin
    case (meta_icmp.typ)
      ICMP_ECHO_REQUEST,
      ECHO_REPLY : icmp_hlen = ICMP_ECHO_LEN;
      ICMP_RS    : icmp_hlen = ICMP_RS_LEN;
      ICMP_RA    : icmp_hlen = ICMP_RA_LEN;
      ICMP_NS    : icmp_hlen = ICMP_NS_LEN;
      ICMP_NA    : icmp_hlen = ICMP_NA_LEN;
      default    : icmp_hlen = '1;
    endcase
  end

  ///////////////////////////////////
  // Packet deconing state machine //
  ///////////////////////////////////

  
  assign tcp_ofs_bytes = meta_tcp.ofs << 2;

  always_ff @ (posedge clk) begin : ff_fsm
    if (fsm_rst || rst) begin
      ctr_pre           <= 0;
      ctr_hdr_eth       <= 0;
      ctr_hdr_ip        <= 0;
      ctr_ip_dst        <= 0;
      ctr_ip_src        <= 0;
      ctr_hdr_icmp      <= 0;
      ctr_tcp           <= 1;
      ctr_dns_hdr       <= 0;
      ctr_dns_qry_str   <= 0;
      ctr_dns_ans_adr   <= 0;
      ctr_icmp_opt      <= 0;
      ctr_hdr_udp       <= 0;
      ctr_icmp_tar      <= 0;
      ctr_dns_ans_inf   <= 0;
      ctr_dns_qry_inf   <= 0;
      ctr_icmp_dat      <= 1;
      ctr_tcp_opt       <= 1;
      state             <= idle_s;
      icmp_opt_fld      <= opt_pri_typ;
      tcp_opt_fld       <= opt_pri_typ;
      err_pro           <= 0;
      icmp_hdr_done     <= 0;
      tcp_sack_opt_cur_block <= 0;
    end
    else begin
      case (state)
        idle_s : begin
          if (phy_val && phy_dat == 8'h55) begin
            state <= preamble_s;
          end
        end
        preamble_s : begin
          if (phy_dat == 8'h55) ctr_pre <= ctr_pre + 1;
          if (ctr_pre == 6) begin
             if (phy_dat == 8'hd5) state <= eth_hdr_s;
          end
        end
        eth_hdr_s : begin
          ctr_hdr_eth <= ctr_hdr_eth + 1;
          if (ctr_hdr_eth == ETH_HEADER_LEN-1) state <= ip_hdr_s;
        end
        ip_hdr_s : begin
          ctr_hdr_ip <= ctr_hdr_ip + 1;
          if (ctr_hdr_ip == IP_HEADER_LEN-2*IP_BYTES-1) state <= ip_src_s;
        end
        ip_src_s : begin
          ctr_ip_src <= ctr_ip_src + 1;
          if (ctr_ip_src == IP_BYTES-1) state <= ip_dst_s;
        end
        ip_dst_s : begin
          ctr_ip_dst <= ctr_ip_dst + 1;
          if (ctr_ip_dst == IP_BYTES-1) begin
            case (meta_ip.pro)
              ICMPV6 : state <= icmp_hdr_s;
              UDP    : state <= udp_hdr_s;
              TCP    : state <= tcp_hdr_s;
              default : err_pro <= 1;
            endcase
          end
        end
        icmp_hdr_s : begin
          if (ctr_hdr_icmp == icmp_hlen-1) begin
            case (meta_icmp.typ)
              ICMP_NA,
              ICMP_NS : state <= icmp_tar_s;
              ICMP_ECHO_REQUEST          : begin
                state <= icmp_pld_s;
                icmp_hdr_done <= 1;
              end
              default               : state <= icmp_opt_s;
            endcase
          end
          ctr_hdr_icmp <= ctr_hdr_icmp + 1;
        end
        icmp_tar_s : begin
          ctr_icmp_tar <= ctr_icmp_tar + 1;
          if (ctr_icmp_tar == IP_BYTES-1) state <= icmp_opt_s;
        end
        icmp_opt_s : begin
          case (icmp_opt_fld)
            (opt_pri_typ) : begin
              icmp_opt_fld <= opt_fld_len;
              icmp_opt_typ <= phy_dat;
              ctr_icmp_opt <= 0;
            end
            (opt_fld_len) : begin
              icmp_opt_fld <= opt_fld_dat;
              icmp_opt_len <= (phy_dat << 3) - 3;
            end
            (opt_fld_dat) : begin
              if (ctr_icmp_opt == icmp_opt_len) begin
                icmp_opt_fld <= opt_pri_typ;
                ctr_icmp_opt <= 0;
              end
              else 
                ctr_icmp_opt <= ctr_icmp_opt + 1;
            end
            default:;
          endcase
        end
        tcp_hdr_s : begin
          ctr_tcp <= ctr_tcp + 1;
          if (ctr_tcp == TCP_HEADER_LEN) begin
            state <= (sipo[7][7:4] == TCP_DEFAULT_OFFSET) ? tcp_pld_s : tcp_opt_s; // get hdr lng direcrly from sipo
          end
        end
        tcp_opt_s : begin
          ctr_tcp <= ctr_tcp + 1;
          if (ctr_tcp == tcp_ofs_bytes) state <= tcp_pld_s;
          case (tcp_opt_fld)
            (opt_pri_typ) : begin
              if (phy_dat != TCP_OPT_NOP) tcp_opt_fld <= opt_fld_len;
              tcp_opt_typ <= phy_dat;
              ctr_tcp_opt <= 1;
            end
            (opt_fld_len) : begin
              tcp_opt_fld <= (tcp_opt_typ == TCP_OPT_SACK_PERM) ? opt_pri_typ : opt_fld_dat; // done with len, only SACK PERM doesn't have data filed
              tcp_opt_len <= phy_dat - 2;
            end
            (opt_fld_dat) : begin
              ctr_tcp_opt <= ctr_tcp_opt + 1;
              for (int i = 1; i < TCP_SACK_BLOCKS + 1; i = i + 1)
                if (ctr_tcp_opt == TCP_OPT_SACK_LEN + i*TCP_OPT_SACK_BLOCK_LEN)
                  tcp_sack_opt_cur_block <= tcp_sack_opt_cur_block + 1; // track currently received SACK block  
              if (ctr_tcp_opt == tcp_opt_len) // done with data, next field is type again
                tcp_opt_fld <= opt_pri_typ;
            end
            default:;
          endcase
        end
        udp_hdr_s : begin
          ctr_hdr_udp <= ctr_hdr_udp + 1;
          if (ctr_hdr_udp == UDP_HEADER_LEN-1) begin
            state <= dns_hdr_s;
          end
        end
        dns_hdr_s : begin
          ctr_dns_hdr <= ctr_dns_hdr + 1;
          if (ctr_dns_hdr == DNS_HEADER_LEN-1) begin
            state <= dns_qry_str_s;
          end
        end
        dns_qry_str_s : begin
          ctr_dns_qry_str <= ctr_dns_qry_str + 1;
          if (phy_dat == "") begin
            state <= dns_qry_inf_s;
          end
        end
        dns_qry_inf_s : begin
          ctr_dns_qry_inf <= ctr_dns_qry_inf + 1;
          if (ctr_dns_qry_inf == DNS_QUERY_INFO_LEN-1) begin
            state <= dns_ans_inf_s;
          end
        end
        dns_ans_inf_s : begin
          ctr_dns_ans_inf <= ctr_dns_ans_inf + 1;
          if (ctr_dns_ans_inf == DNS_ANSWER_INFO_LEN-1) begin
            state <= dns_ans_adr_s;
          end
        end
        dns_ans_adr_s : begin
          ctr_dns_ans_adr <= ctr_dns_ans_adr + 1;
          if (ctr_dns_ans_adr == meta_udp.lng-1) begin
            //state <= dns_str_s;
          end
        end
        tcp_pld_s : begin
          icmp_hdr_done <= 0;
        end
        icmp_pld_s : begin /* ICMP echo data */
          ctr_icmp_dat <= ctr_icmp_dat + 1;
        end
        default :;
      endcase
    end
  end
  
  ///////////////////////////
  // State machine outputs //
  ///////////////////////////

  always_comb begin
    case (state)
      idle_s      : begin
        load     = load_none;
        cks_val  = 0;
        shift    = 0;
        crc_val  = 0;
        ip_pld   = 0;
      end
      preamble_s  : begin
        load     = load_none;
        cks_val  = 0;
        shift    = 0;
        crc_val  = 0;
        ip_pld   = 0;
      end
      eth_hdr_s   : begin
        load     = (ctr_hdr_eth == ETH_HEADER_LEN-1) ? load_eth_hdr : load_none;
        cks_val  = 0;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 0;
      end
      ip_hdr_s    : begin
        load     = (ctr_hdr_ip == IP_HEADER_LEN-2*IP_BYTES-1) ? load_ip_hdr : load_none;
        cks_val  = ctr_hdr_ip[2]; // Length, proto and hops fields
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 0;
      end
      ip_src_s    : begin
        load     = (ctr_ip_src == IP_BYTES-1) ? load_ip_src : load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 0;
      end
      ip_dst_s    : begin
        load     = (ctr_ip_dst == IP_BYTES-1) ? load_ip_dst : load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 0;
      end
      // latch the common header part (type, code, checksum)
      // then, icmp_hlen is calculated based on type
      icmp_hdr_s  : begin
        if      (ctr_hdr_icmp == ICMP_HEADER_LEN_MIN-1)
          load = load_icmp_hdr_cmn;
        else if (ctr_hdr_icmp == icmp_hlen-1)
          load = load_icmp_hdr_var;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      icmp_tar_s  : begin
        if (ctr_icmp_tar == IP_BYTES-1) 
          load = load_icmp_tar;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      icmp_opt_s : begin
        case (icmp_opt_typ)
          ICMP_OPT_MTU : begin
            if (ctr_icmp_opt == icmp_opt_len)
              load = load_icmp_opt_mtu;
            else  
            load = load_none;
          end
          ICMP_OPT_PREFIX : begin
            if      (ctr_icmp_opt == ICMP_OPT_PREFIX_BYTES-IP_BYTES-3) 
              load = load_icmp_opt_pfx_inf;
            else if (ctr_icmp_opt == icmp_opt_len)               
              load = load_icmp_opt_pfx_val;
            else
              load = load_none;
          end
          ICMP_OPT_SOURCE : begin
            if      (ctr_icmp_opt == icmp_opt_len)
              load = load_icmp_opt_lnk_src;
            else                                                       
              load = load_none;
          end
          ICMP_OPT_TARGET : begin
            if      (ctr_icmp_opt == icmp_opt_len)           
              load = load_icmp_opt_lnk_tar;
            else
              load = load_none;
          end
          ICMP_OPT_RDNSS : begin
            if      (ctr_icmp_opt == ICMP_OPT_RNDSS_INFO_LEN-3) // time to load RDNSS information field
              load = load_icmp_opt_rdnss_inf;
            else if (ctr_rdnss == 0) // time to load RDNSS IP address
              load = load_icmp_opt_rdnss_ip;
            else
              load = load_none;
          end
          default : load = load_none;
        endcase
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      tcp_opt_s : begin
        case (tcp_opt_typ)
          TCP_OPT_END ,
          TCP_OPT_NOP       : load =                                                                     load_none;
          TCP_OPT_MSS       : load = (ctr_tcp_opt == tcp_opt_len) ? load_tcp_opt_mss                   : load_none;
          TCP_OPT_SCL       : load = (ctr_tcp_opt == tcp_opt_len) ? load_tcp_opt_scl                   : load_none;
          TCP_OPT_SACK_PERM : load = (ctr_tcp_opt == tcp_opt_len) ? load_tcp_opt_sack_perm             : load_none;
          TCP_OPT_SACK      : load = (ctr_tcp_opt == TCP_OPT_SACK_LEN) ? load_tcp_opt_sack             : 
                                     (ctr_tcp_opt == 1*TCP_OPT_SACK_BLOCK_LEN ||
                                      ctr_tcp_opt == 2*TCP_OPT_SACK_BLOCK_LEN ||
                                      ctr_tcp_opt == 3*TCP_OPT_SACK_BLOCK_LEN ||
                                      ctr_tcp_opt == 4*TCP_OPT_SACK_BLOCK_LEN) ? load_tcp_opt_sack_blk : load_none;
          TCP_OPT_TIM       : load = (ctr_tcp_opt == tcp_opt_len)              ? load_tcp_opt_tim      : load_none;
          default           : load =                                                                     load_none;
        endcase
        cks_val  = 1;
   		  shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      icmp_pld_s : begin
        if      (ctr_ip == meta_ip.lng)
          load = load_icmp_echo;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      tcp_hdr_s : begin
        if      (ctr_tcp == TCP_HEADER_LEN)
          load = load_tcp_hdr;
        else if (ctr_tcp == TCP_OFS_FIELD_POS)
          load = load_tcp_ofs;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      udp_hdr_s : begin
        if      (ctr_hdr_udp == UDP_HEADER_LEN-1)
          load = load_udp_hdr;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      dns_hdr_s : begin
        if      (ctr_dns_hdr == DNS_HEADER_LEN-1)
          load = load_dns_hdr;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      dns_qry_str_s : begin
        if (phy_dat == "")
          load = load_dns_qry_str;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end 
      dns_qry_inf_s : begin
        if (ctr_dns_qry_inf == DNS_QUERY_INFO_LEN-1)
          load = load_dns_qry_inf;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end
      dns_ans_adr_s : begin
        if (ctr_dns_ans_adr == IP_BYTES-1)
          load = load_dns_ans_adr;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end 
      dns_ans_inf_s : begin
        if (ctr_dns_ans_inf == DNS_ANSWER_INFO_LEN-1)
          load = load_dns_ans_inf;
        else
          load = load_none;
        cks_val  = 1;
        shift    = 1;
        crc_val  = 1;
        ip_pld   = 1;
      end 
      tcp_pld_s : begin
        load = load_none;
        cks_val  = 1;
        shift    = 0;
        crc_val  = 1;
        ip_pld   = 1;
      end
      default   : begin
        load     = load_none;
        cks_val  = 0;
        shift    = 0;
        crc_val  = 1;
        ip_pld   = 0;
      end
    endcase
  end

  // verify packet length by counting reveived bytes and compating with reported packet length
  always_ff @ (posedge clk) begin
    if (fsm_rst) begin
      ctr_ip <= 1;
      ip_pld_done <= 0;
    end
    else if (ip_pld) begin
      ctr_ip <= ctr_ip + 1;
      if (ctr_ip == meta_ip.lng) ip_pld_done <= 1; // indicate IP payload is done when packet reachec it's reported length
    end
  end

  always_ff @ (posedge clk) begin
    phy_dat_reg  <= phy_dat; // Register incoming data (delay by 1 tick)
    tcp_pld_val_reg <= tcp_pld_val; // Register TCP payload data valid (delay by 1 tick)
    icmp_pld_val <= !ip_pld_done && state == icmp_pld_s && mac_hit && icmp_hit && val ; // optional ICMP payload (for Echo)
    tcp_pld_val  <= !ip_pld_done && state == tcp_pld_s  && phy_val                    ; // optional TCP payload data valid signal is 'cut' from incoming packet
  end

  assign tcp_pld_sof = !tcp_pld_val_reg && tcp_pld_val; // TCP first byte strobe (1-tick)

  assign icmp_pld_dat = phy_dat_reg; // Payload data is transparently passed to output
  assign tcp_pld_dat = phy_dat_reg;

  assign ctr_rdnss = ctr_icmp_opt - ICMP_OPT_RNDSS_INFO_LEN + 3; // current RNDSS byte

  // delay for FCS check
  qnigma_delay #(
    .W ($bits(dat) + 1),
    .D (5)
  ) delay_phy_inst (
    .clk  (clk),
    .in   ({phy_dat, phy_val}),
    .out  ({dat    , val    })
  );

  // FCS check module
  qnigma_crc32 crc32_inst (
    .clk (clk    ),
    .rst (crc_ok ),
    .dat (phy_dat),
    .val (crc_val),
    .ok  (crc_ok ),
    .crc (       )
  );

  // IP checksum calculator
  qnigma_cks cks_inst (
    .clk (clk                    ),
    .rst (fsm_rst                ),
    .dat (phy_dat                ),
    .ini (0                      ),
    .nxt (ctr_hdr_ip == 7        ), // previous field was IP next header
    .val (cks_val && !ip_pld_done), // calculate over relevant fields
    .zer (cks_ok),                  // calculated cks is zero (cks field inc.) means cks is ok
    .cks ()
  );

endmodule : qnigma_rx
