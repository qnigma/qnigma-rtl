package qnigma_pkg;

  function automatic [3:0] ascii2hex ();
    input bit [7:0] in;
    case (in)
      "0"      : ascii2hex = 4'h0;
      "1"      : ascii2hex = 4'h1;
      "2"      : ascii2hex = 4'h2;
      "3"      : ascii2hex = 4'h3;
      "4"      : ascii2hex = 4'h4;
      "5"      : ascii2hex = 4'h5;
      "6"      : ascii2hex = 4'h6;
      "7"      : ascii2hex = 4'h7;
      "8"      : ascii2hex = 4'h8;
      "9"      : ascii2hex = 4'h9;
      "a", "A" : ascii2hex = 4'ha;
      "b", "B" : ascii2hex = 4'hb;
      "c", "C" : ascii2hex = 4'hc;
      "d", "D" : ascii2hex = 4'hd;
      "e", "E" : ascii2hex = 4'he;
      "f", "F" : ascii2hex = 4'hf;
      default  : ascii2hex = 4'h0;
    endcase
  endfunction

  function automatic [7:0] hex2ascii ();
    input bit [3:0] in;
    case (in)
      4'h0 : hex2ascii = "0";
      4'h1 : hex2ascii = "1";
      4'h2 : hex2ascii = "2";
      4'h3 : hex2ascii = "3";
      4'h4 : hex2ascii = "4";
      4'h5 : hex2ascii = "5";
      4'h6 : hex2ascii = "6";
      4'h7 : hex2ascii = "7";
      4'h8 : hex2ascii = "8";
      4'h9 : hex2ascii = "9";
      4'ha : hex2ascii = "a";
      4'hb : hex2ascii = "b";
      4'hc : hex2ascii = "c";
      4'hd : hex2ascii = "d";
      4'he : hex2ascii = "e";
      4'hf : hex2ascii = "f";
    endcase
  endfunction
  
  `include "src/network/refclk.sv"

  //////////////////////////
  // Synthsis localparams //
  //////////////////////////
  localparam int    MTU_DEFAULT               = 1500;
  localparam int    IFG                       = 5;  
  localparam int    HOST_LEN                  = 32;
  // TCP
  localparam int    TCP_RETRANSMIT_TICKS      = REFCLK_HZ/1250; // 10ms
  localparam int    TCP_RETRANSMIT_TRIES      = 5;
  localparam int    TCP_SACK_RETRANSMIT_TICKS = REFCLK_HZ/125;
  localparam int    TCP_FAST_RETRANSMIT_TICKS = REFCLK_HZ/125;
  localparam int    TCP_RX_RAM_DEPTH          = 14;
  localparam int    TCP_DEFAULT_WINDOW_SIZE   = 1000;
  // 
  localparam int    TCP_TX_RAM_DEPTH          = 14;
  localparam int    TCP_PACKET_DEPTH          = 6;
  localparam int    TCP_WAIT_TICKS            = 125;   // 1us
  localparam int    TCP_CONNECTION_TIMEOUT_MS = 5000;  // 5s
  localparam int    TCP_DUP_ACKS              = 5;
  localparam int    TCP_FORCE_ACK_PACKETS     = 5;
  localparam int    TCP_KEEPALIVE_PERIOD_S    = 3; // 5s
  localparam int    TCP_KEEPALIVE_TRIES       = 3;
  localparam bit    TCP_ENABLE_KEEPALIVE      = 1;
  // 
  localparam int    TCP_ACK_TIMEOUT_MS        = 100;
  localparam int    TCP_TX_PACKET_DEPTH       = 5;
  // 
  localparam int    DNS_TIMEOUT_MS            = 2000;
  localparam int    DNS_TRIES                 = 5;
  localparam int    DNS_QUERY_INFO_LEN        = 4;
  localparam int    DNS_ANSWER_INFO_LEN       = 12;
  localparam [15:0] DNS_DEFAULT_LOCAL_PORT    = 12345;
  localparam [15:0] DNS_QUERY_PORT            = 53;
  // 
  localparam int    MAC_RX_CDC_FIFO_DEPTH     = 4; 
  localparam int    MAC_RX_CDC_DELAY          = 3;
  localparam int    TCP_SACK_BLOCKS           = 4;
  // 
  localparam int    DAD_TRIES                 = 4;
  localparam int    MLD_TRIES                 = 3;
  localparam int    NDP_TRIES                 = 3;
  localparam int    RTR_TRIES                 = 3;
  localparam int    DAD_TIMEOUT_MS            = 250;
  localparam int    NDP_TIMEOUT_MS            = 250;
  localparam int    RTR_TIMEOUT_MS            = 250;
  localparam int    MLD_RETRANSMIT_MS         = 1000;

  localparam int    ICMP_ECHO_FIFO_DEPTH      = 8;
  localparam [6:0]  PREFIX_LENGTH             = 64; // Fix IPv6 prefix to 64 bits

  typedef logic [5:0][7:0]  mac_t;
  typedef logic [15:0][7:0] ip_t;
  typedef logic [7:0][7:0]  iid_t;

  typedef logic [PREFIX_LENGTH-1:0]  pfx_t;

  ///////////////
  // Constants // 
  ///////////////

  // Various lengths
  localparam int UDP_HEADER_LEN = 8;
  localparam int DNS_HEADER_LEN = 12;
  localparam int IP_HEADER_LEN  = 40;
  localparam int ETH_HEADER_LEN = 14;
  localparam int CRC_LEN        = 4;
  
  localparam int   TCP_HEADER_LEN = 20;
  localparam int   TCP_OPTIONS_LEN = 40;
  // MTU contains MSS length + following fields:
  localparam [15:0] MTU_MSS_DIFFERENCE  = IP_HEADER_LEN + TCP_HEADER_LEN + TCP_OPTIONS_LEN;
  // IPv6

  localparam [7:0][7:0] PREAMBLE        = {{7{8'h55}}, 8'hd5};
  localparam [7:0] IP_DEFAULT_HOPS      = '1;
  localparam [7:0] IP_DEFAULT_PRIORITY  = 0;
  localparam ip_t  IP_MULTICAST_ALL_RTR  = {16'hff02, 104'b0, 8'h02};
  localparam ip_t  IP_MULTICAST_ALL_DEV  = {16'hff02, 104'b0, 8'h01};
  localparam ip_t  IP_MULTICAST_MLD      = {16'hff02, 104'b0, 8'h16};

  localparam ip_t DNS_IP_ADDR_PRI = {
    8'h20,8'h01,
    8'h48,8'h60,
    8'h48,8'h60,
    8'h00,8'h00,
    8'h00,8'h00,
    8'h00,8'h00,
    8'h00,8'h00,
    8'h88,8'h88};


  localparam int    INTERFACE_ID_OFFSET = 8;
  localparam int    IP_BYTES            = $bits(ip_t)/$bits(byte);
  localparam int    PSEUDO_LEN          = 8;
  
  localparam [7:0]  IP_OPT_HOP_BY_HOP = 0;
  localparam int    IP_OPT_RTR_ALERT_BYTES = 8;

  localparam [7:0]  IP_OPT_PADN = 1;
  localparam [7:0]  IP_OPT_RTR_ALERT = 5;
  localparam [7:0]  IP_OPT_RTR_ALERT_LEN = 2;
  localparam [15:0] IP_OPT_RTR_ALERT_MLD = 0;


  // MAC first 3 octet constants
  localparam [2:0][7:0] MAC_SOLICITED_MULTICAST = {8'h33, 8'h33, 8'hff};
  localparam [2:0][7:0] MAC_ALL_NODES_MULTICAST = {8'h33, 8'h33, 8'h00};
  // MAC last 3 octet constants
  localparam [2:0][7:0] MAC_ALL_DEV             = {8'h00, 8'h00, 8'h01};
  localparam [2:0][7:0] MAC_ALL_RTR             = {8'h00, 8'h00, 8'h02};
  localparam [2:0][7:0] MLD_MULTICAST           = {8'h00, 8'h00, 8'h16};

  ////////////
  // ICMPv6 //
  ////////////
  localparam int ICMP_HEADER_TX_LEN  = 16;  
  localparam int ICMP_HEADER_RX_LEN  = 16; // Router sol
  localparam int ICMP_HEADER_LEN_MIN = 4; // type[1], code[1], checksum[2]
  localparam int DNS_NUM  = 3;  // type[1], code[1], checksum[2]
  localparam int MAX_DNS_SRV  = 3;  // type[1], code[1], checksum[2]
  
  // ICMP types
  localparam [7:0]
    DEST_UNREACH      = 1,
    PACKET_TOO_BIG    = 2,
    TIME_EXCEEDED     = 3,
    PARAM_PROBLEM     = 4,
    ICMP_ECHO_REQUEST = 128,
    ECHO_REPLY        = 129,
    ICMP_MLDV2        = 143,
    MCAST_REPORT      = 131,
    MCAST_DONE        = 132,
    ICMP_RS           = 133,
    ICMP_RA           = 134,
    ICMP_NS           = 135,
    ICMP_NA           = 136,
    REDIRCET          = 137,
    ROUTER_RENUM      = 138,
    NODE_QUERY        = 139,
    NODE_RESPONSE     = 140;
  
  localparam [7 :0] ICMP_MLDV2_INCLUDE = 3;
  localparam [7 :0] ICMP_MLDV2_AUX_LEN = 0;
  localparam [15:0] ICMP_MLDV2_SOURCES = 0;

  // ICMP basic length by packet type
  localparam [7:0]
    ICMP_ECHO_LEN           = 8,
    ICMP_RA_LEN             = 16,
    ICMP_RS_LEN             = 8,
    ICMP_NS_LEN             = 8,
    ICMP_NA_LEN             = 8,
    ICMP_MLDV2_LEN          = 20,
    ICMP_OPT_RNDSS_INFO_LEN = 8;
  
  // ICMP options encoding
  localparam [7:0]
    ICMP_OPT_SOURCE = 1,
    ICMP_OPT_TARGET = 2,
    ICMP_OPT_PREFIX = 3,
    ICMP_OPT_REDIR  = 4,
    ICMP_OPT_MTU    = 5,
    ICMP_OPT_RDNSS  = 25,
    ICMP_OPT_DNSSL  = 31;
  
  // Prefix information bytes
  localparam int ICMP_OPT_PREFIX_BYTES = 32;

  // ICMP options lengths (in bytes)
  localparam [7:0]
    ICMP_OPT_SOURCE_LEN     = 8,         
    ICMP_OPT_TARGET_LEN     = 8,         
    ICMP_OPT_MTU_LEN        = 8,
    ICMP_OPT_PREFIX_LEN     = 4,
    ICMP_OPT_RDNSS_INFO_LEN = 8,
    PFX_LEN                 = 8;

  // Ethertype definition
  localparam [15:0] IPV6 = 16'h86DD;

  //// IP 2nd octet ls nibble values
  //localparam [3:0]
  //  NODE_LOCAL = 1,
  //  LINK_LOCAL = 2,
  //  SITE_LOCAL = 5,
  //  ORG_LOCAL  = 8,
  //  GLOBAL     = 14;

  // Extension headers
  //localparam [7:0] 
  //  IP_EXT_HOP      = 0, // 	Options that need to be examined by all devices on the path
  //  IP_EXT_ROUTING  = 43, // 	Methods to specify the route for a datagram (used with Mobile IPv6)
  //  IP_EXT_FRAG     = 44, // 	Contains localparams for fragmentation of datagrams
  //  IP_EXT_AH       = 51, // 	Contains information used to verify the authenticity of most parts of the packet
  //  IP_EXT_ESP      = 50, // 	Carries encrypted data for secure communication
  //  IP_EXT_DEST     = 60, // 	Options that need to be examined only by the destination of the packet
  //  IP_EXT_MOBILITY = 135, // localparams used with Mobile IPv6
  //  IP_EXT_HOST_ID  = 139; // Used for Host Identity Protocol version 2 (HIPv2)[10]

  // IPv6 procols (next field)
  localparam [7:0] 
   // HOP_BY_HOP    = 8'd0,
   // DST_OPT       = 8'd60,
   // ROUTING       = 8'd43,
   // FRAGMENT      = 8'd44,
   // AUTH          = 8'd51,
   // SEC           = 8'd50,
   // MOBILITY      = 8'd135,
   // NO_NXT_HEADER = 8'd59,
    ICMPV6          = 8'd58,
    UDP             = 8'd17,
    TCP             = 8'd6;

  // Option field 
  // Common for ICMP and TCP options
  typedef enum logic [2:0] {
    opt_pri_typ,
    opt_fld_len,
    opt_fld_dat
  } opt_pri_t;

  /////////
  // MAC //
  /////////

  typedef enum logic [6:0] {
  /*0*/  ref_ip_rst,
  /*1*/  ref_ip_loc,
  /*2*/  ref_ip_glb,
  /*3*/  ref_ip_sol,
  /*4*/  ref_ip_mcs,
  /*5*/  ref_ip_uns,
  /*6*/  ref_ip_non
  } ip_ref_t;

  //////////
  // Meta // 
  //////////
  // There structs are 8-bit aligned
  // For easy access via verilator

  typedef struct packed {
    logic [7:0]  lng;
    logic [7:0]  flags; 
    logic [31:0] pfx_life;
    logic [31:0] pref_life;
    logic [31:0] reserved;
    pfx_t        pfx;
  } pfx_inf_t; // bytes = 30
  
  typedef struct packed {
    logic [15:0] lifetime;
    logic [15:0] reserved;
    ip_t         dns_addr;
  } rdnss_t;

  typedef struct packed {
    logic       man;
    logic       ovr;
    logic       agt;
    logic [1:0] prf;
    logic       prx;
    logic [1:0] res;
  } rtr_adv_flags_t; // bytes = 1

  // NDP flags
  typedef struct packed {
    logic        rtr;
    logic        sol;
    logic        ovr;
    logic [28:0] res;
  } nbr_flags_t; // bytes = 4
  
  // F
  typedef struct packed {
    nbr_flags_t flags;
  } icmp_nbr_adv_t; // bytes = 4
  
  // Router Advertisement
  typedef struct packed {
    logic [7:0]     cur_hop_lim ;
    rtr_adv_flags_t flags       ;
    logic [15:0]    lifetime    ;
    logic [31:0]    reach_time  ;  
    logic [31:0]    retrans_time;
  } icmp_rtr_adv_t; // bytes = 12

  typedef enum logic [7:0] {
    MODE_IS_INCLUDE        = 8'h1,
    MODE_IS_EXCLUDE        = 8'h2,
    CHANGE_TO_INCLUDE_MODE = 8'h3,
    CHANGE_TO_EXCLUDE_MODE = 8'h4,
    ALLOW_NEW_SOURCES      = 8'h5,
    BLOCK_OLD_SOURCES      = 8'h6
  } mld_rec_typ_t;

  // Multicast adderess is passed to target adderss in ICMP field 
  typedef struct packed {
    mld_rec_typ_t rec_typ;
    logic [ 7:0]  aux_dat_len;
    logic [15:0]  num_src;
  } icmp_mld_t;

  typedef struct packed {
    logic [15:0] id;
    logic [15:0] seq;
    logic [15:0] lng;
  } icmp_echo_t; // bytes = 4

  typedef struct packed {
    // Mandatory fields
    logic [3 :0] ver;                  
    logic [7 :0] pri;                  
    logic [19:0] flo;                  
    logic [15:0] lng;                  
    logic [7: 0] nxt;                  
    logic [7: 0] hop;                                   
  } hdr_ip_t;

 typedef struct packed {
   mac_t        dst, src;
   logic [15:0] etyp;
 } hdr_eth_t;

  localparam int 
    TCP_DEFAULT_OFFSET      = 5,
    TCP_OPT_LEN             = 40,
    TCP_MAX_LEN             = TCP_HEADER_LEN + TCP_OPT_LEN,
    TCP_OFS_FIELD_POS       = 13,
    TCP_MAX_OPT_LEN         = 34,
    HEADER_OPTIONS_POS      = 12,
    MAX_TCP_OFFSET          = 15,
    TCP_MAX_WND_SCALE       = 14;

  localparam [7:0]
    TCP_OPT_END       = 0,
    TCP_OPT_NOP       = 1,
    TCP_OPT_MSS       = 2,
    TCP_OPT_SCL       = 3,
    TCP_OPT_SACK_PERM = 4,
    TCP_OPT_SACK      = 5,
    TCP_OPT_TIM       = 8;

  localparam [7:0]
    TCP_OPT_MSS_LEN        = 4,
    TCP_OPT_SCL_LEN        = 3,
    TCP_OPT_SACK_PERM_LEN  = 2,
    TCP_OPT_SACK_LEN       = 2,
    TCP_OPT_SACK_BLOCK_LEN = 8,
    TCP_OPT_TIM_LEN        = 10;

  // flags vector as in TCP header
  typedef struct packed {
    logic ns;
    logic cwr;
    logic ece;
    logic urg;
    logic ack;
    logic psh;
    logic rst;
    logic syn;
    logic fin;
  } tcp_flags_t;

  localparam tcp_flags_t 
    TCP_FLAG_NS  = 9'b100000000,
    TCP_FLAG_CWR = 9'b010000000,
    TCP_FLAG_ECE = 9'b001000000,
    TCP_FLAG_URG = 9'b000100000,
    TCP_FLAG_ACK = 9'b000010000,
    TCP_FLAG_PSH = 9'b000001000,
    TCP_FLAG_RST = 9'b000000100,
    TCP_FLAG_SYN = 9'b000000010,
    TCP_FLAG_FIN = 9'b000000001;

  localparam OPT_LEN = 8;

  typedef logic [3:0] tcp_scl_t;    // raw window scale type
  typedef logic [15+TCP_MAX_WND_SCALE:0] tcp_wnd_scl_t; // scaled window type

  typedef enum logic [2:0] {
  /*0*/ icmp,
  /*1*/ tcp,
  /*2*/ dns
  } proto_t;

  // structure to keep info about each packet in tx buff
  typedef struct packed {
    logic        exists;   // packet exists. present flag. "0" means all data below is garbage and may be overwritten
    logic [31:0] cks;      // 32-bit checksum for packet's paload with carry
    logic [31:0] start;    // first sequence number of the packet
    logic [31:0] stop;     // last sequence number of the packet
    logic [15:0] lng;      // start + lng equals stop
    logic [31:0] norm_rto; // A long timer to retransmit unacked packet. Last resort or compatibility with non-SACK TCPs
    logic [31:0] sack_rto; // A fast timer to retransmit an unSACKed packet after it has been sent due to SACK
    logic [$clog2(TCP_RETRANSMIT_TRIES):0] 
                 tries;    // Times server has tried to retransmit the packet
  } tcp_pkt_t;

  typedef struct packed {
    logic [15:0] src;
    logic [15:0] dst;
    logic [31:0] seq;
    logic [31:0] ack;
    logic [3:0]  ofs;
    logic [2:0]  res;
    tcp_flags_t  flg;
    logic [15:0] wnd;
    logic [15:0] cks;
    logic [15:0] ptr;
  } hdr_tcp_t;

  // one sack blk borders
  typedef struct packed  {
    logic [31:0] left;
    logic [31:0] right;
  } tcp_sack_blk_t;
  
  // compele sack info
  typedef struct packed {
    tcp_sack_blk_t [3:0] blk;
    logic          [3:0] val; // blocks valid
  } tcp_opt_sack_t;

  typedef struct packed {
    logic [31:0] rec;
    logic [31:0] snd;
  } tcp_opt_tim_t;
 
  typedef struct packed {
    bit mss_pres;
    bit wnd_pres;
    bit sack_pres;
    bit sack_perm_pres;
    bit tim_pres;
  } tcp_opt_pres_t;
 
  // all info on options
  typedef struct packed {
    logic [15:0]   mss;
    logic [7:0]    tcp_opt_scl;
    tcp_opt_sack_t tcp_opt_sack;
    logic          tcp_opt_sack_perm;
    tcp_opt_tim_t  tcp_opt_tim;
    tcp_opt_pres_t tcp_opt_pres; // tcp options present flags
  } tcp_opt_t;

  typedef struct packed {
    logic [31:0] start;
    logic [31:0] stop;
    logic [15:0] lng;
    logic [31:0] cks;
  } tcp_pld_info_t;

  // TCP status
  typedef enum logic [4:0] {
    tcp_closed,
    tcp_listening,
    tcp_wait_dns,
    tcp_connecting,
    tcp_connected,
    tcp_disconnecting
  } tcp_stat_t;

  // transmission control block struct. store info on current connection
  typedef struct packed {
    logic [15:0]   mss     ;    // current MSS
    logic [15:0]   loc_port;    // local port
    logic [15:0]   rem_port;    // remote port
    ip_ref_t       loc_ref;     // local ip selection
    ip_t           rem_ip;      // remote host IP
    mac_t          mac;         // remote host MAC
    logic [31:0]   loc_seq;     // current local  sequence number
    logic [31:0]   loc_ack;     // current local  acknowledgement number
    logic [31:0]   rem_seq;     // last known remote sequence number
    logic [31:0]   rem_ack;     // last known remote acknowledgement number
    tcp_opt_sack_t rem_sack;    // last known remote SACK blocks
    tcp_opt_sack_t loc_sack;    // current local SACK
    tcp_wnd_scl_t  rem_wnd;     // last known remote scaled remote window
    tcp_stat_t     status;      // TCP status
  } tcb_t;

  // TCP packet metadata
  typedef struct packed {
    logic [15:0]   src;
    logic [15:0]   dst;
    logic [31:0]   seq;
    logic [31:0]   ack;
    tcp_flags_t    flg;
    logic [15:0]   wnd;
    logic [15:0]   cks;
    logic [15:0]   ptr;
    logic [ 3:0]   ofs;
    logic [15:0]   pld_len;
    logic [31:0]   pld_cks;
  
    logic [15:0]   opt_mss;
    logic [7:0]    opt_scale;
    tcp_opt_sack_t opt_sack;
    logic          opt_sack_perm;
    tcp_opt_tim_t  opt_tim;
    tcp_pld_info_t pld;
  } meta_tcp_t;

  // TCP option metadata present
  typedef struct packed {
    logic opt_mss;
    logic opt_scale;
    logic opt_sack;
    logic opt_sack_perm;
    logic opt_tim;
  } meta_tcp_pres_t;

  // MAC reference type
  // Encode local possible MAC addresses
  typedef enum logic [4:0] {
  /*0*/ ref_mac_rst,
  /*1*/ ref_mac_dev,
  /*2*/ ref_mac_glb,
  /*3*/ ref_mac_sol,
  /*4*/ ref_mac_non
  } mac_ref_t;

  //
  typedef struct packed {
    mac_t        rem;     // Pass remote MAC 'by value'
    mac_ref_t    loc_ref; // Pass local MAC 'by reference'
    /*logic [15:0] lng; Not used*/
    logic [15:0] etyp; // Ethertype. Should be always IPv6
  } meta_mac_t;

  typedef struct packed {
    logic [15:0] lng;
    logic [7:0]  pro;
    logic [19:0] flo;
    logic [7:0]  pri;
    logic [7:0]  hop;
    ip_t         rem;
    ip_ref_t     loc_ref;
    logic        rtr_alert;
  } meta_ip_t;

  typedef struct packed {
    logic [7:0]    typ;          // ICMP type
    logic [7:0]    cod;          // ICMP code
    // Protocol-spcecific fields
    icmp_mld_t     mld;          // MDL related fields
    icmp_nbr_adv_t nbr;          // NDP related fields
    icmp_echo_t    echo;         // Echo related fields
    icmp_rtr_adv_t rtr;          // Router Advertisement related fields
    // Addresses
    ip_t           tar;          // Target IP in supported ICMP packets 
    ip_ref_t       tar_ref;      // Target reference 
    mac_t          opt_lnk_src;  // Source Link-Layer address in supported packets
    mac_t          opt_lnk_tar;  // Target Link-Layer address in supported packets
    pfx_inf_t      opt_pfx_inf;  // Prefix information for Router Advertesements
    rdnss_t        opt_rdnss;    // RDNSS for Router Advertesements
    logic [31:0]   opt_mtu;      // MTU ICMP option
    logic [31:0]   pld_cks;      // Payload checksum
  } meta_icmp_t;

  typedef struct packed {
    logic tar;                   // Target IP field present
    logic opt_lnk_src;           // Source Link-Layer address option present
    logic opt_lnk_tar;           // Target Link-Layer address option present
    logic opt_pfx_inf;           // Prefix information option present
    logic opt_mtu;               // MTU option present
    logic opt_rdnss;             // RDNSS option present
    logic dns_addr;              // RDNSS addr present
  } meta_icmp_pres_t;
  
  typedef struct packed {
    logic [15:0]   src;          // Source UDP port (the one that's sending data)
    logic [15:0]   dst;          // Source UDP port (the one that's receiving data)
    logic [15:0]   lng;          // Datagram (payload) length
    logic [15:0]   cks;          // UDP checksum
  } meta_udp_t;
    
  typedef struct packed {
    logic [HOST_LEN-1:0][7:0]    str; // Prepared hostname string. Dots replaced 
    logic [$clog2(HOST_LEN)-1:0] lng; // Length of the string
  } hostname_t;
  
  typedef struct packed {
    logic [15:0]   src;
    logic [15:0]   dst;
    logic [15:0]   lng;
    logic [15:0]   cks;
  } hdr_udp_t;
  
  typedef struct packed {
    logic [15:0] typ;
    logic [15:0] cls;
    logic [31:0] ttl;
    logic [15:0] lng;
  } dns_inf_t;

  typedef struct packed {
    logic [15:0] tid;
    logic [15:0] flg;
    logic [15:0] num;
    logic [15:0] ans;
    logic [15:0] aut;
    logic [15:0] add;
    dns_inf_t    inf;
    hostname_t   hst;
    ip_t         addr;
  } meta_dns_t;

  typedef struct packed {
    logic [15:0] tid;
    logic [15:0] flg;
    logic [15:0] num;
    logic [15:0] ans;
    logic [15:0] aut;
    logic [15:0] add;
  } hdr_dns_t;
  
 // function hostname_t conv_hn;
 //   input [HOST_LEN-1:0][7:0] raw;
//
 //   bit [7:0] zeros = 0;
 //   bit [7:0] ctr = 0;
 //   hostname_t hn;
 //   
 //   for (int i = HOST_LEN-1; i > 0; i--) begin
 //     if (raw[i] == "") zeros = zeros + 1;
 //     hn.str = "";
 //   end
 //   $display(zeros);
 //   hn.lng = HOST_LEN - zeros + 1;
 //   for (int i = 0; i < HOST_LEN - zeros; i++) begin
 //     if (i == HOST_LEN - zeros - 1) hn.str[HOST_LEN-1] = ctr + 1;
 //     if (raw[i] == ".") begin
 //       hn.str[i + zeros - 1] = ctr;
 //       ctr = 0;
 //     end
 //     else begin
 //       hn.str[i + zeros - 1] = raw[i];
 //       ctr = ctr + 1;
 //     end
 //     if (i == HOST_LEN - zeros) return hn;
 //   end
 //   return hn;
 // endfunction

endpackage : qnigma_pkg