#include "pkt_c.h"

constexpr pkt_c::ip_t pkt_c::IP_MULTICAST_ALL_DEVICES;
constexpr pkt_c::ip_t pkt_c::IP_MULTICAST_ALL_ROUTERS;
constexpr pkt_c::ip_t pkt_c::IP_MULTICAST_MLD;
constexpr pkt_c::mac_t pkt_c::MAC_MULTICAST_ALL_ROUTERS;
constexpr pkt_c::mac_t pkt_c::MAC_MULTICAST_ALL_DEVICES;
constexpr pkt_c::mac_t pkt_c::MAC_MULTICAST_MLD;
constexpr pkt_c::ip_t pkt_c::IP_UNSPECIFIED;

constexpr uint32_t pkt_c::CRC_POLY;
constexpr uint32_t pkt_c::CRC_MAGIC_NUMBER;

// Ethertypes
constexpr uint16_t pkt_c::IPV6;
constexpr uint16_t pkt_c::ARP;
constexpr unsigned pkt_c::FCS_BYTES;
constexpr unsigned pkt_c::PREAMBLE_BYTES;
constexpr unsigned pkt_c::MAC_OFFSET;
// ICMP message types
constexpr uint8_t pkt_c::ICMP_TYPE_ECHO_REQUEST;
constexpr uint8_t pkt_c::ICMP_TYPE_ECHO_REPLY;
constexpr uint8_t pkt_c::ICMP_TYPE_ROUTER_SOLICITATION;
constexpr uint8_t pkt_c::ICMP_TYPE_ROUTER_ADVERTISEMENT;
constexpr uint8_t pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION;
constexpr uint8_t pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT;
constexpr uint8_t pkt_c::ICMP_TYPE_MULTICAST_LISTENER_REPORT_V2;
// ICMP message type head   er lengths
constexpr uint8_t pkt_c::ICMP_ECHO_HLEN;
constexpr uint8_t pkt_c::ICMP_RS_HLEN;
constexpr uint8_t pkt_c::ICMP_RA_HLEN;
constexpr uint8_t pkt_c::ICMP_NEIGHBOR_HLEN;
constexpr uint8_t pkt_c::ICMP_MLD_HLEN;
// ICMP options
constexpr uint8_t pkt_c::ICMP_OPTION_RECURSIVE_DNS_SERVERS;
constexpr uint8_t pkt_c::ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS;
constexpr uint8_t pkt_c::ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS;
constexpr uint8_t pkt_c::ICMP_OPTION_PREFIX_INFORMATION;
constexpr uint8_t pkt_c::ICMP_OPTION_REDIRECT;
constexpr uint8_t pkt_c::ICMP_OPTION_MTU;
// ICMP option lengths
constexpr uint8_t pkt_c::ICMP_OPTION_RECURSIVE_DNS_SERVERS_LENGTH;
constexpr uint8_t pkt_c::ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH;
constexpr uint8_t pkt_c::ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS_LENGTH;
constexpr uint8_t pkt_c::ICMP_OPTION_PREFIX_INFORMATION_LENGTH;
constexpr uint8_t pkt_c::ICMP_OPTION_MTU_LENGTH;
// Router Advertiesment flags
constexpr uint8_t pkt_c::RA_MANAGED_FLAG;
constexpr uint8_t pkt_c::RA_OTHER_FLAG;
constexpr uint8_t pkt_c::RA_HOME_FLAG;
constexpr uint8_t pkt_c::RA_PREF_HIGH_FLAG;
constexpr uint8_t pkt_c::RA_PREF_MEDIUM_FLAG;
constexpr uint8_t pkt_c::RA_PREF_LOW_FLAG;
constexpr uint8_t pkt_c::RA_PREF_BAD_FLAG;
constexpr uint8_t pkt_c::RA_PROXY_FLAG;
// RDNSS option
constexpr uint8_t pkt_c::IP_OPTION_HOP_BY_HOP;
constexpr uint8_t pkt_c::ICMP_OPTION_DNS_LENGTH;

constexpr uint8_t pkt_c::ICMP;
constexpr uint8_t pkt_c::UDP;
constexpr uint8_t pkt_c::TCP;
constexpr size_t pkt_c::IP_HDR_LEN;

constexpr uint8_t pkt_c::TCP_OPT_END;
constexpr uint8_t pkt_c::TCP_OPT_NOP;
constexpr uint8_t pkt_c::TCP_OPT_MSS;
constexpr uint8_t pkt_c::TCP_OPT_SCL;
constexpr uint8_t pkt_c::TCP_OPT_SACK_PERM;
constexpr uint8_t pkt_c::TCP_OPT_SACK;
constexpr uint8_t pkt_c::TCP_OPT_TIM;
constexpr uint8_t pkt_c::TCP_OPT_MSS_LEN;
constexpr uint8_t pkt_c::TCP_OPT_SCL_LEN;
constexpr uint8_t pkt_c::TCP_OPT_SACK_PERM_LEN;
constexpr uint8_t pkt_c::TCP_OPT_TIM_LEN;

constexpr uint16_t pkt_c::DNS_PORT;
constexpr uint16_t pkt_c::DNS_HEADER_LEN;
constexpr uint16_t pkt_c::DNS_QUERY_INFO_LEN;
constexpr uint16_t pkt_c::DNS_TYPE_AAAA;
constexpr uint16_t pkt_c::DNS_CLASS_IN;
constexpr uint16_t pkt_c::DNS_RESP_DEFAULT_TTL;
constexpr uint8_t pkt_c::DNS_POINTER;
constexpr uint8_t pkt_c::DNS_POINTER_VALUE;

constexpr unsigned pkt_c::IP_HEADER_LEN;
constexpr unsigned pkt_c::TCP_HEADER_MAX_LEN;

pkt_c::pkt_c()
{

  ifg_ctr = 0;
}

pkt_c::~pkt_c()
{
}

void pkt_c::parse(
    vector<uint8_t> &raw,
    pkt_t &pkt,
    parse_err_t &err)
{
  if (raw.size() < 64)
  {
    err.ERR_ETH_TOO_SMALL = true;
    return;
  }
  pkt.meta = {0};
  pkt.pld.clear();

  parse_eth(raw, pkt.meta.mac, pkt.err_rx);
  parse_ip(raw, pkt.meta.ip, pkt.err_rx);

  ////////////////
  // IP payload //
  ////////////////
  switch (pkt.meta.ip.proto)
  {
  case (ICMP):
  {
    parse_icmp(raw, pkt.meta.icmp, pkt.err_rx, pkt.pld);
    break;
  }
  case (UDP):
  {
    parse_udp(raw, pkt.meta.udp, pkt.err_rx);
    if (pkt.meta.udp.dst == DNS_PORT)
      parse_dns(raw, pkt.meta.dns, pkt.err_rx);
    break;
  }
  case (TCP):
  {
    parse_tcp(raw, pkt.meta.tcp, pkt.err_rx, pkt.pld);
    break;
  }
  }
}

void pkt_c::generate(
    vector<uint8_t> &raw,
    const pkt_t &pkt)
{
  raw.clear();
  switch (pkt.meta.ip.proto)
  {
  case (ICMP):
  {
    generate_icmp(raw, pkt.meta.icmp, pkt.err_tx);
    break;
  }
  case (UDP):
  {
    if (pkt.meta.udp.src == DNS_PORT)
    {
      generate_dns(raw, pkt.meta.dns);
    }
    generate_udp(raw, pkt.meta.udp);
    break;
  }
  case (TCP):
  {
    generate_tcp(raw, pkt.meta.tcp);
    break;
  }
  }
  if (pkt.pld.size())
    raw.insert(raw.end(), pkt.pld.begin(), pkt.pld.end());
  uint16_t cks = calc_checksum(
      raw,
      pkt.meta.ip.proto,
      pkt.meta.ip.src,
      pkt.meta.ip.dst);
  insert_checksum(raw, pkt.meta.ip.proto, cks);
  generate_ip(raw, pkt.meta.ip, pkt.err_tx.ip);
  generate_eth(raw, pkt.meta.mac, pkt.err_tx.eth);
}

uint32_t *pkt_c::gen_crc_tbl()
{
  static uint32_t crc_tbl[256];
  for (int i = 0; i < 256; i++)
  {
    uint32_t cur = i;
    for (int j = 0; j < 8; j++)
    {
      cur = (cur & 1) ? (cur >> 1) ^ CRC_POLY : cur >> 1;
    }
    crc_tbl[i] = cur;
  }
  return crc_tbl;
}

/////////
// MAC //
/////////

/*
 Generates FCS for a given packet. Accepts packet witout preamble
*/
uint32_t pkt_c::gen_fcs(vector<uint8_t> raw)
{
  uint32_t crc = 0xffffffff;
  uint32_t *crc_tbl = gen_crc_tbl();
  for (size_t i = 0; i < raw.size(); i++)
  {
    crc = crc_tbl[(crc ^ raw[i]) & 0xff] ^ (crc >> 8);
  }
  return crc;
}

/*
Check FCS of a given raw packet. Accepts whole packet including preamble
*/

bool pkt_c::check_fcs(const vector<uint8_t> raw, uint32_t &crc)
{
  crc = 0xffffffff;
  uint32_t *crc_tbl = gen_crc_tbl();
  for (size_t i = 8; i < raw.size(); i++)
  {
    crc = crc_tbl[(crc ^ raw[i]) & 0xff] ^ (crc >> 8);
  }
  return (crc != CRC_MAGIC_NUMBER);
}

/*
Template to exctact values from raw packet as byte vector
*/

template <class T>
T pkt_c::extract(const vector<uint8_t> &raw, const size_t idx)
{
  T val = 0;
  if (idx + sizeof(T) > raw.size())
    return 0;
  for (int i = 0; i < sizeof(T); i++)
  {
    val = raw[idx + i] << (sizeof(T) - i - 1) * 8 | val;
  }
  return val;
}

pkt_c::ip_t pkt_c::extract_ip(
    const vector<uint8_t> &raw,
    const int &idx)
{
  ip_t ip;
  if (idx + sizeof(ip_t) > raw.size())
    return {0};
  for (int i = 0; i < sizeof(ip_t); i++)
  {
    ip.i[i] = raw[idx + i];
  }
  return ip;
}

pkt_c::mac_t pkt_c::extract_mac(
    const vector<uint8_t> &raw,
    const int &idx)
{
  mac_t mac;
  if (idx + sizeof(mac_t) > raw.size())
    return {0};
  for (int i = 0; i < sizeof(mac_t); i++)
  {
    mac.m[i] = raw[idx + i];
  }
  return mac;
}

/*
Parse raw 'pkt', extract header to 'meta', copy payload to 'data' if any
*/
void pkt_c::parse_eth(
    vector<uint8_t> &raw,
    meta_mac_t &meta,
    parse_err_t &err)
{
  uint32_t crc;
  if (check_fcs(raw, crc))
    err.ERR_FCS = true;
  for (int i = 0; i < sizeof(pkt_c::mac_t); i++)
  {
    meta.dst.m[i] = raw[PREAMBLE_BYTES + i];
    meta.src.m[i] = raw[PREAMBLE_BYTES + sizeof(pkt_c::mac_t) + i];
  }
  meta.ethertype = extract<uint16_t>(raw, PREAMBLE_BYTES + sizeof(pkt_c::mac_t) * 2);
  // remove MAC header and FCS from packet
  raw = {raw.begin() + MAC_OFFSET, raw.end() - 4};

  // Check for basic errors
  if (!raw.size())
    err.ERR_ETH_TOO_SMALL = true;
  // if (!meta.length > MTU)
  //   err = ERR_ETH_TOO_BIG;
  if (meta.ethertype != IPV6)
    err.ERR_ETH_NOT_IP = true;
}

void pkt_c::parse_ip(
    vector<uint8_t> &raw,
    meta_ip_t &meta,
    parse_err_t &err)
{
  uint8_t version = (raw[0] >> 4 & 0x0f);
  unsigned option_len = 0;
  if (version != 6)
  {
    err.ERR_IP_VER = true;
  }
  meta.traffic_class = (raw[0] << 4 & 0xf0) | (raw[1] >> 4 & 0x0f);
  meta.flow_label = (raw[1] << 16 & 0x0000f0000) | (raw[2] << 8 & 0x00000ff00) | (raw[3] & 0x0000000ff);
  if (extract<uint16_t>(raw, 4) == 0)
    err.ERR_IP_ZERO_LEN = true;
  meta.len = (raw[4] << 8 & 0xff00) | (raw[5] & 0x000ff);
  meta.proto = raw[6];
  meta.hops = raw[7];
  if (meta.hops == 0)
    err.ERR_IP_HOPS_EXHAUSTED = true;
  for (int i = 0; i < sizeof(pkt_c::ip_t); i++)
  {
    meta.src.i[i] = raw[8 + i];
    meta.dst.i[i] = raw[8 + i + sizeof(pkt_c::ip_t)];
  }
  if (meta.proto == IP_OPTION_HOP_BY_HOP) // todo parse router alert
  {
    meta.proto = raw[40];
    option_len = 8;
  }
  raw = {raw.begin() + IP_HDR_LEN + option_len, raw.end()}; // Remove already extracted data
};

void pkt_c::parse_icmp(
    vector<uint8_t> &raw, // Raw ICMP packet (IP packet's payload)
    meta_icmp_t &meta,    // Parsed ICMP metadata
    parse_err_t &err,     // Parse error
    vector<uint8_t> &pld) // Payload od the packet
{
  // Common part of the packet
  meta.type = raw[0];
  meta.code = raw[1];
  // uint16_t icmp_checksum = extract<uint16_t>(raw, 2);
  //
  switch (meta.type)
  {
  case (ICMP_TYPE_ECHO_REQUEST):
  case (ICMP_TYPE_ECHO_REPLY):
  {
    if (raw.size() != ICMP_ECHO_HLEN)
    {
      err.ERR_ICMP_BAD_LENGTH = true;
    }
    meta.echo_id = extract<uint16_t>(raw, 4);
    meta.echo_seq = extract<uint16_t>(raw, 6);
    if (raw.size() > 8)
      pld = {raw.begin() + 8, raw.end()};
    break;
  }
  case (ICMP_TYPE_ROUTER_SOLICITATION):
  {
    if (raw.size() != ICMP_RS_HLEN + ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH)
    {
      err.ERR_ICMP_BAD_LENGTH = true;
    }
    if (extract<uint32_t>(raw, 4) != 0)
      err.ERR_ICMP_BAD_RES = true;
    if (raw[8] != ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS)
    {
      err.ERR_ICMP_RS_SRC_LNKA_NOT_PRESENT = true;
      break;
    }
    if (raw[9] != ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH)
    {
      err.ERR_ICMP_BAD_SRC_LNKA_OPTION_LENGTH = true;
      break;
    }
    meta.opt.src_lnka.pres = true;
    meta.opt.src_lnka.mac = extract_mac(raw, 10);
    break;
  }
  case (ICMP_TYPE_ROUTER_ADVERTISEMENT):
  {
    meta.ra_cur_hop_lim = raw[4];
    meta.ra_flags = raw[5];
    meta.ra_router_lifetime = extract<uint16_t>(raw, 6);
    meta.ra_reach_time = extract<uint32_t>(raw, 8);
    meta.ra_retrans_time = extract<uint32_t>(raw, 12);
    break;
  };
  case (ICMP_TYPE_NEIGHBOR_SOLICITATION):
  {
    if (extract<uint32_t>(raw, 4) != 0)
    {
      err.ERR_ICMP_BAD_RES = true;
    }
    meta.tar_pres = true;
    for (int i = 0; i < sizeof(pkt_c::ip_t); i++)
    {
      meta.tar_ip.i[i] = raw[8 + i];
    }
    break;
  }
  case (ICMP_TYPE_NEIGHBOR_ADVERTISEMENT):
  {
    meta.na_flags = extract<uint32_t>(raw, 4);
    meta.tar_pres = true;
    for (int i = 0; i < sizeof(pkt_c::ip_t); i++)
    {
      meta.tar_ip.i[i] = raw[8 + i];
    };
    break;
  }
  case (ICMP_TYPE_MULTICAST_LISTENER_REPORT_V2):
  {
    meta.mld.reserved = extract<uint16_t>(raw, 4);
    meta.mld.num_rec = extract<uint16_t>(raw, 6);
    meta.mld.rec_typ = raw[8];
    meta.mld.aux_dat_len = raw[9];
    meta.mld.num_src = extract<uint16_t>(raw, 10);
    for (int i = 0; i < sizeof(pkt_c::ip_t); i++)
    {
      meta.mld.mcast_addr.i[i] = raw[12 + i];
    };
    break;
  }
  default:
  {
    err.ERR_ICMP_UNKNOWN_TYPE = true;
    break;
  }
  }
}

void pkt_c::parse_udp(
    vector<uint8_t> &raw,
    meta_udp_t &meta,
    parse_err_t &err)
{
  meta.src = extract<uint16_t>(raw, 0);
  meta.dst = extract<uint16_t>(raw, 2);
  meta.len = extract<uint16_t>(raw, 4);
  meta.cks = extract<uint16_t>(raw, 6);
}

void pkt_c::parse_dns(
    vector<uint8_t> &raw,
    meta_dns_t &meta,
    parse_err_t &err)
{
  meta.id = extract<uint16_t>(raw, 8);
  meta.flags = extract<uint16_t>(raw, 10);
  meta.questions = extract<uint16_t>(raw, 12);
  meta.ans_rrs = extract<uint16_t>(raw, 14);
  meta.aut_rrs = extract<uint16_t>(raw, 16);
  meta.add_rrs = extract<uint16_t>(raw, 18);
  meta.query_str.clear();
  unsigned i = 0;
  while (raw[20 + i] != 0x00)
    meta.query_str += raw[20 + i++];
  meta.query_type = extract<uint16_t>(raw, meta.query_str.size() + DNS_HEADER_LEN);
  meta.query_class = extract<uint16_t>(raw, meta.query_str.size() + DNS_HEADER_LEN + 2);
}

void pkt_c::parse_tcp(
    vector<uint8_t> &raw,
    meta_tcp_t &meta,
    parse_err_t &err,
    vector<uint8_t> &pld)
{
  uint8_t ofs;
  meta.src = extract<uint16_t>(raw, 0);
  meta.dst = extract<uint16_t>(raw, 2);
  meta.seq = extract<uint32_t>(raw, 4);
  meta.ack = extract<uint32_t>(raw, 8);
  ofs = extract<uint8_t>(raw, 12);
  ofs = (ofs >> 4) & 0xf;
  meta.flg = extract<uint16_t>(raw, 12);
  meta.flg = meta.flg & 0xfff;
  meta.wnd = extract<uint16_t>(raw, 14);
  meta.cks = extract<uint16_t>(raw, 16);
  meta.ptr = extract<uint16_t>(raw, 18);
  uint8_t hdr_len = ofs << 2;
  if (hdr_len > raw.size())
  {
    err.ERR_TCP_OFFSET_BAD = true;
    return;
  }
  tcp_field_t cur_field = typ;
  uint8_t cur_opt_typ;
  uint8_t cur_opt_len;
  size_t pos;
  //
  for (pos = TCP_HDR_LEN; pos < hdr_len; pos++) // start after hdr. parse opts
  {
    switch (cur_field)
    {
    case (typ):
    {
      cur_opt_typ = raw[pos];
      switch (cur_opt_typ)
      {
      case (TCP_OPT_END):
      {
        cur_field = typ;
        break;
      }
      case (TCP_OPT_NOP):
      {
        cur_field = typ;
        break;
      }
      case (TCP_OPT_MSS):
      {
        cur_field = len;
        meta.opt.mss_pres = true;
        break;
      }
      case (TCP_OPT_SCL):
      {
        cur_field = len;
        meta.opt.wnd_pres = true;
        break;
      }
      case (TCP_OPT_SACK_PERM):
      {
        meta.opt.sack_perm_pres = true;
        cur_field = len;
        break;
      }
      case (TCP_OPT_SACK):
      {
        meta.opt.sack_pres = true;
        cur_field = len;
        break;
      }
      case (TCP_OPT_TIM):
      {
        meta.opt.tim_pres = true;

        cur_field = len;
        break;
      }
      }
      break;
    }
    case (len):
    {
      cur_opt_len = raw[pos]; // remember current option length
      // SACK permitted is an exlusion not having any data
      cur_field = (cur_opt_typ == TCP_OPT_SACK_PERM) ? typ : dat;
      break;
    }
    case (dat):
    {
      switch (cur_opt_typ)
      {
      case (TCP_OPT_MSS):
      {
        meta.opt.mss = extract<uint16_t>(raw, pos);
        pos = pos + 1; // readout 16 bits (adjust pos)
        cur_field = typ;
        break;
      }
      case (TCP_OPT_SCL):
      {
        meta.opt.wnd = extract<uint8_t>(raw, pos);
        cur_field = typ;
        break;
      }
      case (TCP_OPT_SACK):
      {
        unsigned blocks = (cur_opt_len - 2) / 8;
        for (unsigned blk_idx = 0; blk_idx < 4; blk_idx++)
          meta.opt.sack.b[blk_idx].pres = false;
        for (unsigned blk_idx = 0; blk_idx < blocks; blk_idx++)
        {
          meta.opt.sack.b[blk_idx].pres = true;
          meta.opt.sack.b[blk_idx].left = extract<uint32_t>(raw, pos);
          meta.opt.sack.b[blk_idx].right = extract<uint32_t>(raw, pos + 4);
          pos = pos + 8; // readout 16 bits (adjust pos)
        }
        cur_field = typ;
        break;
      }
      case (TCP_OPT_TIM):
      {
        cur_field = typ;
        break;
      }
      }
      break;
    }
    }
  }
  if (pos != raw.size())
  {
    pld = {raw.begin() + pos, raw.end()};
  }
}

////////////////////////
// ICMP Common header //
////////////////////////
void pkt_c::generate_icmp(
    vector<uint8_t> &raw,
    const meta_icmp_t &meta,
    const gen_err_t &err)
{
  append(raw, meta.type);
  append(raw, meta.code);
  append(raw, (uint16_t)0);
  //////////////////////////////////
  // ICMP Message specific header //
  //////////////////////////////////
  switch (meta.type)
  {
  case (ICMP_TYPE_ECHO_REPLY):
  case (ICMP_TYPE_ECHO_REQUEST):
  {
    append(raw, meta.echo_id);
    append(raw, meta.echo_seq);
    break;
  }
  case (ICMP_TYPE_ROUTER_ADVERTISEMENT):
  {
    append(raw, (uint8_t)(0xff));
    append(raw, meta.ra_flags);
    append(raw, meta.ra_router_lifetime);
    append(raw, meta.ra_reach_time);
    append(raw, meta.ra_retrans_time);
    break;
  }
  case (ICMP_TYPE_ROUTER_SOLICITATION):
  {
    append(raw, (uint8_t)0);
    break;
  }
  case (ICMP_TYPE_NEIGHBOR_SOLICITATION):
  case (ICMP_TYPE_NEIGHBOR_ADVERTISEMENT):
  {
    append(raw, (uint32_t)0);
    append(raw, meta.tar_ip);
    break;
  }
  }
  // ICMP options
  if (meta.opt.mtu.pres)
  {
    append(raw, ICMP_OPTION_MTU);
    append(raw, ICMP_OPTION_MTU_LENGTH);
    append(raw, (uint8_t)0);
    append(raw, (uint8_t)0);
    append(raw, meta.opt.mtu.mtu);
  }
  if (meta.opt.rdnss.pres)
  {
    append(raw, ICMP_OPTION_RECURSIVE_DNS_SERVERS);
    append(raw, ICMP_OPTION_RECURSIVE_DNS_SERVERS_LENGTH);
    append(raw, (uint8_t)0);
    append(raw, (uint8_t)0);
    append(raw, meta.opt.rdnss.life);
    for (int i = 0; i < meta.opt.rdnss.dns_ip.size(); i++)
      append(raw, meta.opt.rdnss.dns_ip[i]);
  }
  if (meta.opt.src_lnka.pres)
  {
    append(raw, ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS);
    append(raw, ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH);
    append(raw, meta.opt.src_lnka.mac);
  }
  if (meta.opt.tar_lnka.pres)
  {
    append(raw, ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS);
    append(raw, ICMP_OPTION_TARGET_LINK_LAYER_ADDRESS_LENGTH);
    append(raw, meta.opt.tar_lnka.mac);
  }
  if (meta.opt.pfx.pres)
  {
    append(raw, ICMP_OPTION_PREFIX_INFORMATION);
    append(raw, ICMP_OPTION_PREFIX_INFORMATION_LENGTH);
    append(raw, meta.opt.pfx.len);
    append(raw, meta.opt.pfx.flags);
    append(raw, meta.opt.pfx.vlife);
    append(raw, meta.opt.pfx.plife);
    append(raw, (uint32_t)0);
    append(raw, meta.opt.pfx.ip);
  }
}

void pkt_c::generate_udp(
    vector<uint8_t> &raw,
    const meta_udp_t &meta)
{
  uint16_t udp_len = raw.size() + UDP_HLEN;

  prepend(raw, meta.cks);
  prepend(raw, udp_len);
  prepend(raw, meta.dst);
  prepend(raw, meta.src);
}

void pkt_c::generate_dns(
    vector<uint8_t> &raw,
    const meta_dns_t &meta)
{
  append(raw, meta.id);
  append(raw, meta.flags);
  append(raw, meta.questions);
  append(raw, meta.ans_rrs);
  append(raw, meta.aut_rrs);
  append(raw, meta.add_rrs);
  // query
  for (size_t i = 0; i < meta.query_str.size(); i++)
    raw.insert(raw.end(), meta.query_str[i]);
  append(raw, (uint8_t)(0));
  append(raw, meta.query_type);
  append(raw, meta.query_class);
  // answer
  append(raw, DNS_POINTER);
  append(raw, DNS_POINTER_VALUE);
  append(raw, meta.answer_type);
  append(raw, meta.answer_class);
  append(raw, meta.answer_ttl);
  append(raw, uint16_t(sizeof(ip_t)));
  append(raw, meta.answer_addr);
}

void pkt_c::generate_tcp(
    vector<uint8_t> &raw,
    const meta_tcp_t &meta)
{
  uint8_t ofs = 5;
  if (meta.opt.mss_pres)
    ofs++;
  if (meta.opt.sack_perm_pres)
    ofs++;
  if (meta.opt.wnd_pres)
    ofs++;
  if (meta.opt.tim_pres)
    ofs = ofs + 2;
  append(raw, meta.src);
  append(raw, meta.dst);
  append(raw, meta.seq);
  append(raw, meta.ack);
  uint16_t ofs_flg = (ofs << 12) & 0xf000 | (meta.flg & 0x0fff);
  append(raw, ofs_flg);
  append(raw, meta.wnd);
  append(raw, (uint16_t)0);
  append(raw, meta.ptr);
  if (meta.opt.mss_pres)
  {
    append(raw, TCP_OPT_MSS);
    append(raw, TCP_OPT_MSS_LEN);
    append(raw, meta.opt.mss);
  }
  if (meta.opt.sack_perm_pres)
  {
    append(raw, TCP_OPT_SACK_PERM);
    append(raw, TCP_OPT_SACK_PERM_LEN);
    append(raw, TCP_OPT_NOP);
    append(raw, TCP_OPT_NOP);
  }
  if (meta.opt.sack_pres)
  {
    append(raw, TCP_OPT_SACK);
    uint8_t sack_len = 2;
    for (int i = 0; i < 4; i++)
      sack_len = sack_len + 8;
    append(raw, sack_len);
    for (unsigned i = 0; i < 3; i++)
    {
      if (meta.opt.sack.b[i].pres)
      {
        append(raw, meta.opt.sack.b[i].left);
        append(raw, meta.opt.sack.b[i].right);
      }
    }
  }
  if (meta.opt.tim_pres)
  {
    append(raw, TCP_OPT_TIM);
    append(raw, TCP_OPT_TIM_LEN);
    append(raw, meta.opt.tim.start);
    append(raw, meta.opt.tim.stop);
  }
  if (meta.opt.wnd_pres)
  {
    append(raw, TCP_OPT_SCL);
    append(raw, TCP_OPT_SCL_LEN);
    append(raw, meta.opt.wnd);
    append(raw, TCP_OPT_NOP);
  }
}

void pkt_c::generate_ip(
    vector<uint8_t> &raw,
    const meta_ip_t &meta,
    const gen_err_ip_t &err)
{
  uint16_t length = raw.size();
  uint8_t version = 6;
  uint8_t proto = meta.proto;
  ip_t dst = meta.dst;
  ip_t src = meta.src;
  if (err == ERR_IP_DST_GROUP_BAD)
    src.i[rand() % 2]++;
  if (err == ERR_IP_DST_PREFIX_BAD)
    src.i[rand() % 6 + 2]++;
  if (err == ERR_IP_VER_BAD)
    version = version++;
  if (err == ERR_IP_LEN_BAD_PLUS_1)
    length++;
  if (err == ERR_IP_LEN_BAD_MINUS_1)
    length--;
  if (err == ERR_IP_LEN_ZERO)
    length = 0;
  if (err == ERR_IP_LEN_FFFF)
    length = 0xffff;
  if (err == ERR_IP_NXT_BAD)
    proto++;
  prepend(raw, meta.dst);
  prepend(raw, meta.src);
  prepend(raw, meta.hops);
  prepend(raw, proto);
  prepend(raw, length);
  prepend(raw, (uint16_t)(meta.flow_label & 0xffff));
  prepend(raw, (uint8_t)(meta.traffic_class << 4 & 0xf0 | meta.flow_label >> 16 & 0x0f));
  prepend(raw, (uint8_t)(version << 4 & 0xf0 | meta.traffic_class >> 4 & 0x0f));
}

void pkt_c::generate_eth(
    vector<uint8_t> &raw,
    const meta_mac_t &meta,
    const gen_err_eth_t &err)
{
  uint16_t ethertype = meta.ethertype;
  mac_t dst = meta.dst;

  if (err == ERR_DST_MAC)
    dst.m[0]++;
  if (err == ERR_ETHERTYPE)
    ethertype++;
  prepend(raw, ethertype);
  prepend(raw, meta.src);
  prepend(raw, dst);
  if (err == ERR_EXTRA_BYTE)
    prepend(raw, (uint8_t)0xff);
  uint32_t fcs = gen_fcs(raw);
  if (err == ERR_PREAMBLE_BAD_BYTE)
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x56, 0xd5});
  else if (err == ERR_PREAMBLE_TOO_SHORT)
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5});
  else if (err == ERR_PREAMBLE_TOO_LONG)
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5});
  else if (err == ERR_PREAMBLE_SFD_SKIP)
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55});
  else if (err == ERR_PREAMBLE_SFD_BAD)
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0X55});
  else
    raw.insert(raw.begin(), {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xd5});
  if (err == ERR_FCS_SKIP)
    return;
  for (size_t i = 0; i < sizeof(uint32_t); i++)
    if (err == ERR_FCS_BAD_BYTE && i == 3)
      raw.push_back((uint8_t)(fcs >> 8 * i ^ 0xff) + 1);
    else
      raw.push_back((uint8_t)(fcs >> 8 * i ^ 0xff));
}

void pkt_c::append(vector<uint8_t> &raw, const uint8_t &dat)
{
  raw.insert(raw.end(), dat);
}

void pkt_c::append(vector<uint8_t> &raw, const uint16_t &dat)
{
  for (size_t i = 0; i < sizeof(uint16_t); i++)
    raw.insert(raw.end(), (uint8_t)((dat >> (sizeof(uint16_t) - i - 1) * 8) & 0xff));
}

void pkt_c::append(vector<uint8_t> &raw, const uint32_t &dat)
{
  for (size_t i = 0; i < sizeof(uint32_t); i++)
    raw.insert(raw.end(), (uint8_t)((dat >> (sizeof(uint32_t) - i - 1) * 8) & 0xff));
}

void pkt_c::append(vector<uint8_t> &raw, const mac_t &dat)
{
  for (size_t i = 0; i < sizeof(mac_t); i++)
    raw.insert(raw.end(), dat.m[i]);
}

void pkt_c::append(vector<uint8_t> &raw, const ip_t &dat)
{
  for (size_t i = 0; i < sizeof(ip_t); i++)
    raw.insert(raw.end(), dat.i[i]);
}
void pkt_c::prepend(vector<uint8_t> &raw, const uint8_t &dat)
{
  raw.insert(raw.begin(), dat);
}

void pkt_c::prepend(vector<uint8_t> &raw, const uint16_t &dat)
{
  for (size_t i = 0; i < sizeof(uint16_t); i++)
    raw.insert(raw.begin(), (uint8_t)((dat >> i * 8) & 0xff));
}

void pkt_c::prepend(vector<uint8_t> &raw, const uint32_t &dat)
{
  for (size_t i = 0; i < sizeof(uint32_t); i++)
    raw.insert(raw.begin(), (uint8_t)((dat >> i * 8) & 0xff));
}

void pkt_c::prepend(vector<uint8_t> &raw, const mac_t &dat)
{
  for (size_t i = 0; i < sizeof(mac_t); i++)
  {
    raw.insert(raw.begin(), dat.m[sizeof(mac_t) - i - 1]);
  }
}

void pkt_c::prepend(vector<uint8_t> &raw, const ip_t &dat)
{
  for (size_t i = 0; i < sizeof(ip_t); i++)
    raw.insert(raw.begin(), dat.i[sizeof(ip_t) - i - 1]);
}

uint32_t pkt_c::cks_ip(
    const ip_t &ip)
{
  uint32_t cks = 0;
  uint16_t cur = 0;
  for (size_t idx = 0; idx < sizeof(pkt_c::ip_t) / 2; idx++)
  {
    cur = ((ip.i[2 * idx] << 8) & 0xff00) | (ip.i[2 * idx + 1] & 0x00ff);
    cks = cks + cur;
  }
  return cks;
};
uint16_t pkt_c::calc_checksum(
    const vector<uint8_t> &raw,
    const uint8_t &proto,
    const ip_t &src,
    const ip_t &dst)
{
  uint32_t cks32 = 0;
  uint16_t cur = 0;

  cks32 = raw.size() + (uint32_t)proto + cks_ip(src) + cks_ip(dst);
  for (size_t idx = 0; idx < raw.size() / 2; idx++)
  {
    cur = ((raw[2 * idx] << 8) & 0xff00) | (raw[2 * idx + 1] & 0x00ff);
    cks32 = cks32 + cur;
  }
  if (raw.size() % 2)
    cks32 = cks32 + (raw[raw.size() - 1] << 8 & 0xff00);
  uint16_t cks_lo = cks32 & 0xffff;
  uint16_t cks_hi = cks32 >> 16;
  uint32_t cks_sum = cks_lo + cks_hi;
  return ~(cks_lo + cks_hi + ((cks_sum >> 16) & 0xffff));
}

void pkt_c::insert_checksum(
    vector<uint8_t> &raw,
    const uint8_t &proto,
    const uint16_t &cks)
{
  if (proto == ICMP)
  {
    raw[2] = (uint8_t)(cks >> 8);
    raw[3] = (uint8_t)(cks);
  }
  else if (proto == TCP)
  {
    raw[16] = (uint8_t)(cks >> 8);
    raw[17] = (uint8_t)(cks);
  }
  else if (proto == UDP)
  {
    raw[6] = (uint8_t)(cks >> 8);
    raw[7] = (uint8_t)(cks);
  }
}

bool pkt_c::is_solicited_multicast(
    const ip_t &ip,
    const ip_t &sol)
{
  return (sol.i[0] == 0xff &&
          sol.i[1] == 0x02 &&
          sol.i[2] == 0x00 &&
          sol.i[3] == 0x00 &&
          sol.i[4] == 0x00 &&
          sol.i[5] == 0x00 &&
          sol.i[6] == 0x00 &&
          sol.i[7] == 0x00 &&
          sol.i[8] == 0x00 &&
          sol.i[9] == 0x00 &&
          sol.i[10] == 0x00 &&
          sol.i[11] == 0x01 &&
          sol.i[12] == 0xff &&
          sol.i[13] == ip.i[13] &&
          sol.i[14] == ip.i[14] &&
          sol.i[15] == ip.i[15]);
}

bool pkt_c::is_solicited_multicast(
    const ip_t &ip,
    const mac_t &sol)
{
  return (sol.m[0] == 0x33 &&
          sol.m[1] == 0x33 &&
          sol.m[2] == 0xff &&
          sol.m[3] == ip.i[13] &&
          sol.m[4] == ip.i[14] &&
          sol.m[5] == ip.i[15]);
}

pkt_c::ip_t pkt_c::gen_lla(
    const pkt_c::mac_t &mac)
{
  pkt_c::ip_t ip;
  ip.i[0] = 0xfe;
  ip.i[1] = 0x80;
  ip.i[2] = 0x00;
  ip.i[3] = 0x00;
  ip.i[4] = 0x00;
  ip.i[5] = 0x00;
  ip.i[6] = 0x00;
  ip.i[7] = 0x00;
  ip.i[8] = (mac.m[0]) | (1UL << 1);
  ip.i[9] = mac.m[1] & 0xff;
  ip.i[10] = mac.m[2];
  ip.i[11] = 0xff;
  ip.i[12] = 0xfe;
  ip.i[13] = mac.m[3];
  ip.i[14] = mac.m[4];
  ip.i[15] = mac.m[5];
  return ip;
}

pkt_c::ip_t pkt_c::gen_ga(
    const pkt_c::ip_t &lla,
    const pkt_c::ip_t &pfx,
    const uint8_t &pfx_len)
{
  // pfx_len not used atm
  pkt_c::ip_t ip;
  ip.i[0] = pfx.i[0];
  ip.i[1] = pfx.i[1];
  ip.i[2] = pfx.i[2];
  ip.i[3] = pfx.i[3];
  ip.i[4] = pfx.i[4];
  ip.i[5] = pfx.i[5];
  ip.i[6] = pfx.i[6];
  ip.i[7] = pfx.i[7];
  ip.i[8] = lla.i[8];
  ip.i[9] = lla.i[9];
  ip.i[10] = lla.i[10];
  ip.i[11] = lla.i[11];
  ip.i[12] = lla.i[12];
  ip.i[13] = lla.i[13];
  ip.i[14] = lla.i[14];
  ip.i[15] = lla.i[15];
  return ip;
}

pkt_c::ip_t pkt_c::gen_ip_mcast(
    const pkt_c::ip_t &lla)
{
  pkt_c::ip_t ip;
  ip.i[0] = 0xff;
  ip.i[1] = 0x02;
  ip.i[2] = 0x00;
  ip.i[3] = 0x00;
  ip.i[4] = 0x00;
  ip.i[5] = 0x00;
  ip.i[6] = 0x00;
  ip.i[7] = 0x00;
  ip.i[8] = 0x00;
  ip.i[9] = 0x00;
  ip.i[10] = 0x00;
  ip.i[11] = 0x01;
  ip.i[12] = 0xff;
  ip.i[13] = lla.i[13];
  ip.i[14] = lla.i[14];
  ip.i[15] = lla.i[15];
  return ip;
}

pkt_c::mac_t pkt_c::gen_mac_mcast(
    const pkt_c::ip_t &ip)
{
  pkt_c::mac_t mac;
  mac.m[0] = 0x33;
  mac.m[1] = 0x33;
  mac.m[2] = 0xff;
  mac.m[3] = ip.i[13];
  mac.m[4] = ip.i[14];
  mac.m[5] = ip.i[15];
  return mac;
}
