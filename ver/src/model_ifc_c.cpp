#include "model_ifc_c.h"

model_ifc_c::model_ifc_c() {}

void model_ifc_c::display_mac(
    const pkt_c::mac_t &mac)
{
  printf("%02x:%02x:%02x:%02x:%02x:%02x",
         mac.m[0],
         mac.m[1],
         mac.m[2],
         mac.m[3],
         mac.m[4],
         mac.m[5]);
};

void model_ifc_c::display_ip(
    const pkt_c::ip_t &ip)
{
  bool zer = false;
  bool zer_prev = false;
  for (int i = 0; i < sizeof(pkt_c::ip_t); i = i + 2)
  {
    if (ip.i[i] == 0x00 && ip.i[i + 1] == 0x00)
    {
      if ((zer && !zer_prev) || i == 0)
        printf(":");
    }
    else
    {
      printf("%02x%02x", ip.i[i], ip.i[i + 1]);
      if (i != sizeof(pkt_c::ip_t) - 2)
        printf(":");
    }
    zer_prev = zer;
    zer = (ip.i[i] == 0x00 && ip.i[i + 1] == 0x00);
  }
};

pkt_c::ip_t model_ifc_c::get_ip(
    const WData raw[4])
{
  pkt_c::ip_t ip;
  for (size_t i = 0; i < sizeof(pkt_c::ip_t); i++)
  {
    ip.i[i] = raw[3 - (i >> 2)] >> ((sizeof(pkt_c::ip_t) - i - 1) * 8) & 0xff;
  }
  return ip;
};

pkt_c::ip_t model_ifc_c::get_ip(
    QData raw)
{
  pkt_c::ip_t ip;
  for (size_t i = 0; i < sizeof(QData); i++)
  {
    ip.i[i] = raw >> ((sizeof(QData) - i - 1) * 8) & 0xff;
  }
  for (size_t i = sizeof(QData); i < sizeof(pkt_c::ip_t); i++)
    ip.i[i] = 0;

  return ip;
};

pkt_c::mac_t model_ifc_c::get_mac(
    QData raw)
{
  pkt_c::mac_t mac;
  for (size_t i = 0; i < sizeof(pkt_c::mac_t); i++)
  {
    mac.m[i] = raw >> ((sizeof(pkt_c::mac_t) - i - 1) * 8) & 0xff;
  }
  return mac;
};

void model_ifc_c::set_ip(
    WData *raw,
    const pkt_c::ip_t ip)
{
  for (size_t i = 0; i < 4; i++)
  {
    raw[3 - i] =
        (ip.i[i * 4 + 3] << 0) & 0xff |
        (ip.i[i * 4 + 2] << 8) & 0xff00 |
        (ip.i[i * 4 + 1] << 16) & 0xff0000 |
        (ip.i[i * 4 + 0] << 24) & 0xff000000;
  }
}

// Set string in DUT
void model_ifc_c::set_str(
    WData *raw,
    const std::string str)
{
  unsigned raw_size = sizeof(str);
  raw_size = raw_size >> 2 + (raw_size & 0x3);  // actual number of 32bit regs
  for (size_t i = 0; i < sizeof(str) >> 2; i++) // initial 32-bit words registers as 0
    raw[i] = 0;
  for (size_t i = 0; i < str.size(); i++) // fill rest 32-bit words with string data
  {
    raw[i >> 2] = raw[i >> 2] | ((0xff & str[i]) << 8 * i);
  }
}

void model_ifc_c::set_port(
    SData &raw,
    uint16_t port)
{
  raw = port;
}
//////////////////////////
// DUT states extractor //
//////////////////////////
model_ifc_c::icmp_state_t model_ifc_c::get_state_icmp(
    Vtop *tb)
{
  icmp_state_t state;
  switch (tb->top->wrap->dut->core_inst->icmp_inst->state)
  {
  case (0x0):
    return icmp_gen_lla_s;
  case (0x1):
    return icmp_mld_send_s;
  case (0x2):
    return icmp_mld_sending_s;
  case (0x3):
    return icmp_mld_wait_s;
  case (0x4):
    return icmp_dad_send_s;
  case (0x5):
    return icmp_dad_sending_s;
  case (0x6):
    return icmp_dad_wait_s;
  case (0x7):
    return icmp_rs_wait_s;
  case (0x8):
    return icmp_rs_send_s;
  case (0x9):
    return icmp_rs_sending_s;
  case (0xA):
    return icmp_IDLE;
  case (0xB):
    return icmp_wait_tx_s;
  default:
    return icmp_unknown_s;
  }
}

model_ifc_c::tx_state_t model_ifc_c::get_state_tx(
    Vtop *tb)
{
  tx_state_t state;
  switch (tb->top->wrap->dut->tx_inst->state)
  {
  case 0:
    tx_IDLE;
    break;
  case 1:
    tx_pre_s;
    break;
  case 2:
    tx_hdr_eth_s;
    break;
  case 3:
    tx_hdr_ip_s;
    break;
  case 4:
    tx_ip_dst_s;
    break;
  case 5:
    tx_ip_src_s;
    break;
  case 6:
    tx_hdr_ip_pseudo_s;
    break;
  case 7:
    tx_icmp_hdr_s;
    break;
  case 8:
    tx_icmp_opt_s;
    break;
  case 9:
    tx_icmp_tar_s;
    break;
  case 10:
    tx_data_s;
    break;
  case 11:
    tx_crc_s;
    break;
  case 12:
    tx_ifg_s;
    break;
  };
  return state;
}

model_ifc_c::rx_state_t model_ifc_c::get_state_rx(
    Vtop *tb)
{
  rx_state_t state;
  switch (tb->top->wrap->dut->rx_inst->state)
  {
  case 0:
    rx_IDLE;
    break;
  case 1:
    rx_preamble_s;
    break;
  case 2:
    rx_eth_hdr_s;
    break;
  case 3:
    rx_ip_hdr_s;
    break;
  case 4:
    rx_ip_src_s;
    break;
  case 5:
    rx_ip_dst_s;
    break;
  case 6:
    rx_hdr_ip_ext_s;
    break;
  case 7:
    rx_icmp_hdr_s;
    break;
  case 8:
    rx_icmp_opt_s;
    break;
  case 9:
    rx_icmp_tar_s;
    break;
  case 10:
    rx_data_write_s;
    break;
  case 11:
    rx_data_read_s;
    break;
  case 12:
    rx_tcp_hdr_s;
    break;
  case 13:
    rx_udp_hdr_s;
    break;
  case 14:
    rx_hdr_udp_s;
    break;
  case 15:
    rx_drop_s;
    break;
  case 16:
    rx_payload_s;
    break;
  }
  return state;
}

//////////////////////////
// DUT meta exctractors //
//////////////////////////
pkt_c::meta_mac_t model_ifc_c::get_meta_mac_rx(
    Vtop *tb)
{
  pkt_c::meta_mac_t meta;
  // MAC meta

  meta.ethertype = tb->top->wrap->dut->rx_inst->meta_mac[0] & 0xffff;

  meta.src.m[0] = tb->top->wrap->dut->rx_inst->meta_mac[2] >> 8 & 0xff;
  meta.src.m[1] = tb->top->wrap->dut->rx_inst->meta_mac[2] >> 0 & 0xff;
  meta.src.m[2] = tb->top->wrap->dut->rx_inst->meta_mac[1] >> 24 & 0xff;
  meta.src.m[3] = tb->top->wrap->dut->rx_inst->meta_mac[1] >> 16 & 0xff;
  meta.src.m[4] = tb->top->wrap->dut->rx_inst->meta_mac[1] >> 8 & 0xff;
  meta.src.m[5] = tb->top->wrap->dut->rx_inst->meta_mac[1] >> 0 & 0xff;

  meta.dst.m[0] = tb->top->wrap->dut->rx_inst->meta_mac[3] >> 24 & 0xff;
  meta.dst.m[1] = tb->top->wrap->dut->rx_inst->meta_mac[3] >> 16 & 0xff;
  meta.dst.m[2] = tb->top->wrap->dut->rx_inst->meta_mac[3] >> 8 & 0xff;
  meta.dst.m[3] = tb->top->wrap->dut->rx_inst->meta_mac[3] >> 0 & 0xff;
  meta.dst.m[4] = tb->top->wrap->dut->rx_inst->meta_mac[2] >> 24 & 0xff;
  meta.dst.m[5] = tb->top->wrap->dut->rx_inst->meta_mac[2] >> 16 & 0xff;

  return meta;
};

pkt_c::meta_ip_t model_ifc_c::get_meta_ip_rx(
    Vtop *tb)
{
  pkt_c::meta_ip_t meta;
  meta.dst.i[0] = tb->top->wrap->dut->rx_inst->meta_ip[3] >> 24 & 0xff;
  meta.dst.i[1] = tb->top->wrap->dut->rx_inst->meta_ip[3] >> 16 & 0xff;
  meta.dst.i[2] = tb->top->wrap->dut->rx_inst->meta_ip[3] >> 8 & 0xff;
  meta.dst.i[3] = tb->top->wrap->dut->rx_inst->meta_ip[3] >> 0 & 0xff;
  meta.dst.i[4] = tb->top->wrap->dut->rx_inst->meta_ip[2] >> 24 & 0xff;
  meta.dst.i[5] = tb->top->wrap->dut->rx_inst->meta_ip[2] >> 16 & 0xff;
  meta.dst.i[6] = tb->top->wrap->dut->rx_inst->meta_ip[2] >> 8 & 0xff;
  meta.dst.i[7] = tb->top->wrap->dut->rx_inst->meta_ip[2] >> 0 & 0xff;
  meta.dst.i[8] = tb->top->wrap->dut->rx_inst->meta_ip[1] >> 24 & 0xff;
  meta.dst.i[9] = tb->top->wrap->dut->rx_inst->meta_ip[1] >> 16 & 0xff;
  meta.dst.i[10] = tb->top->wrap->dut->rx_inst->meta_ip[1] >> 8 & 0xff;
  meta.dst.i[11] = tb->top->wrap->dut->rx_inst->meta_ip[1] >> 0 & 0xff;
  meta.dst.i[12] = tb->top->wrap->dut->rx_inst->meta_ip[0] >> 24 & 0xff;
  meta.dst.i[13] = tb->top->wrap->dut->rx_inst->meta_ip[0] >> 16 & 0xff;
  meta.dst.i[14] = tb->top->wrap->dut->rx_inst->meta_ip[0] >> 8 & 0xff;
  meta.dst.i[15] = tb->top->wrap->dut->rx_inst->meta_ip[0] >> 0 & 0xff;

  meta.src.i[0] = tb->top->wrap->dut->rx_inst->meta_ip[7] >> 24 & 0xff;
  meta.src.i[1] = tb->top->wrap->dut->rx_inst->meta_ip[7] >> 16 & 0xff;
  meta.src.i[2] = tb->top->wrap->dut->rx_inst->meta_ip[7] >> 8 & 0xff;
  meta.src.i[3] = tb->top->wrap->dut->rx_inst->meta_ip[7] >> 0 & 0xff;
  meta.src.i[4] = tb->top->wrap->dut->rx_inst->meta_ip[6] >> 24 & 0xff;
  meta.src.i[5] = tb->top->wrap->dut->rx_inst->meta_ip[6] >> 16 & 0xff;
  meta.src.i[6] = tb->top->wrap->dut->rx_inst->meta_ip[6] >> 8 & 0xff;
  meta.src.i[7] = tb->top->wrap->dut->rx_inst->meta_ip[6] >> 0 & 0xff;
  meta.src.i[8] = tb->top->wrap->dut->rx_inst->meta_ip[5] >> 24 & 0xff;
  meta.src.i[9] = tb->top->wrap->dut->rx_inst->meta_ip[5] >> 16 & 0xff;
  meta.src.i[10] = tb->top->wrap->dut->rx_inst->meta_ip[5] >> 8 & 0xff;
  meta.src.i[11] = tb->top->wrap->dut->rx_inst->meta_ip[5] >> 0 & 0xff;
  meta.src.i[12] = tb->top->wrap->dut->rx_inst->meta_ip[4] >> 24 & 0xff;
  meta.src.i[13] = tb->top->wrap->dut->rx_inst->meta_ip[4] >> 16 & 0xff;
  meta.src.i[14] = tb->top->wrap->dut->rx_inst->meta_ip[4] >> 8 & 0xff;
  meta.src.i[15] = tb->top->wrap->dut->rx_inst->meta_ip[4] >> 0 & 0xff;

  meta.hops = tb->top->wrap->dut->rx_inst->meta_ip[8] >> 0 & 0xff;
  meta.traffic_class = tb->top->wrap->dut->rx_inst->meta_ip[8] >> 8 & 0xff;

  meta.flow_label = ((tb->top->wrap->dut->rx_inst->meta_ip[9] & 0x0f) << 16) | (tb->top->wrap->dut->rx_inst->meta_ip[8] >> 16 & 0xffff);

  meta.proto = tb->top->wrap->dut->rx_inst->meta_ip[9] >> 4 & 0xff;

  meta.len = (tb->top->wrap->dut->rx_inst->meta_ip[9] >> 12) & 0xffff;
  return meta;
};

pkt_c::meta_icmp_t model_ifc_c::get_meta_icmp_rx(
    Vtop *tb)
{

  pkt_c::meta_icmp_t meta;
  meta.type = tb->top->wrap->dut->rx_inst->meta_icmp[34] >> 8 & 0xff;
  meta.code = tb->top->wrap->dut->rx_inst->meta_icmp[34] >> 0 & 0xff;

  meta.echo_id = tb->top->wrap->dut->rx_inst->meta_icmp[33] >> 16 & 0xffff;
  meta.echo_seq = tb->top->wrap->dut->rx_inst->meta_icmp[33] >> 0 & 0xffff;
  meta.echo_len = tb->top->wrap->dut->rx_inst->meta_icmp[32] >> 16 & 0xffff;

  meta.ra_cur_hop_lim = tb->top->wrap->dut->rx_inst->meta_icmp[32] >> 8 & 0xff;
  meta.ra_flags = tb->top->wrap->dut->rx_inst->meta_icmp[32] >> 0 & 0xff;
  meta.ra_router_lifetime = tb->top->wrap->dut->rx_inst->meta_icmp[31] >> 16 & 0xffff;
  meta.ra_reach_time = (tb->top->wrap->dut->rx_inst->meta_icmp[31] >> 0 & 0xffff) | (tb->top->wrap->dut->rx_inst->meta_icmp[30] >> 16 & 0xffff);
  meta.ra_retrans_time = (tb->top->wrap->dut->rx_inst->meta_icmp[30] >> 0 & 0xffff) | (tb->top->wrap->dut->rx_inst->meta_icmp[29] >> 16 & 0xffff);

  meta.na_flags = (tb->top->wrap->dut->rx_inst->meta_icmp[29] >> 0 & 0xffff) | (tb->top->wrap->dut->rx_inst->meta_icmp[28] >> 16 & 0xffff);

  meta.tar_ip.i[0] = tb->top->wrap->dut->rx_inst->meta_icmp[28] >> 8 & 0xff;
  meta.tar_ip.i[1] = tb->top->wrap->dut->rx_inst->meta_icmp[28] >> 0 & 0xff;
  meta.tar_ip.i[2] = tb->top->wrap->dut->rx_inst->meta_icmp[27] >> 24 & 0xff;
  meta.tar_ip.i[3] = tb->top->wrap->dut->rx_inst->meta_icmp[27] >> 16 & 0xff;
  meta.tar_ip.i[4] = tb->top->wrap->dut->rx_inst->meta_icmp[27] >> 8 & 0xff;
  meta.tar_ip.i[5] = tb->top->wrap->dut->rx_inst->meta_icmp[27] >> 0 & 0xff;
  meta.tar_ip.i[6] = tb->top->wrap->dut->rx_inst->meta_icmp[26] >> 24 & 0xff;
  meta.tar_ip.i[7] = tb->top->wrap->dut->rx_inst->meta_icmp[26] >> 16 & 0xff;
  meta.tar_ip.i[8] = tb->top->wrap->dut->rx_inst->meta_icmp[26] >> 8 & 0xff;
  meta.tar_ip.i[9] = tb->top->wrap->dut->rx_inst->meta_icmp[26] >> 0 & 0xff;
  meta.tar_ip.i[10] = tb->top->wrap->dut->rx_inst->meta_icmp[25] >> 24 & 0xff;
  meta.tar_ip.i[11] = tb->top->wrap->dut->rx_inst->meta_icmp[25] >> 16 & 0xff;
  meta.tar_ip.i[12] = tb->top->wrap->dut->rx_inst->meta_icmp[25] >> 8 & 0xff;
  meta.tar_ip.i[13] = tb->top->wrap->dut->rx_inst->meta_icmp[25] >> 0 & 0xff;
  meta.tar_ip.i[14] = tb->top->wrap->dut->rx_inst->meta_icmp[24] >> 24 & 0xff;
  meta.tar_ip.i[15] = tb->top->wrap->dut->rx_inst->meta_icmp[24] >> 16 & 0xff;

  meta.opt.src_lnka.mac.m[0] = tb->top->wrap->dut->rx_inst->meta_icmp[24] >> 8 & 0xff;
  meta.opt.src_lnka.mac.m[1] = tb->top->wrap->dut->rx_inst->meta_icmp[24] >> 0 & 0xff;
  meta.opt.src_lnka.mac.m[2] = tb->top->wrap->dut->rx_inst->meta_icmp[23] >> 24 & 0xff;
  meta.opt.src_lnka.mac.m[3] = tb->top->wrap->dut->rx_inst->meta_icmp[23] >> 16 & 0xff;
  meta.opt.src_lnka.mac.m[4] = tb->top->wrap->dut->rx_inst->meta_icmp[23] >> 8 & 0xff;
  meta.opt.src_lnka.mac.m[5] = tb->top->wrap->dut->rx_inst->meta_icmp[23] >> 0 & 0xff;

  meta.opt.tar_lnka.mac.m[0] = tb->top->wrap->dut->rx_inst->meta_icmp[22] >> 8 & 0xff;
  meta.opt.tar_lnka.mac.m[1] = tb->top->wrap->dut->rx_inst->meta_icmp[22] >> 0 & 0xff;
  meta.opt.tar_lnka.mac.m[2] = tb->top->wrap->dut->rx_inst->meta_icmp[21] >> 24 & 0xff;
  meta.opt.tar_lnka.mac.m[3] = tb->top->wrap->dut->rx_inst->meta_icmp[21] >> 16 & 0xff;
  meta.opt.tar_lnka.mac.m[4] = tb->top->wrap->dut->rx_inst->meta_icmp[21] >> 8 & 0xff;
  meta.opt.tar_lnka.mac.m[5] = tb->top->wrap->dut->rx_inst->meta_icmp[21] >> 0 & 0xff;

  meta.opt.pfx.len = tb->top->wrap->dut->rx_inst->meta_icmp[20] >> 24 & 0xff;
  meta.opt.pfx.flags = tb->top->wrap->dut->rx_inst->meta_icmp[20] >> 16 & 0xff;
  meta.opt.pfx.plife = tb->top->wrap->dut->rx_inst->meta_icmp[20] >> 8 & 0xff;
  meta.opt.pfx.vlife = tb->top->wrap->dut->rx_inst->meta_icmp[20] >> 0 & 0xff;

  meta.opt.pfx.ip.i[0] = tb->top->wrap->dut->rx_inst->meta_icmp[19] >> 8 & 0xff;
  meta.opt.pfx.ip.i[1] = tb->top->wrap->dut->rx_inst->meta_icmp[19] >> 0 & 0xff;
  meta.opt.pfx.ip.i[2] = tb->top->wrap->dut->rx_inst->meta_icmp[19] >> 24 & 0xff;
  meta.opt.pfx.ip.i[3] = tb->top->wrap->dut->rx_inst->meta_icmp[19] >> 16 & 0xff;
  meta.opt.pfx.ip.i[4] = tb->top->wrap->dut->rx_inst->meta_icmp[18] >> 8 & 0xff;
  meta.opt.pfx.ip.i[5] = tb->top->wrap->dut->rx_inst->meta_icmp[18] >> 0 & 0xff;
  meta.opt.pfx.ip.i[6] = tb->top->wrap->dut->rx_inst->meta_icmp[18] >> 24 & 0xff;
  meta.opt.pfx.ip.i[7] = tb->top->wrap->dut->rx_inst->meta_icmp[18] >> 16 & 0xff;
  meta.opt.pfx.ip.i[8] = tb->top->wrap->dut->rx_inst->meta_icmp[17] >> 8 & 0xff;
  meta.opt.pfx.ip.i[9] = tb->top->wrap->dut->rx_inst->meta_icmp[17] >> 0 & 0xff;
  meta.opt.pfx.ip.i[10] = tb->top->wrap->dut->rx_inst->meta_icmp[17] >> 24 & 0xff;
  meta.opt.pfx.ip.i[11] = tb->top->wrap->dut->rx_inst->meta_icmp[17] >> 16 & 0xff;
  meta.opt.pfx.ip.i[12] = tb->top->wrap->dut->rx_inst->meta_icmp[16] >> 8 & 0xff;
  meta.opt.pfx.ip.i[13] = tb->top->wrap->dut->rx_inst->meta_icmp[16] >> 0 & 0xff;
  meta.opt.pfx.ip.i[14] = tb->top->wrap->dut->rx_inst->meta_icmp[16] >> 24 & 0xff;
  meta.opt.pfx.ip.i[15] = tb->top->wrap->dut->rx_inst->meta_icmp[16] >> 16 & 0xff;

  // meta.opt.mtu.mtu = =  tb->top->wrap->dut->rx_inst->meta_icmp[15];

  return meta;
};
/*
pkt_c::meta_t model_ifc_c::get_meta_tx(
    Vtop *tb)
{
  pkt_c::meta_t meta;
  // MAC meta
  meta.mac.ethertype = pkt_c::IPV6;
  for (size_t i = 0; i < sizeof(pkt_c::mac_t); i++)
  {
    meta.mac.src.m[i] = tb->top->wrap->dut->mac_tx->loc >> ((sizeof(pkt_c::mac_t) - i - 1) * 8) & 0xff;
    meta.mac.dst.m[i] = tb->top->wrap->dut->mac_tx->rem >> ((sizeof(pkt_c::mac_t) - i - 1) * 8) & 0xff;
  }
  // IP meta
  meta.traffic_class = tb->top->wrap->dut->ip_tx->pri;
  meta.flow_label = tb->top->wrap->dut->ip_tx->flo;
  meta.proto = tb->top->wrap->dut->ip_tx->pro;
  meta.hops = 255; // Hops are set to 255 by default
  for (size_t i = 0; i < sizeof(pkt_c::ip_t); i++)
  {
    meta.src.i[i] = tb->top->wrap->dut->ip_tx->loc[3 - (i >> 2)] >> ((sizeof(pkt_c::ip_t) - i - 1) * 8) & 0xff;
    meta.dst.i[i] = tb->top->wrap->dut->ip_tx->rem[3 - (i >> 2)] >> ((sizeof(pkt_c::ip_t) - i - 1) * 8) & 0xff;
  }
  // ICMP common header fields
  meta.type = tb->top->wrap->dut->icmp_tx->typ;
  meta.code = tb->top->wrap->dut->icmp_tx->cod;
  // RA only header fields
  meta.ra_cur_hop_lim = tb->top->wrap->dut->icmp_tx->rtr[2] >> 24 & 0xff;
  meta.ra_flags = tb->top->wrap->dut->icmp_tx->rtr[2] >> 16 & 0xff;
  meta.ra_router_lifetime = tb->top->wrap->dut->icmp_tx->rtr[2] & 0xffff;
  meta.ra_reach_time = tb->top->wrap->dut->icmp_tx->rtr[1];
  meta.ra_retrans_time = tb->top->wrap->dut->icmp_tx->rtr[0];
  // ICMP target IP field
  for (size_t i = 0; i < sizeof(pkt_c::ip_t); i++)
  {
    meta.tar_ip.i[i] = tb->top->wrap->dut->icmp_tx->tar[3 - (i >> 2)] >> ((sizeof(pkt_c::ip_t) - i - 1) * 8) & 0xff;
  }
  // ICMP echo only header fields
  meta.echo_id = tb->top->wrap->dut->icmp_tx->echo >> 16 & 0xffff;
  meta.echo_seq = tb->top->wrap->dut->icmp_tx->echo & 0xffff;
  // ICMP source link-layer option
  for (size_t i = 0; i < sizeof(pkt_c::mac_t); i++)
  {
    meta.opt.src_lnka.mac.m[i] = tb->top->wrap->dut->icmp_tx->opt_lnk_src >> ((sizeof(pkt_c::mac_t) - i - 1) * 8) & 0xff;
  }
  meta.opt.src_lnka.pres = tb->top->wrap->dut->icmp_tx->opt_lnk_src_val;
  // ICMP target link-layer option
  for (size_t i = 0; i < sizeof(pkt_c::mac_t); i++)
  {
    meta.opt.tar_lnka.mac.m[i] = tb->top->wrap->dut->icmp_tx->opt_lnk_tar >> ((sizeof(pkt_c::mac_t) - i - 1) * 8) & 0xff;
  }
  meta.opt.tar_lnka.pres = tb->top->wrap->dut->icmp_tx->opt_lnk_tar_val;
  // ICMP MTU option
  meta.opt.mtu.mtu = tb->top->wrap->dut->icmp_tx->opt_mtu;
  meta.opt.mtu.pres = tb->top->wrap->dut->icmp_tx->opt_mtu_val;
  // ICMP prefix information option
  for (size_t i = 0; i < sizeof(pkt_c::ip_t); i++)
  {
    meta.opt.pfx.ip.i[i] = tb->top->wrap->dut->icmp_tx->opt_pfx_inf[3 - (i >> 2)] >> ((sizeof(pkt_c::ip_t) - i - 1) * 8) & 0xff;
  }
  meta.opt.pfx.plife = tb->top->wrap->dut->icmp_tx->opt_pfx_inf[5];
  meta.opt.pfx.vlife = tb->top->wrap->dut->icmp_tx->opt_pfx_inf[6];
  meta.opt.pfx.flags = tb->top->wrap->dut->icmp_tx->opt_pfx_inf[7] & 0xff;
  meta.opt.pfx.len = tb->top->wrap->dut->icmp_tx->opt_pfx_inf[7] >> 8 & 0xff;
  meta.opt.pfx.pres = tb->top->wrap->dut->icmp_tx->opt_pfx_inf_val;
  // meta.opt.rdnss.dns              = tb->top->wrap->dut->rx_inst->meta_icmp->
  // meta.opt.rdnss.life             = tb->top->wrap->dut->rx_inst->meta_icmp->
  // meta.opt.rdnss.pres             = tb->top->wrap->dut->rx_inst->meta_icmp->
  bool sol;     // Message is solicited
  bool sol_mac; // MAC to send reply
  bool sol_ip;  // IP to send reply

  return meta;
};
*/
bool model_ifc_c::meta_compare(
    const pkt_c::meta_t &dut,
    const pkt_c::meta_t &tb,
    const char *dir)
{
  if (tb.mac.ethertype != dut.mac.ethertype)
  {
    printf(
        "\x1b[31m[chk]<- Error: Ethertypr mismatch in %s. Should be: %04x. Got: %04x \x1b[0m \n", dir,
        tb.mac.ethertype,
        dut.mac.ethertype);
    return false;
  }

  if (tb.mac.src != dut.mac.src)
  {
    printf("\x1b[31m[chk]<- Error: source MAC mismatch in %s. Sould be: ", dir);
    display_mac(tb.mac.src);
    printf(" Got: ");
    display_mac(dut.mac.src);
    printf("\x1b[0m \n");
    return false;
  };
  if (tb.mac.dst != dut.mac.dst)
  {
    printf("\x1b[31m[chk]<- Error: destination MAC mismatch in %s. Sould be: ", dir);
    display_mac(tb.mac.dst);
    printf(" Got: ");
    display_mac(dut.mac.dst);
    printf("\x1b[0m \n");
    return false;
  };
  if (tb.ip.traffic_class != dut.ip.traffic_class)
  {
    printf(
        "\x1b[31m[chk]<- Error: IP traffic class mismatch in %s \x1b[0m \n", dir);
    return false;
  }
  if (tb.ip.flow_label != dut.ip.flow_label)
  {
    printf(
        "\x1b[31m[chk]<- Error: IP flow label mismatch in %s \x1b[0m \n", dir);
    return false;
  }
  if (tb.ip.proto != dut.ip.proto)
  {
    printf(
        "\x1b[31m[chk]<- Error: IP protocol mismatch in %s. Sould be: %04x. Got: %04x \x1b[0m \n", dir,
        tb.ip.proto,
        dut.ip.proto);
    return false;
  }
  if (tb.ip.hops != dut.ip.hops)
  {
    printf(
        "\x1b[31m[chk]<- Error: IP hop limit mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
        tb.ip.hops,
        dut.ip.hops);
    return false;
  }
  if (tb.ip.src != dut.ip.src)
  {
    printf("\x1b[31m[chk]<- Error: source IP mismatch in %s. Sould be: ", dir);
    display_ip(tb.ip.src);
    printf(" Got: ");
    display_ip(dut.ip.src);
    printf("\x1b[0m \n");
    return false;
  };
  if (tb.ip.dst != dut.ip.dst)
  {
    printf("\x1b[31m[chk]<- Error: destination IP mismatch in %s. Sould be: ", dir);
    display_ip(tb.ip.dst);
    printf(" Got: ");
    display_ip(dut.ip.dst);
    printf("\x1b[0m \n");
    return false;
  };
  if (tb.icmp.type != dut.icmp.type)
  {
    printf(
        "\x1b[31m[chk]<- Error: ICMP type mismatch in %s. Sould be: %d, Got: %d \x1b[0m \n", dir,
        tb.icmp.type,
        dut.icmp.type);
    return false;
  };
  if (tb.icmp.code != dut.icmp.code)
  {
    printf(
        "\x1b[31m[chk]<- Error: ICMP code mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
        tb.icmp.code,
        dut.icmp.code);
    return false;
  }; // RA only header fields
  if (tb.icmp.type == pkt_c::ICMP_TYPE_ROUTER_ADVERTISEMENT)
  {
    if (tb.icmp.ra_cur_hop_lim != dut.icmp.ra_cur_hop_lim)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP Router advertisement Hop Limit mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_cur_hop_lim,
          dut.icmp.ra_cur_hop_lim);
      return false;
    };
    if (tb.icmp.ra_flags != dut.icmp.ra_flags)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP Router advertisement flags mismatch in %s. Sould be: %x. Got: %x \x1b[0m \n", dir,
          tb.icmp.ra_flags,
          dut.icmp.ra_flags);
      return false;
    };
    if (tb.icmp.ra_router_lifetime != dut.icmp.ra_router_lifetime)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP Router advertisement router lifetime mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_router_lifetime,
          dut.icmp.ra_router_lifetime);
      return false;
    };
    if (tb.icmp.ra_reach_time != dut.icmp.ra_reach_time)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP Router advertisement router reachable time mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_reach_time,
          dut.icmp.ra_reach_time);
      return false;
    };
    if (tb.icmp.ra_retrans_time != dut.icmp.ra_retrans_time)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP Router advertisement router retransmission time mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_retrans_time,
          dut.icmp.ra_retrans_time);
      return false;
    };
  }
  if (tb.icmp.type == pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION || dut.icmp.type == pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT)
  {
    if (tb.icmp.tar_ip != dut.icmp.tar_ip)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP target IP mismatch in %s. Sould be: %02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x. Got: %02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x:%02x%02x \x1b[0m \n", dir,
          tb.icmp.tar_ip.i[0],
          tb.icmp.tar_ip.i[1],
          tb.icmp.tar_ip.i[2],
          tb.icmp.tar_ip.i[3],
          tb.icmp.tar_ip.i[4],
          tb.icmp.tar_ip.i[5],
          tb.icmp.tar_ip.i[6],
          tb.icmp.tar_ip.i[7],
          tb.icmp.tar_ip.i[8],
          tb.icmp.tar_ip.i[9],
          tb.icmp.tar_ip.i[10],
          tb.icmp.tar_ip.i[11],
          tb.icmp.tar_ip.i[12],
          tb.icmp.tar_ip.i[13],
          tb.icmp.tar_ip.i[14],
          tb.icmp.tar_ip.i[15],
          dut.icmp.tar_ip.i[0],
          dut.icmp.tar_ip.i[1],
          dut.icmp.tar_ip.i[2],
          dut.icmp.tar_ip.i[3],
          dut.icmp.tar_ip.i[4],
          dut.icmp.tar_ip.i[5],
          dut.icmp.tar_ip.i[6],
          dut.icmp.tar_ip.i[7],
          dut.icmp.tar_ip.i[8],
          dut.icmp.tar_ip.i[9],
          dut.icmp.tar_ip.i[10],
          dut.icmp.tar_ip.i[11],
          dut.icmp.tar_ip.i[12],
          dut.icmp.tar_ip.i[13],
          dut.icmp.tar_ip.i[14],
          dut.icmp.tar_ip.i[15]);
      return false;
    }
  }
  if (tb.icmp.type == pkt_c::ICMP_TYPE_ECHO_REPLY || dut.icmp.type == pkt_c::ICMP_TYPE_ECHO_REQUEST)
  {
    if (tb.icmp.echo_id != dut.icmp.echo_id)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP echo ID time mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_retrans_time,
          dut.icmp.ra_retrans_time);
      return false;
    };
    if (tb.icmp.echo_seq != dut.icmp.echo_seq)
    {
      printf(
          "\x1b[31m[chk]<- Error: ICMP echo sequence router retransmission time mismatch in %s. Sould be: %d. Got: %d \x1b[0m \n", dir,
          tb.icmp.ra_retrans_time,
          dut.icmp.ra_retrans_time);
      return false;
    };
  }

  if (tb.icmp.opt.src_lnka.pres && !dut.icmp.opt.src_lnka.pres)
  {
    printf(
        "\x1b[31m[chk]<- Error: ICMP expecting Source link-layer option in %s, however it's not present \x1b[0m \n", dir);
    return false;
  };

  if (!tb.icmp.opt.src_lnka.pres && dut.icmp.opt.src_lnka.pres)
  {
    printf(
        "\x1b[31m[chk]<- Error: ICMP not expecting Source link-layer option in %s, however it's present \x1b[0m \n", dir);
    return false;
  };

  if (tb.icmp.opt.src_lnka.pres)
  {
    if (tb.icmp.opt.src_lnka.mac != dut.icmp.opt.src_lnka.mac)
    {

      printf("\x1b[31m[chk]<- Error: ICMP Source link-layer option MAC mismatch in %s. Sould be: ", dir);
      display_mac(tb.icmp.opt.src_lnka.mac);
      printf(" Got: ");
      display_mac(dut.icmp.opt.src_lnka.mac);
      printf("\x1b[0m \n");
      return false;
    };
  }
  if (tb.icmp.opt.tar_lnka.pres && !dut.icmp.opt.tar_lnka.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP expecting Target link-layer option in %s, however it's not present \x1b[0m \n", dir);
    return false;
  };

  if (!tb.icmp.opt.tar_lnka.pres && dut.icmp.opt.tar_lnka.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP not expecting Target link-layer option in %s, however it's present \x1b[0m \n", dir);
    return false;
  };

  if (tb.icmp.opt.tar_lnka.pres)
  {
    if (tb.icmp.opt.tar_lnka.mac != dut.icmp.opt.tar_lnka.mac)
    {
      printf("\x1b[31m[chk]<- Error: ICMP Target link-layer option MAC mismatch in %s. Sould be: ", dir);
      display_mac(tb.icmp.opt.tar_lnka.mac);
      printf(" Got: ");
      display_mac(dut.icmp.opt.tar_lnka.mac);
      printf("\x1b[0m \n");
      return false;
    }
  }

  if (tb.icmp.opt.mtu.pres && !dut.icmp.opt.mtu.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP expecting MTU option in %s, however it's not present \x1b[0m \n", dir);
    return false;
  };

  if (!tb.icmp.opt.mtu.pres && dut.icmp.opt.mtu.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP not expecting MTU option in %s, however it's present \x1b[0m \n", dir);
    return false;
  };

  if (tb.icmp.opt.mtu.pres)
  {
    if (tb.icmp.opt.mtu.mtu != dut.icmp.opt.mtu.mtu)
    {
      printf("\x1b[31m[chk]<- Error: ICMP MTU option mismatch in %s. Should be: %d. Got: %d \x1b[0m \n", dir,
             tb.icmp.opt.mtu.mtu,
             dut.icmp.opt.mtu.mtu);
      return false;
    }
  };

  if (tb.icmp.opt.pfx.pres && !dut.icmp.opt.pfx.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP expecting Prefix information option in %s, however it's not present \x1b[0m \n", dir);
    return false;
  };

  if (!tb.icmp.opt.pfx.pres && dut.icmp.opt.pfx.pres)
  {
    printf("\x1b[31m[chk]<- Error: ICMP not expecting Prefix information option in %s, however it's present \x1b[0m \n", dir);
    return false;
  };

  if (tb.icmp.opt.pfx.pres)
  {
    if (tb.icmp.opt.pfx.flags != dut.icmp.opt.pfx.flags)
    {
      printf("\x1b[31m[chk]<- Error: ICMP Prefix information option Flag field mismatch in %s. Should be: %x. Got: %x \x1b[0m \n", dir,
             tb.icmp.opt.pfx.flags,
             dut.icmp.opt.pfx.flags);
      return false;
    }
    if (tb.icmp.opt.pfx.len != dut.icmp.opt.pfx.len)
    {
      printf("\x1b[31m[chk]<- Error: ICMP Prefix information option Length field mismatch in %s. Should be: %d. Got: %d \x1b[0m \n", dir,
             tb.icmp.opt.pfx.len,
             dut.icmp.opt.pfx.len);
      return false;
    }
    if (tb.icmp.opt.pfx.vlife != dut.icmp.opt.pfx.vlife)
    {
      printf("\x1b[31m[chk]<- Error: ICMP Prefix information option Valid lifetime field mismatch in %s. Should be: %d. Got: %d \x1b[0m \n", dir,
             tb.icmp.opt.pfx.vlife,
             dut.icmp.opt.pfx.vlife);
      return false;
    }
    if (tb.icmp.opt.pfx.plife != dut.icmp.opt.pfx.plife)
    {
      printf("\x1b[31m[chk]<- Error: ICMP Prefix information option Preffered lifetime field mismatch in %s. Should be: %d. Got: %d \x1b[0m \n", dir,
             tb.icmp.opt.pfx.plife,
             dut.icmp.opt.pfx.plife);
      return false;
    }
  };
  return true;
};

void model_ifc_c::display_error_message(err_t &err)
{
  if (err == err_bad_src_mac)
  {
    printf("\x1b[31m Error: bad source MAC \x1b[0m \n");
    return;
  }
  else if (err == err_bad_dst_mac)
  {
    printf("\x1b[31m Error: bad destination MAC \x1b[0m \n");
    return;
  }
  else if (err == err_bad_ethertype)
  {
    printf("\x1b[31m Error: bad Ethertype \x1b[0m \n");
    return;
  }
  else if (err == err_bad_src_ip)
  {
    printf("\x1b[31m Error: bad source IP \x1b[0m \n");
    return;
  }
  else if (err == err_bad_dst_ip)
  {
    printf("\x1b[31m Error: bad destination IP \x1b[0m \n");
    return;
  }
  else if (err == err_bad_ip_proto)
  {
    printf("\x1b[31m Error: bad IP proto \x1b[0m \n");
    return;
  }
  else if (err == err_bad_icmp_target_ip)
  {
    printf("\x1b[31m Error: bad target IP \x1b[0m \n");
    return;
  }
  else if (err == err_bad_icmp_type)
  {
    printf("\x1b[31m Error: bad ICMP type \x1b[0m \n");
    return;
  }
  else if (err == err_bad_icmp_type)
  {
    printf("\x1b[31m Error: bad ICMP code \x1b[0m \n");
    return;
  }
}
////////////////////////////////
// High-level packet chks //
////////////////////////////////
model_ifc_c::err_t model_ifc_c::check_pkt_ns_dad(
    pkt_c::meta_t &meta,
    pkt_c::mac_t &mac)
{
  err_t err;
  if (meta.mac.src != mac)
    err = err_bad_src_mac;
  else if (meta.mac.dst != pkt_c::MAC_MULTICAST_ALL_DEVICES)
    err = err_bad_dst_mac;
  else if (meta.mac.ethertype != pkt_c::IPV6)
    err = err_bad_ethertype;
  else if (meta.ip.src != pkt_c::IP_UNSPECIFIED)
    err = err_bad_src_ip;
  else if (meta.ip.dst != pkt_c::gen_lla(mac))
    err = err_bad_dst_ip;
  else if (meta.icmp.tar_ip != pkt_c::gen_lla(mac))
    err = err_bad_icmp_target_ip;
  else if (meta.ip.proto != pkt_c::ICMP)
    err = err_bad_ip_proto;
  else if (meta.icmp.type != pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION)
    err = err_bad_icmp_type;
  else if (meta.icmp.code != 0)
    err = err_icmp_bad_code;
  else
    err = err_none;
  return err;
};

model_ifc_c::err_t model_ifc_c::check_pkt(
    const pkt_c::meta_t &meta,
    const uint8_t &proto,
    const uint8_t &typ,
    const pkt_c::ip_t &src_ip,
    const pkt_c::ip_t &dst_ip,
    const pkt_c::mac_t &src_mac,
    const pkt_c::mac_t &dst_mac)
{
  if (meta.mac.src != src_mac)
    return err_bad_src_mac;
  if (meta.mac.dst != dst_mac)
    return err_bad_dst_mac;
  if (meta.ip.src != src_ip)
    return err_bad_src_ip;
  if (meta.ip.dst != dst_ip)
    return err_bad_dst_ip;
  switch (proto)
  {
  case (pkt_c::ICMP):
  {
    if (meta.icmp.type != typ)
      return err_bad_icmp_type;
    switch (meta.icmp.type)
    {
    case (pkt_c::ICMP_TYPE_ROUTER_SOLICITATION):
    {

      break;
    }
    case (pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT):
    {
      break;
    }
    case (pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION):
    {
      if (!meta.icmp.tar_pres)
        return err_icmp_no_tar_ip;
      if (meta.icmp.tar_ip != dst_ip)
        return err_icmp_bad_tar;
      break;
    }
    }
    break;
  }
  }
  if (meta.icmp.type != pkt_c::ICMP_TYPE_ROUTER_SOLICITATION)

    if (meta.icmp.code != 0)
      return err_icmp_bad_code;
  return err_none;
};
