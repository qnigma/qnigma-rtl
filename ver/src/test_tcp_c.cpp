#include "test_tcp_c.h"

test_tcp_c::test_tcp_c(Vtop *tb) : prm_c(tb)
{
  rx_auto = true;    // Automatic receive control
  ka_ack_ena = true; // Automatic Keep-Alive Ack reply
  bytes_sent = 0;
  tb_to_dut_state = tb_to_dut_IDLE;
  rx_buf.clear();
  tx_pld.clear();
  tcb.loc_wnd = TCP_INIT_WND;
  tcp_state = tcp_idle;
  timeout = 0;
  timeout_ctr_enable = false;
  cur_tx_seg = 0;
  tx_check_vect.clear();
};

/* Advance TCP state machine
 * And parse/generate relevant packets
 * once connected, handle all TCP in/out packets
 * =============================================
 * This FSM is common for all TCP tests
 * However additional packets may be receved/transmitted
 * Depending on derived class implamentation
 */

void test_tcp_c::advance(
    Vtop *tb,
    phy_c *phy)
{
  tx_pld.clear();
  pkt_t pkt;
  // Neighbor Discovery
  if (proc_pkt(pkt_icmp_ns, phy, pkt))
  {
    if (!phy->sending())
      phy->send_pkt(gen_pkt(pkt_icmp_na, 0, tx_pld));
    return;
  }
  timeout = (timeout_ctr_enable) ? timeout + 1 : 0;

  pkt_t pkt_rx;

  switch (tcp_state)
  {
  case (tcp_idle):
  {
    timeout_ctr_enable = false;
    icmp_ra_sent = 0;
    dcn_fin_sent = false;
    break;
  }
  case (listen_s):
  {
    timeout_ctr_enable = false;
    if (!icmp_ra_sent) // Send RA once if acting as server
    {
      if (!phy->sending())
      {
        phy->send_pkt(gen_pkt(pkt_icmp_ra, 0, tx_pld));
        icmp_ra_sent = true;
      }
    }
    if (proc_pkt(pkt_con_syn, phy, pkt_rx)) // begin establishing connection
    {
      tcb.mode = tcp_cli;
      tcb.rem_mac = pkt.meta.mac.src;
      tcb.rem_ip = pkt.meta.ip.src;
      tcb.rem_port = pkt.meta.tcp.src;
      //  tcb.loc_seq = random();
      tcb.loc_ack = pkt.meta.tcp.seq + 1;
      tcb.rem_seq = pkt.meta.tcp.seq;
      tcb.rem_ack = pkt.meta.tcp.ack;
      tcb.rem_scale = (pkt.meta.tcp.opt.wnd_pres) ? 0x01 << pkt.meta.tcp.opt.wnd : 0x01;

      tcb.mode = tcp_srv;
      tcp_state = send_con_synack_s;
    }
    break;
  }
  case (send_ns_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
    {
      tcb.mode = tcp_cli;
      phy->send_pkt(gen_pkt(pkt_icmp_ns, 0, tx_pld));
      tcp_state = wait_na_s;
    }
    break;
  }
  case (wait_na_s):
  {
    if (proc_pkt(pkt_icmp_na, phy, pkt_rx))
    {
      tcb.rem_mac = pkt.meta.mac.src;
      tcb.rem_ip = pkt.meta.ip.src;
      tcp_state = send_con_syn_s;
    }
    break;
  }
  case (send_con_syn_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
    {
      tcb.mode = tcp_cli;
      phy->send_pkt(gen_pkt(pkt_con_syn, 0, tx_pld));
      tcp_state = wait_con_synack_s;
    }
    break;
  }
  case (send_con_synack_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
    {
      phy->send_pkt(gen_pkt(pkt_con_synack, 0, tx_pld));
      tcp_state = wait_con_ack_s;
    }
    break;
  }
  case (send_con_ack_s):
  {
    if (!phy->sending())
    {
      timeout_ctr_enable = true;
      phy->send_pkt(gen_pkt(pkt_con_ack, 0, tx_pld));
      tcp_state = connected_s;
      tcb.ini_seq = tcb.loc_seq;
    }
    break;
  }
  case (wait_con_synack_s):
  {
    timeout_ctr_enable = true;
    if (proc_pkt(pkt_con_synack, phy, pkt_rx))
    {
      tcb.rem_mac = pkt.meta.mac.src;
      tcb.rem_ip = pkt.meta.ip.src;
      tcb.rem_port = pkt.meta.tcp.src;
      tcb.loc_seq++;
      tcb.loc_ack = pkt_rx.meta.tcp.seq + 1;
      tcb.rem_seq = pkt_rx.meta.tcp.seq;
      tcb.rem_ack = pkt_rx.meta.tcp.ack;
      tcb.rem_scale = (pkt_rx.meta.tcp.opt.wnd_pres) ? 1 << pkt_rx.meta.tcp.opt.wnd : 1;
      tcp_state = send_con_ack_s;
    }
    break;
  }
  case (wait_con_ack_s):
  {
    if (proc_pkt(pkt_con_ack, phy, pkt_rx))
    {
      tcb.loc_seq++;
      tcb.loc_ack = pkt.meta.tcp.seq;
      tcb.rem_ack = pkt.meta.tcp.ack;
      tcp_state = connected_s;
      tcb.ini_seq = tcb.loc_seq;
    }
    break;
  }
  case (send_dcn_fin_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
    {
      dcn_fin_sent = true;
      phy->send_pkt(gen_pkt(pkt_dcn_fin, 0, tx_pld));
      tcp_state = wait_dcn_ack_s;
    }
    break;
  }
  case (send_dcn_finack_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
    {
      dcn_fin_sent = true;
      phy->send_pkt(gen_pkt(pkt_dcn_finack, 0, tx_pld));
      tcp_state = wait_dcn_ack_s;
    }
    break;
  }
  case (wait_dcn_ack_s):
  {
    timeout_ctr_enable = true;
    if (proc_pkt(pkt_dcn_ack, phy, pkt_rx))
    {
      tcb.loc_ack++;
      // pkt.meta.tcp.seq + 1;
      tcb.loc_seq++;
      tcp_state = (dcn_fin_sent) ? tcp_idle : send_dcn_finack_s;
    }
    break;
  }
  case (wait_dcn_fin_s):
  {
    timeout_ctr_enable = true;
    if (proc_pkt(pkt_dcn_finack, phy, pkt_rx) || proc_pkt(pkt_dcn_fin, phy, pkt_rx))
    {
      tcb.loc_ack++;
      tcp_state = send_dcn_ack_s;
    }
    break;
  }
  case (send_dcn_ack_s):
  {
    timeout_ctr_enable = true;
    if (!phy->sending())
      phy->send_pkt(gen_pkt(pkt_dcn_ack, 0, tx_pld));
    tcp_state = (dcn_fin_sent) ? tcp_idle : send_dcn_finack_s;
    break;
  }
  case (connected_s):
    if (tb->tcp_val_out)
    {
      tx_check_vect.push_back(tb->tcp_dat_out);
    }
    timeout_ctr_enable = false;
    // Process input payload
    process_in(phy);
    process_out(phy);
    if (proc_pkt(pkt_dcn_fin, phy, pkt_rx))
    {
      tcp_state = send_dcn_ack_s;
    }
    // Keepalive Ack received
    if (ka_ack_ena & proc_pkt(pkt_ka, phy, pkt_rx))
    {
      if (!phy->sending())
        phy->send_pkt(gen_pkt(pkt_ka_ack, 0, tx_pld));
    }
    // Ack received
    if (proc_pkt(pkt_ack, phy, pkt_rx))
    {
    }
    //
    if (proc_pkt(pkt_pld, phy, pkt_rx))
    {
    }
    break;
  }
}

/*
 * Generatess
 By adding packets directly to phy queue
 */

void test_tcp_c::add_to_queue(
    phy_c *phy,
    const vector<uint8_t> &pld,
    const vector<unsigned> &lost_blk,
    const uint32_t seq,
    const unsigned max_payload_length)
{
  unsigned idx = 0;
  tx_buf_t cur_pkt;

  // initialize current packet's boundaries
  unsigned pkt_start = 0;
  unsigned pkt_stop = max_payload_length;

  unsigned packets = pld.size() / max_payload_length + 1; // total packet needed
  uint32_t last_seq;

  // Slice packets according to max_payload_length
  for (unsigned idx = 0; idx < packets; idx++)
  {
    unsigned offset_start = idx * max_payload_length; // cu
    unsigned offset_end = (idx + 1) * max_payload_length;
    if (offset_end > pld.size())                                          // Is predicted last sequence number is out of payload size
      offset_end = pld.size();                                            // Prune the last offset to match payload size
    cur_pkt.valid = true;                                                 // Set packet valid
    cur_pkt.pld = {pld.begin() + offset_start, pld.begin() + offset_end}; // Extract payload slice
    cur_pkt.seq = seq + offset_start;                                     // Calculate packet's sequence number
    // Set lost packets as not 'valid'
    for (int i = 0; i < lost_blk.size(); i++)
      if (idx == lost_blk[i])
        cur_pkt.valid = false;
    tx_pkts.push_back(cur_pkt);
  }
}

// Gradually send packets in 'tx_pkt'
void test_tcp_c::process_out(
    phy_c *phy)
{
  uint32_t dif = tcb.loc_seq - tcb.rem_ack;
  // This event is when PHY is not sending anything
  // and number of packets is not equal (more)
  // then last tranmitted segment
  if (!phy->sending() && tx_pkts.size() != cur_tx_seg)
  {
    tx_buf_t seg = tx_pkts[cur_tx_seg++];
    if (seg.seq == tcb.loc_seq)
      tcb.loc_seq = tcb.loc_seq + seg.pld.size();
    pkt_t pkt = gen_pkt(pkt_pld, seg.seq, seg.pld);
    // Update to report up-to-date values...
    pkt.meta.tcp.ack = tcb.loc_ack;
    pkt.meta.tcp.opt.sack = tcb.loc_sack;
    if (seg.valid)
      phy->send_pkt(pkt);
  }
}

bool test_tcp_c::send_to_tb(
    const vector<uint8_t> &pld,
    Vtop *tb)
{
  switch (tb_to_dut_state)
  {
  case (tb_to_dut_IDLE):
  {
    tb_to_dut_state = tb_to_dut_tx_s;
    ctr_dut_to_tb = 0;
    break;
  }
  case (tb_to_dut_tx_s):
  {
    if (ctr_dut_to_tb == pld.size())
    {
      tb->tcp_val_in = false;
      tb_to_dut_state = tb_to_dut_IDLE;
      return true;
    }
    if (tb->tcp_cts_in)
    {
      tb->tcp_val_in = true;
      tb->tcp_dat_in = pld[ctr_dut_to_tb++];
    }
    else
      tb->tcp_val_in = false;
    break;
  }
  }
  return false;
}

void test_tcp_c::process_in(
    phy_c *phy)
{
  pkt_t pkt;
  if (rx_auto &&
      phy->recv_pkt(pkt) &&
      pkt.meta.tcp.seq == tcb.loc_ack &&
      (pkt.meta.tcp.flg == TCP_FLAG_PSH | TCP_FLAG_ACK && pkt.pld.size()))
  {
    tcb.loc_ack = pkt.meta.tcp.seq + pkt.pld.size();
    if (!phy->sending())
      phy->send_pkt(gen_pkt(pkt_ack, 0, tx_pld));
    if (rx_buf.size())
      rx_buf.insert(rx_buf.end(), pkt.pld.begin(), pkt.pld.end());
    else
      rx_buf = pkt.pld;
  }
}

// void test_tcp_c::process_out(
//     phy_c *phy)
//{
//   if (tx_queue.size())
//   {
//     pkt_entry_t entry;
//     entry = tx_queue.front();
//     tx_queue.pop();
//     pkt_tx.pld.clear();
//     pkt_tx = gen_pkt(pkt_pld, entry.seq, entry.pld);
//   }
// }
//

/*
 * Construct packet for a selected type
 * Can accept sequence number for packet
 * and corresponding payload
 */
pkt_c::pkt_t test_tcp_c::gen_pkt(
    tcp_pkt_t typ,
    const uint32_t &seq,
    const vector<uint8_t> &pld)
{
  pkt_c::pkt_t pkt;
  pkt.pld = pld;

  pkt.meta.mac.ethertype = IPV6;
  pkt.meta.mac.src = tcb.loc_mac;
  // Always target MAC recorded in TCB
  pkt.meta.mac.dst = tcb.rem_mac;
  pkt.meta.ip.src = tcb.loc_ip;
  // Always target IP recorded in TCB
  pkt.meta.ip.dst = tcb.rem_ip;
  pkt.meta.ip.flow_label = 0;
  pkt.meta.ip.hops = 255;
  pkt.meta.ip.proto = TCP;
  pkt.meta.ip.traffic_class = 0;
  // Assign default packet values
  pkt.meta.tcp.ptr = 0;
  pkt.meta.tcp.wnd = tcb.loc_wnd;
  pkt.meta.tcp.src = tcb.loc_port;
  pkt.meta.tcp.dst = tcb.rem_port;
  // seq and ack may be overwritten
  pkt.meta.tcp.seq = tcb.loc_seq;
  pkt.meta.tcp.ack = tcb.loc_ack;

  pkt.meta.tcp.opt.mss = TCP_MSS;
  pkt.meta.tcp.opt.mss_pres = false;

  pkt.meta.tcp.opt.wnd = TCP_WND_SCALE;
  pkt.meta.tcp.opt.mss_pres = false;
  pkt.meta.tcp.opt.sack_perm_pres = false;
  pkt.meta.tcp.opt.tim_pres = false;
  pkt.meta.tcp.opt.wnd_pres = false;
  pkt.meta.tcp.opt.sack_pres = false;

  switch (typ)
  {
  case (pkt_con_syn):
  {
    pkt.meta.tcp.opt.mss_pres = true;
    pkt.meta.tcp.opt.sack_perm_pres = true;
    pkt.meta.tcp.opt.tim_pres = false;
    pkt.meta.tcp.opt.wnd_pres = true;
    pkt.meta.tcp.opt.sack_pres = false;
    pkt.meta.tcp.flg = TCP_FLAG_SYN;
    break;
  }
  case (pkt_con_synack):
  {
    pkt.meta.tcp.opt.mss_pres = true;
    pkt.meta.tcp.opt.sack_perm_pres = true;
    pkt.meta.tcp.opt.tim_pres = false;
    pkt.meta.tcp.opt.wnd_pres = true;
    pkt.meta.tcp.opt.sack_pres = false;
    pkt.meta.tcp.flg = TCP_FLAG_SYN | TCP_FLAG_ACK;
    break;
  }
  case (pkt_con_ack):
  {
    pkt.meta.tcp.flg = TCP_FLAG_ACK;
    break;
  }
  case (pkt_dcn_fin):
  {
    pkt.meta.tcp.flg = TCP_FLAG_FIN;
    break;
  }
  case (pkt_dcn_finack):
  {
    pkt.meta.tcp.flg = TCP_FLAG_FIN | TCP_FLAG_ACK;
    break;
  }
  case (pkt_dcn_ack):
  {
    pkt.meta.tcp.flg = TCP_FLAG_ACK;
    pkt.meta.tcp.ack = tcb.loc_ack + 1;
    break;
  }
  case (pkt_ack):
  {
    pkt.meta.tcp.flg = TCP_FLAG_ACK;
    break;
  }
  case (pkt_ka):
  {
    pkt.meta.tcp.flg = TCP_FLAG_ACK;
    pkt.meta.tcp.seq = tcb.loc_seq - 1;
    break;
  }
  case (pkt_ka_ack):
  {
    pkt.meta.tcp.flg = TCP_FLAG_ACK;
    break;
  }
  case (pkt_pld):
  {
    pkt.meta.tcp.flg = TCP_FLAG_PSH | TCP_FLAG_ACK;
    pkt.meta.tcp.seq = seq;
    pkt.meta.tcp.ack = tcb.loc_ack;
    break;
  }
  case (pkt_icmp_ns):
  {
    pkt.meta.mac.src = tcb.loc_mac;
    pkt.meta.mac.dst = MAC_MULTICAST_ALL_DEVICES;
    pkt.meta.ip.src = tcb.loc_ip;
    pkt.meta.ip.dst = tcb.rem_ip;
    pkt.meta.ip.flow_label = 0;
    pkt.meta.ip.hops = 255;
    pkt.meta.ip.proto = ICMP;
    pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION;
    pkt.meta.icmp.code = 0;
    pkt.meta.icmp.tar_pres = true;
    pkt.meta.icmp.opt.mtu.pres = false;
    pkt.meta.icmp.opt.pfx.pres = false;
    pkt.meta.icmp.opt.rdnss.pres = false;
    pkt.meta.icmp.opt.tar_lnka.pres = false;
    pkt.meta.icmp.opt.src_lnka.pres = true;
    pkt.meta.icmp.opt.src_lnka.mac = tcb.loc_mac;
    pkt.meta.icmp.tar_ip = tcb.rem_ip;
    break;
  }
  case (pkt_icmp_na):
  {
    pkt.meta.mac.src = tcb.loc_mac;
    pkt.meta.mac.dst = tcb.rem_mac;
    pkt.meta.ip.src = tcb.loc_ip;
    pkt.meta.ip.dst = tcb.rem_ip;
    pkt.meta.ip.flow_label = 0;
    pkt.meta.ip.hops = 255;
    pkt.meta.ip.proto = ICMP;
    pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT;
    pkt.meta.icmp.code = 0;
    pkt.meta.icmp.tar_pres = true;
    pkt.meta.icmp.opt.mtu.pres = false;
    pkt.meta.icmp.opt.pfx.pres = false;
    pkt.meta.icmp.opt.rdnss.pres = false;
    pkt.meta.icmp.opt.tar_lnka.pres = true;
    pkt.meta.icmp.opt.src_lnka.pres = false;
    pkt.meta.icmp.opt.tar_lnka.mac = tcb.loc_mac;
    pkt.meta.icmp.tar_ip = tcb.loc_ip;
    break;
  }
  case (pkt_icmp_ra):
  {
    pkt.meta.mac.src = TB_MAC;
    pkt.meta.mac.dst = MAC_MULTICAST_ALL_DEVICES;
    pkt.meta.mac.ethertype = IPV6;
    // IP
    pkt.meta.ip.src = TB_LA;
    pkt.meta.ip.dst = IP_MULTICAST_ALL_DEVICES;
    pkt.meta.ip.proto = ICMP;
    pkt.meta.ip.hops = 255;
    pkt.meta.ip.flow_label = 0;
    pkt.meta.ip.traffic_class = 0;
    // ICMP
    pkt.meta.icmp.type = ICMP_TYPE_ROUTER_ADVERTISEMENT;
    pkt.meta.icmp.code = 0;
    pkt.meta.icmp.tar_pres = false;
    pkt.meta.icmp.ra_flags = 0;
    pkt.meta.icmp.ra_router_lifetime = ROUTER_LIFETIME;
    pkt.meta.icmp.ra_reach_time = ROUTER_REACH_TIME;
    pkt.meta.icmp.ra_retrans_time = ROUTER_RETRANS_TIME;
    // MTU
    pkt.meta.icmp.opt.mtu.pres = 1;
    pkt.meta.icmp.opt.mtu.mtu = RA_MTU;
    // Prefix
    pkt.meta.icmp.opt.pfx.pres = 1;
    pkt.meta.icmp.opt.pfx.len = PREFIX_LENGTH;
    pkt.meta.icmp.opt.pfx.flags = 0;
    pkt.meta.icmp.opt.pfx.plife = PREFIX_PREFFERED_LIFETIME;
    pkt.meta.icmp.opt.pfx.vlife = PREFIX_VALID_LIFETIME;
    pkt.meta.icmp.opt.pfx.ip = PREFIX_IP;
    // RDNSS
    pkt.meta.icmp.opt.rdnss.pres = 1;
    pkt.meta.icmp.opt.rdnss.life = RDNSS_LIFETIME;
    pkt.meta.icmp.opt.rdnss.dns_ip = DNS_LIST;
    pkt.meta.icmp.opt.src_lnka.pres = false;
    pkt.meta.icmp.opt.tar_lnka.pres = false;
    break;
  }
  case (pkt_dns_ans):
    pkt.meta.mac.src = TB_MAC;
    pkt.meta.mac.dst = DUT_MAC;
    pkt.meta.mac.ethertype = IPV6;
    pkt.meta.ip.src = dns_ip;
    pkt.meta.ip.dst = tcb.rem_ip;
    pkt.meta.ip.proto = UDP;
    pkt.meta.ip.hops = 255;
    pkt.meta.ip.flow_label = 0;
    pkt.meta.ip.traffic_class = 0;
    pkt.meta.udp.src = DNS_PORT;
    pkt.meta.udp.dst = 12345;
    pkt.meta.dns.flags = 0x8000;
    pkt.meta.dns.questions = 1;
    pkt.meta.dns.ans_rrs = 1;
    pkt.meta.dns.aut_rrs = 0;
    pkt.meta.dns.add_rrs = 0;
    pkt.meta.dns.id = meta_dns_qry.id;
    pkt.meta.dns.query_type = DNS_TYPE_AAAA;
    pkt.meta.dns.query_class = DNS_CLASS_IN;
    pkt.meta.dns.query_str = meta_dns_qry.query_str;
    pkt.meta.dns.answer_addr = DNS_ANS_IP;
    pkt.meta.dns.answer_type = DNS_TYPE_AAAA;
    pkt.meta.dns.answer_class = DNS_CLASS_IN;
    pkt.meta.dns.answer_ttl = DNS_DEFAULT_TTL;
    pkt.meta.dns.answer_data_len = sizeof(ip_t);
    break;
    //
  }
  return pkt;
}

// Return true if packet is of given type
// With respect to current TCP FSM state
bool test_tcp_c::proc_pkt(
    const tcp_pkt_t &typ,
    phy_c *phy,
    pkt_t &pkt)
{
  // If packet is not received at this tick...
  if (!phy->recv_pkt(pkt))
    return false;
  // If packet is not IPv6, reject it
  if (pkt.meta.mac.ethertype != IPV6)
    return false;
  // Otherwise, packet is being received...
  if (pkt.meta.mac.ethertype == IPV6 &&
      pkt.meta.ip.proto == TCP)
  {
    // Update remote window
    tcb.rem_wnd = pkt.meta.tcp.wnd * tcb.rem_scale;
    // Update remote sack
    tcb.rem_sack = pkt.meta.tcp.opt.sack;
    // Update remote ack
    tcb.rem_ack = pkt.meta.tcp.ack;
    // Update remote seq (only with new values)
    uint32_t rem_seq_dif = tcb.rem_seq - (pkt.meta.tcp.seq + pkt.pld.size());
    bool upd = (rem_seq_dif & 0x80000000) >> 31;
    if (upd && pkt.pld.size())
    {
      tcb.rem_seq = pkt.meta.tcp.seq + pkt.pld.size();
    }
  }
  switch (typ)
  {
  case (pkt_con_syn):
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_SYN))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_con_synack):
  {

    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_SYN | TCP_FLAG_ACK))
    {

      return true;
    }
    else
      return false;
  }
  case (pkt_con_ack):
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_ACK))
    {

      return true;
    }
    else
      return false;
  }
  case (pkt_dcn_fin):
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_FIN))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_dcn_finack): // FINACK-flagged disconnect packet received
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_FIN | TCP_FLAG_ACK))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_dcn_ack): // ACK-flagged disconnect packet received
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_ACK))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_ack): // Ack received
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg & TCP_FLAG_ACK)
    {
      tcb.rem_ack = pkt.meta.tcp.ack;
      return true;
    }
    else
      return false;
  }
  case (pkt_ka):
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.seq == tcb.rem_seq &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_ACK))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_ka_ack):
  {
    if (
        pkt.meta.ip.proto == TCP &&
        pkt.meta.mac.dst == tcb.loc_mac &&
        pkt.meta.mac.src == tcb.rem_mac &&
        pkt.meta.ip.dst == tcb.loc_ip &&
        pkt.meta.ip.src == tcb.rem_ip &&
        pkt.meta.tcp.dst == tcb.loc_port &&
        pkt.meta.tcp.src == tcb.rem_port &&
        pkt.meta.tcp.flg == (TCP_FLAG_ACK))
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_icmp_ns): // todo: filter
  {
    if (
        pkt.meta.ip.proto == ICMP &&
        pkt.meta.icmp.type == pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION)
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_icmp_na): // todo: filter
  {
    if (
        pkt.meta.ip.proto == ICMP &&
        pkt.meta.icmp.type == pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT)
    {
      return true;
    }
    else
      return false;
  }
  case (pkt_dns_qry): // todo: filter
  {
    if (
        pkt.meta.mac.src == DUT_MAC &&
        pkt.meta.mac.dst == TB_MAC &&
        pkt.meta.ip.proto == UDP &&
        pkt.meta.udp.dst == DNS_PORT)
    {
      meta_dns_qry = pkt.meta.dns;
      dns_ip = pkt.meta.ip.dst;
      return true;
    }
    else
      return false;
  }
  default:
    return false;
  }
}

bool test_tcp_c::connect_active(
    Vtop *tb)
{
  tb->tcp_connect_name = false;
  tb->tcp_connect_addr = false;
  tb->tcp_listen = true;
  if (tcp_state == tcp_idle)
  {
    printf("Connecting to DUT... ");
    tcp_state = send_ns_s;
    init_tcb(
        model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
        TB_LA,
        tb->top->wrap->dut->tcp_con_port);
    init_dut(tb);
  }
  bool connected = (tb->tcp_status_connected & tcp_state == connected_s);
  if (connected)
    printf("Connected\n");
  return connected;
}

bool test_tcp_c::connect_passive(
    Vtop *tb,
    const bool &by_name,
    const std::string &hostname)
{
  if (tcp_state == tcp_idle)
  {
    printf("Connecting to TB ");
    tb->tcp_listen = false;
    tb->tcp_connect_name = by_name;
    tb->tcp_connect_addr = !by_name;
    if (by_name)
    {
      printf("by hostname... (%s) ", hostname.c_str());
      model_ifc_c::set_str(tb->tcp_hostname_str, hostname);
      tb->tcp_hostname_len = 16;
    }
    else
      printf("by IP address...");
    tcp_state = listen_s;
    init_tcb(
        model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
        (by_name) ? DNS_ANS_IP : TB_LA,
        tb->top->wrap->dut->tcp_con_port);
    init_dut(tb);
  }
  bool connected = (tb->tcp_status_connected & tcp_state == connected_s);
  if (connected)
    printf("Connected\n");
  return connected;
}

bool test_tcp_c::disconnect_passive(
    Vtop *tb)
{
  bool disconnected = (tb->tcp_status_idle || tb->tcp_status_listening) && tcp_state == tcp_idle;
  if (tcp_state == connected_s)
  {
    printf("Disconnecting from DUT... ");
    tcp_state = send_dcn_fin_s;
  }
  if (disconnected)
    printf("Disconnected\n");
  return (disconnected);
}

bool test_tcp_c::disconnect_active(
    Vtop *tb)
{
  bool disconnected = (tb->tcp_status_idle || tb->tcp_status_listening) && tcp_state == tcp_idle;
  tb->tcp_listen = false;
  tb->tcp_connect_name = false;
  tb->tcp_connect_addr = false;
  tb->tcp_disconnect = !disconnected;
  if (!tb->tcp_disconnect)
  {
    printf("Disconnecting from TB... ");
  }
  if (disconnected)
    printf("Disconnected\n");
  return (disconnected);
}

pkt_c::mac_t mac;
pkt_c::ip_t ip;
uint16_t port;

void test_tcp_c::init_tcb(
    const ip_t &rem_ip,
    const ip_t &loc_ip,
    const uint16_t &port)
{
  tcb.loc_mac = TB_MAC;
  tcb.loc_ip = loc_ip;
  tcb.loc_port = rand() & 0xffff;
  tcb.rem_ip = rem_ip;
  tcb.rem_port = TB_PORT;
  tcb.loc_seq = random();
  tcb.loc_ack = 0;
  tcb.rem_seq = 0;
  tcb.rem_ack = 0;
  tcb.rem_mss = 0;
  tcb.rem_mss_pres = false;
  tcb.rem_wnd = 0;
}

void test_tcp_c::init_dut(
    Vtop *tb)
{
  tb->tcp_loc_port = tcb.rem_port;
  tb->tcp_rem_port = tcb.loc_port;
  model_ifc_c::set_ip(tb->tcp_rem_ip, tcb.loc_ip);
}