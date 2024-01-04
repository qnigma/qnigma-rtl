#ifndef pkt_c_H
#define pkt_c_H

#include "pcap.h"

class pkt_c
{

public:
  struct mac_t
  {
    bool operator==(const mac_t &other) const
    {
      // for (const int& i : other)
      for (size_t idx = 0; idx < sizeof(mac_t); idx++)
        if (this->m[idx] != other.m[idx])
          return false;
      return true;
    };
    bool operator!=(const mac_t &other) const
    {
      return !operator==(other);
    };
    uint8_t m[6];
  };

  struct ip_t
  {
    bool operator==(const ip_t &other) const
    {
      // for (const int& i : other)
      for (size_t idx = 0; idx < sizeof(ip_t); idx++)
        if (this->i[idx] != other.i[idx])
          return false;
      return true;
    };
    bool operator!=(const ip_t &other) const
    {
      return !operator==(other);
    };
    uint8_t i[16];
  };
  ///////////////
  // Constants //
  ///////////////

  static constexpr uint32_t CRC_POLY = 0xEDB88320;
  static constexpr uint32_t CRC_MAGIC_NUMBER = 0xDEBB20E3;
  // Ethertypes
  static constexpr uint16_t IPV6 = 0x86dd;
  static constexpr uint16_t ARP = 0x0806;
  // IP protocols
  static constexpr uint8_t ICMP = 58;
  static constexpr uint8_t UDP = 17;
  static constexpr uint8_t TCP = 6;
  // Lengths & offsets
  static constexpr int IP_BYTES = 16;
  static constexpr int MAC_BYTES = 6;
  static constexpr size_t IP_HDR_LEN = 40;
  static constexpr size_t TCP_HDR_LEN = 20;
  static constexpr unsigned FCS_BYTES = 4;
  static constexpr unsigned PREAMBLE_BYTES = 8;
  static constexpr unsigned MAC_OFFSET = 22;
  // ICMP options
  static constexpr uint8_t ICMP_OPTION_RECURSIVE_DNS_SERVERS = 25;
  static constexpr uint8_t ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS = 1;
  static constexpr uint8_t ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS = 2;
  static constexpr uint8_t ICMP_OPTION_PREFIX_INFORMATION = 3;
  static constexpr uint8_t ICMP_OPTION_REDIRECT = 4;
  static constexpr uint8_t ICMP_OPTION_MTU = 5;
  // ICMP option lengths
  static constexpr uint8_t ICMP_OPTION_RECURSIVE_DNS_SERVERS_LENGTH = 7;
  static constexpr uint8_t ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH = 1;
  static constexpr uint8_t ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS_LENGTH = 1;
  static constexpr uint8_t ICMP_OPTION_PREFIX_INFORMATION_LENGTH = 4;
  static constexpr uint8_t ICMP_OPTION_MTU_LENGTH = 1;
  static constexpr uint8_t ICMP_ECHO_DATA_LENGTH = 0;
  static constexpr uint8_t RA_MANAGED_FLAG = 0x80;
  static constexpr uint8_t RA_OTHER_FLAG = 0x40;
  static constexpr uint8_t RA_HOME_FLAG = 0x20;
  static constexpr uint8_t RA_PREF_HIGH_FLAG = 0x04;
  static constexpr uint8_t RA_PREF_MEDIUM_FLAG = 0x00;
  static constexpr uint8_t RA_PREF_LOW_FLAG = 0x14;
  static constexpr uint8_t RA_PREF_BAD_FLAG = 0x10;
  static constexpr uint8_t RA_PROXY_FLAG = 0x02;

  // RDNSS option
  static constexpr uint8_t ICMP_OPTION_DNS = 25;
  static constexpr uint8_t ICMP_OPTION_DNS_LENGTH = 13;
  static constexpr uint8_t IP_OPTION_HOP_BY_HOP = 0;

  static constexpr ip_t IP_MULTICAST_ALL_DEVICES = {
      0xff, 0x02, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x01};

  static constexpr ip_t IP_MULTICAST_ALL_ROUTERS = {
      0xff, 0x02, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x02};

  static constexpr ip_t IP_MULTICAST_MLD = {
      0xff, 0x02, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x16};

  static constexpr ip_t IP_UNSPECIFIED = {
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00};
  // Solicited-node multicast address based on the link-layer address

  static constexpr mac_t MAC_MULTICAST_ALL_DEVICES = {
      0x33, 0x33, 0x00, 0x00, 0x00, 0x01};

  static constexpr mac_t MAC_MULTICAST_ALL_ROUTERS = {
      0x33, 0x33, 0x00, 0x00, 0x00, 0x02};

  static constexpr mac_t MAC_MULTICAST_MLD = {
      0x33, 0x33, 0x00, 0x00, 0x00, 0x16};

  static constexpr uint16_t DNS_PORT = 53;
  static constexpr uint16_t DNS_HEADER_LEN = 12;
  static constexpr uint16_t DNS_QUERY_INFO_LEN = 4;
  static constexpr uint16_t DNS_TYPE_AAAA = 28;
  static constexpr uint16_t DNS_CLASS_IN = 1;
  static constexpr uint16_t DNS_RESP_DEFAULT_TTL = 300;
  static constexpr uint8_t DNS_POINTER = 0xc0;
  static constexpr uint8_t DNS_POINTER_VALUE = 12;

  // ICMP message types
  static constexpr uint8_t ICMP_TYPE_ECHO_REQUEST = 128;
  static constexpr uint8_t ICMP_TYPE_ECHO_REPLY = 129;
  static constexpr uint8_t ICMP_TYPE_ROUTER_SOLICITATION = 133;
  static constexpr uint8_t ICMP_TYPE_ROUTER_ADVERTISEMENT = 134;
  static constexpr uint8_t ICMP_TYPE_NEIGHBOR_SOLICITATION = 135;
  static constexpr uint8_t ICMP_TYPE_NEIGHBOR_ADVERTISEMENT = 136;
  static constexpr uint8_t ICMP_TYPE_MULTICAST_LISTENER_REPORT_V2 = 143;

  // ICMP message type header lengths
  static constexpr uint8_t ICMP_ECHO_HLEN = 8;
  static constexpr uint8_t ICMP_RS_HLEN = 8;
  static constexpr uint8_t ICMP_RA_HLEN = 16;
  static constexpr uint8_t ICMP_NEIGHBOR_HLEN = 24;
  static constexpr uint8_t ICMP_MLD_HLEN = 36;

  static constexpr uint8_t UDP_HLEN = 8;

  static constexpr uint8_t TCP_OPT_END = 0;
  static constexpr uint8_t TCP_OPT_NOP = 1;
  static constexpr uint8_t TCP_OPT_MSS = 2;
  static constexpr uint8_t TCP_OPT_SCL = 3;
  static constexpr uint8_t TCP_OPT_SACK_PERM = 4;
  static constexpr uint8_t TCP_OPT_SACK = 5;
  static constexpr uint8_t TCP_OPT_TIM = 8;

  static constexpr uint8_t TCP_OPT_MSS_LEN = 4;
  static constexpr uint8_t TCP_OPT_SCL_LEN = 3;
  static constexpr uint8_t TCP_OPT_SACK_PERM_LEN = 2;
  static constexpr uint8_t TCP_OPT_TIM_LEN = 10;

  static constexpr uint8_t TCP_FLAG_FIN = 0x01;
  static constexpr uint8_t TCP_FLAG_SYN = 0x02;
  static constexpr uint8_t TCP_FLAG_RST = 0x04;
  static constexpr uint8_t TCP_FLAG_PSH = 0x08;
  static constexpr uint8_t TCP_FLAG_ACK = 0x10;
  static constexpr uint8_t TCP_FLAG_URG = 0x20;
  static constexpr uint8_t TCP_FLAG_ECE = 0x40;
  static constexpr uint8_t TCP_FLAG_CWR = 0x80;

  static constexpr unsigned IP_HEADER_LEN = 40;
  static constexpr unsigned TCP_HEADER_MAX_LEN = 60;

  enum tcp_field_t
  {
    typ,
    len,
    dat
  };

  struct meta_mac_t
  {
    uint16_t ethertype;
    mac_t src;
    mac_t dst;
  };

  struct meta_ip_t
  {
    uint8_t traffic_class;
    uint32_t flow_label;
    uint8_t proto;
    uint8_t hops;
    ip_t src;
    ip_t dst;
    uint16_t len;
  };

  struct meta_udp_t
  {
    uint16_t src;
    uint16_t dst;
    uint16_t len;
    uint16_t cks;
  };

  struct sack_blk_t
  {
    bool operator==(const sack_blk_t &other) const
    {
      // for (const int& i : other)
      if (this->left != other.left)
        return false;
      if (this->right != other.right)
        return false;
      if (this->pres != other.pres)
        return false;
      return true;
    };
    bool operator!=(const sack_blk_t &other) const
    {
      return !operator==(other);
    };
    uint32_t left;
    uint32_t right;
    bool pres;
  };

  struct tcp_opt_sack_t
  {
    sack_blk_t b[4];
  };

  struct tcp_opt_tim_t
  {
    uint32_t start;
    uint32_t stop;
  };

  struct tcp_opt_t
  {
    // MSS option
    uint16_t mss;
    bool mss_pres;
    // Windows Scale option
    uint8_t wnd;
    bool wnd_pres;
    // Sack Permitted option
    bool sack_perm;
    bool sack_perm_pres;
    // SACK option data
    tcp_opt_sack_t sack;
    // SACK option present
    bool sack_pres;
    // Timestamp option
    tcp_opt_tim_t tim;
    bool tim_pres;
  };

  struct meta_tcp_t
  {
    uint16_t src;
    uint16_t dst;
    uint32_t seq;
    uint32_t ack;
    uint16_t flg;
    uint16_t wnd;
    uint16_t cks;
    uint16_t ptr;
    tcp_opt_t opt;
  };

  struct meta_dns_t
  {
    /* header */
    uint16_t id;
    uint16_t questions;
    uint16_t flags;
    uint16_t ans_rrs;
    uint16_t aut_rrs;
    uint16_t add_rrs;
    /* query */
    bool query;
    std::string query_str;
    uint16_t query_type;
    uint16_t query_class;
    /* answer */
    bool answer;
    uint16_t answer_name;
    uint16_t answer_type;
    uint16_t answer_class;
    uint32_t answer_ttl;
    uint16_t answer_data_len;
    ip_t answer_addr;
  };

  struct icmp_opt_lnka_t
  {
    mac_t mac;
    bool pres;
  };

  struct icmp_opt_mtu_t
  {
    uint32_t mtu;
    bool pres;
  };

  struct icmp_opt_pfx_t
  {
    uint32_t vlife; // valid lifetime
    uint32_t plife; // preffered lifetime
    uint8_t len;
    uint8_t flags;
    ip_t ip;
    bool pres;
  };

  struct icmp_opt_rdnss_t
  {
    uint32_t life;
    vector<ip_t> dns_ip;
    bool pres;
  };

  struct icmp_opt_t
  {
    icmp_opt_lnka_t src_lnka, tar_lnka;
    icmp_opt_mtu_t mtu;
    icmp_opt_pfx_t pfx;
    icmp_opt_rdnss_t rdnss;
  };

  struct icmp_mld_t
  {
    uint16_t reserved;
    uint8_t rec_typ;
    uint16_t num_rec;
    uint8_t aux_dat_len;
    uint16_t num_src;
    ip_t mcast_addr;
  };

  struct meta_icmp_t
  {
    uint8_t type;
    uint8_t code;
    // RA only header fields
    uint8_t ra_cur_hop_lim;
    uint8_t ra_flags;
    uint16_t ra_router_lifetime;
    uint32_t ra_reach_time;
    uint32_t ra_retrans_time;
    uint32_t na_flags;
    // NA/NS only header fields
    ip_t tar_ip;
    bool tar_pres;
    // echo only header fields
    uint16_t echo_id;
    uint16_t echo_seq;
    uint16_t echo_len;
    // ICMP options
    icmp_opt_t opt;
    bool sol;     // Message is solicited
    bool sol_mac; // MAC to send reply
    bool sol_ip;  // IP to send reply
    icmp_mld_t mld;
  };

  struct meta_t
  {
    meta_mac_t mac;
    meta_ip_t ip;
    meta_icmp_t icmp;
    meta_udp_t udp;
    meta_tcp_t tcp;
    meta_dns_t dns;
  };

  struct parse_err_t
  {
    bool
        ERR_NONE,
        ERR_FCS,
        ERR_ETH_TOO_SMALL,
        ERR_ETH_TOO_BIG,
        ERR_ETH_NOT_IP,
        ERR_IP_PROTO,
        ERR_IP_VER,
        ERR_IP_ZERO_LEN,
        ERR_IP_HOPS_EXHAUSTED,
        ERR_ICMP_UNKNOWN_TYPE,
        ERR_ICMP_CHECKSUM,
        ERR_ICMP_BAD_LENGTH,
        ERR_ICMP_BAD_SRC_LNKA_OPTION_LENGTH,
        ERR_ICMP_RS_SRC_LNKA_NOT_PRESENT,
        ERR_ICMP_TOO_SMALL,
        ERR_ICMP_TOO_BIG,
        ERR_ICMP_UNKNOWN_OPTION,
        ERR_ICMP_OPTION_LEN,
        ERR_ICMP_BAD_CODE,
        ERR_ICMP_BAD_RES,
        ERR_ICMP_TOO_SHORT,
        ERR_TCP_OFFSET_BAD;
  };

  static constexpr unsigned ETH_ERRORS = 11;

  enum gen_err_eth_t
  {
    ERR_ETH_NONE,
    ERR_PREAMBLE_BAD_BYTE,
    ERR_PREAMBLE_TOO_SHORT,
    ERR_PREAMBLE_TOO_LONG,
    ERR_PREAMBLE_SFD_SKIP,
    ERR_PREAMBLE_SFD_BAD,
    ERR_FCS_BAD_BYTE,
    ERR_FCS_SKIP,
    ERR_ETHERTYPE,
    ERR_DST_MAC,
    ERR_EXTRA_BYTE
  };

  enum gen_err_ip_t
  {
    ERR_IP_NONE,
    ERR_IP_VER_BAD,
    ERR_IP_LEN_ZERO,
    ERR_IP_LEN_FFFF,
    ERR_IP_LEN_BAD_PLUS_1,
    ERR_IP_LEN_BAD_MINUS_1,
    ERR_IP_NXT_BAD,
    ERR_IP_HOP_ZERO,
    ERR_IP_DST_GROUP_BAD,
    ERR_IP_DST_PREFIX_BAD,
    ERR_IP_DST_INTERFACE_ID_BAD
  };

  enum gen_err_icmp_t
  {
    ERR_ICMP_NONE,
    ERR_ICMP_BAD_TYPE,
    ERR_ICMP_BAD_CODE,
    ERR_ICMP_TARGET_IP_MISSING,
    ERR_ICMP_TARGET_IP_BAD,
    ERR_ICMP_CHECKSUM_BAD
  };

  enum gen_err_udp_t
  {
    ERR_UDP_NONE,
    ERR_UDP_CHECKSUM_BAD,
    ERR_UDP_LENGTH_ZERO,
    ERR_UDP_LENGTH_FFFF,
    ERR_UDP_LENGTH_BAD
  };

  enum gen_err_tcp_t
  {
    ERR_TCP_NONE,
    ERR_TCP_OFFSET_BAD,
    ERR_TCP_CHECKSUM_BAD,
    ERR_TCP_DST_PORT_BAD
  };

  enum gen_err_dns_t
  {
    ERR_DNS_NONE,
    ERR_DNS_STRING_BAD
  };

  enum pro_t
  {
    eth,
    ip,
    icmp,
    udp,
    dns,
    tcp
  };

  struct gen_err_t
  {
    gen_err_eth_t eth;
    gen_err_ip_t ip;
    gen_err_icmp_t icmp;
    gen_err_udp_t udp;
    gen_err_dns_t dns;
    gen_err_tcp_t tcp;
  };

  struct pkt_t
  {
    meta_t meta;         // Packet metainformation
    vector<uint8_t> pld; // Payload
    parse_err_t err_rx;  // Errors detected in packet from DUT
    gen_err_t err_tx;    // Error to injext into packet for DUT
  };

  // Settings for RA prefix option
  struct ra_pfx_setting_t
  {
    bool pres;
    ip_t pfx;
    uint8_t len;
  };

  // RDNSS option server list
  struct ra_dns_setting_t
  {
    bool pres;
    vector<ip_t> dns_ip;
  };

  // Setting for RA MTU option
  struct ra_mtu_setting_t
  {
    bool pres;
    uint32_t mtu;
  };

  pkt_c();

  ~pkt_c();

  static uint32_t *gen_crc_tbl();

  /////////////
  // Methods //
  /////////////

  // State variables
  unsigned tx_ptr;
  unsigned ifg_ctr;

  // pcap log
  pcap *pcap_log;
  int tx_idx = 0;
  // queue of packets
  vector<pkt_c::pkt_t> tx_buf;

  vector<uint8_t> raw_rx; // current packet being received
  vector<uint8_t> raw_tx; // current packet being transmitted
  vector<uint8_t> PREAMBLE{0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5};

  static pkt_c::ip_t gen_lla(
      const pkt_c::mac_t &mac);

  static pkt_c::ip_t gen_ga(
      const pkt_c::ip_t &lla,
      const pkt_c::ip_t &pfx,
      const uint8_t &pfx_len);

  static pkt_c::mac_t gen_mac_mcast(
      const pkt_c::ip_t &ip);

  static pkt_c::ip_t gen_ip_mcast(
      const pkt_c::ip_t &lla);

  // Add a packet to tx queue
  void send_pkt(
      pkt_c::pkt_t &pkt);

  bool sending();

  static ip_t extract_ip(
      const vector<uint8_t> &raw,
      const int &idx);

  static mac_t extract_mac(
      const vector<uint8_t> &raw,
      const int &idx);

  static void append_ip(
      vector<uint8_t> &raw,
      const ip_t &ip);

  static bool is_multicast(
      const ip_t &ip);

  static bool is_solicited_multicast(
      const ip_t &ip,
      const ip_t &sol);

  static bool is_solicited_multicast(
      const ip_t &ip,
      const mac_t &sol);

  static uint32_t cks_ip(
      const ip_t &ip);

  // Packet processing
  static void parse(
      vector<uint8_t> &raw,
      pkt_c::pkt_t &pkt,
      parse_err_t &err);

  static void parse_icmp(
      vector<uint8_t> &raw,
      meta_icmp_t &meta,
      parse_err_t &err,
      vector<uint8_t> &pld);

  static void parse_udp(
      vector<uint8_t> &raw,
      meta_udp_t &meta,
      parse_err_t &err);

  static void parse_dns(
      vector<uint8_t> &raw,
      meta_dns_t &meta,
      parse_err_t &err);

  static void parse_tcp(
      vector<uint8_t> &raw,
      meta_tcp_t &meta,
      parse_err_t &err,
      vector<uint8_t> &pld);

  static void parse_ip(
      vector<uint8_t> &raw,
      meta_ip_t &meta,
      parse_err_t &err);

  static void parse_eth(
      vector<uint8_t> &raw,
      meta_mac_t &meta,
      parse_err_t &err);

  static void generate(
      vector<uint8_t> &raw,
      const pkt_t &pkt);

  static void generate_icmp(
      vector<uint8_t> &raw,
      const meta_icmp_t &meta);

  static void generate_icmp(
      vector<uint8_t> &raw,
      const meta_icmp_t &meta,
      const gen_err_t &err);

  static void generate_udp(
      vector<uint8_t> &raw,
      const meta_udp_t &meta);

  static void generate_dns(
      vector<uint8_t> &raw,
      const meta_dns_t &meta);

  static void generate_tcp(
      vector<uint8_t> &raw,
      const meta_tcp_t &meta);

  static void generate_ip(
      vector<uint8_t> &raw,
      const meta_ip_t &meta,
      const gen_err_ip_t &err);

  static void generate_eth(
      vector<uint8_t> &raw,
      const meta_mac_t &meta,
      const gen_err_eth_t &err);

  static void generate_bad(
      vector<uint8_t> &raw,
      const pkt_t &pkt,
      const gen_err_t err);

  static bool is_multicast(
      mac_t &mac);

  void tx_add_pkt(
      vector<uint8_t> &raw);

  template <class T>
  static T extract(
      const vector<uint8_t> &raw,
      size_t idx);

  static void append(
      vector<uint8_t> &raw,
      const uint8_t &dat);

  static void append(
      vector<uint8_t> &raw,
      const uint16_t &dat);

  static void append(
      vector<uint8_t> &raw,
      const uint32_t &dat);

  static void append(
      vector<uint8_t> &raw,
      const mac_t &dat);

  static void append(
      vector<uint8_t> &raw,
      const ip_t &dat);

  static void prepend(
      vector<uint8_t> &raw,
      const uint8_t &dat);

  static void prepend(
      vector<uint8_t> &raw,
      const uint16_t &dat);

  static void prepend(
      vector<uint8_t> &raw,
      const uint32_t &dat);

  static void prepend(
      vector<uint8_t> &raw,
      const mac_t &dat);

  static void prepend(
      vector<uint8_t> &raw,
      const ip_t &dat);

  static uint32_t extract_32(
      vector<uint8_t> raw,
      int idx);

  static bool check_pre(
      vector<uint8_t> raw);

  static bool check_fcs(
      const vector<uint8_t> raw,
      uint32_t &crc);

  static uint32_t gen_fcs(
      vector<uint8_t> raw);

  //
  static void append_mac(
      vector<uint8_t> &raw,
      mac_t mac);

  // Calculate checksum over IP payload and pseudo hdr
  static uint16_t calc_checksum(
      const vector<uint8_t> &raw,
      const uint8_t &proto,
      const ip_t &src,
      const ip_t &dst);

  // Insert checksum into raw packet
  static void insert_checksum(
      vector<uint8_t> &raw,
      const uint8_t &proto,
      const uint16_t &cks);

  void process_rx(
      const uint8_t &phy_dat,
      const bool &phy_val,
      parse_err_t &err);

  // Process outgoing PHY stream
  // Packets are loaded from tx_buf
  void process_tx(
      uint8_t &phy_dat,
      bool &phy_val);
};
#endif
