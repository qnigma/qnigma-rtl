#include "test_rtr_c.h"

test_rtr_c::test_rtr_c(Vtop *tb) : prm_c(tb)
{
  rs_packets = 0;
  ra_delay_ctr = gen_reply_timer(tb);
  state = IDLE;
}

test_rtr_c::~test_rtr_c()
{
  err_c::display_result(err);
};

unsigned test_rtr_c::gen_reply_timer(
    Vtop *tb)
{
  return (rand() % unsigned(tb->top->wrap->PARAM_RTR_TIMEOUT_MS * tb->top->wrap->TICKS_PER_MS));
}

bool test_rtr_c::run(
    Vtop *tb,
    phy_c *phy)
{
  err = rtr_no_error;
  pkt_c::pkt_t pkt_tx;
  pkt_c::pkt_t pkt_rx;
  switch (state)
  {
  case (IDLE):
  {
    rs_timeout = tb->top->wrap->PARAM_RTR_TIMEOUT_MS * tb->top->wrap->TICKS_PER_MS * 1000;
    state = WAIT_RS;
    break;
  }
  case (WAIT_RS):
  {
    if (phy->recv_pkt(pkt_rx))
    {
      printf("RS from ");
      model_ifc_c::display_ip(pkt_rx.meta.ip.src);
      printf("\n");
      if (rs_rtr_chk(pkt_rx))
      {
        rs_packets++;
        rs_timeout = tb->top->wrap->PARAM_RTR_TIMEOUT_MS * tb->top->wrap->TICKS_PER_MS * 2;
      }
    }
    if (rs_packets == tb->top->wrap->PARAM_RTR_TRIES)
    {
      state = WAIT_RA;
    }
    if (!rs_timeout--)
    {
      err = rtr_err_rs_timeout;
      return true;
    }
    break;
  }
  case (WAIT_RA):
  {
    if (!ra_delay_ctr--)
      state = SEND_RA_MINIMAL;
    break;
  }
  ////////////////
  // No options //
  ////////////////
  case (SEND_RA_MINIMAL):
  {
    if (!phy->sending())
    {

      mtu.pres = false;
      dns.pres = false;
      pfx.pres = false;
      printf("Sending Router Advertiesement (no options)... ");
      pkt_tx = ra_rtr_gen(
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          mtu,
          pfx,
          dns);
      phy->send_pkt(pkt_tx);
      set_timeout = ROUTER_SOLICITATION_SETTLE_TIMEOUT;
      state = WAIT_RA_MINIMAL;
    }
    break;
  }
  case (WAIT_RA_MINIMAL):
  {
    if (!set_timeout--)
    {
      err = rtr_err_set_timeout;
      return true;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->rcv)
      state = CHECK_RA_MINIMAL;
    break;
  }
  case (CHECK_RA_MINIMAL):
  {
    err = check_opt(tb, false, false, false);
    state = SEND_RA_ALL_OPT;
    break;
  }
  /////////////////////////////////
  // All options (pfx, dns, mtu) //
  /////////////////////////////////
  case (SEND_RA_ALL_OPT):
  {
    if (!phy->sending())
    {
      mtu.pres = true;
      mtu.mtu = RA_MTU;
      dns.pres = true;
      dns.dns_ip = DNS_LIST;
      pfx.pres = true;
      pfx.pfx = PREFIX_IP;
      pfx.len = PREFIX_LENGTH;
      printf("Sending Router Advertiesement (all options)... ");
      pkt_tx = ra_rtr_gen(
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          mtu,
          pfx,
          dns);

      phy->send_pkt(pkt_tx);
      set_timeout = ROUTER_SOLICITATION_SETTLE_TIMEOUT;
      state = WAIT_RA_ALL_OPTS;
    }
    break;
  }
  case (WAIT_RA_ALL_OPTS):
  {
    if (!set_timeout--)
    {
      err = rtr_err_set_timeout;
      return true;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->rcv)
      state = CHECK_RA_ALL_OPT;
    break;
  }
  case (CHECK_RA_ALL_OPT):
  {
    err = check_opt(tb, true, true, true);
    state = SEND_RA_MTU_ONLY;
    break;
  }
  /////////////////////
  // MTU option only //
  /////////////////////
  case (SEND_RA_MTU_ONLY):
  {
    if (!phy->sending())
    {
      mtu.pres = true;
      dns.pres = false;
      pfx.pres = false;
      printf("Sending Router Advertiesement (MTU option only)... ");
      pkt_tx = ra_rtr_gen(
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          mtu,
          pfx,
          dns);
      phy->send_pkt(pkt_tx);
      set_timeout = ROUTER_SOLICITATION_SETTLE_TIMEOUT;
      state = WAIT_RA_MTU_ONLY;
    }
    break;
  }
  case (WAIT_RA_MTU_ONLY):
  {
    if (!set_timeout--)
    {
      err = rtr_err_set_timeout;
      return true;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->rcv)
      state = CHECK_RA_MTU_ONLY;
    break;
  }
  case (CHECK_RA_MTU_ONLY):
  {
    err = check_opt(tb, true, false, false);
    state = SEND_RA_PFX_ONLY;
    break;
  }
  ////////////////////////
  // Prefix option only //
  ////////////////////////
  case (SEND_RA_PFX_ONLY):
  {
    if (!phy->sending())
    {
      mtu.pres = false;
      dns.pres = false;
      pfx.pres = true;
      printf("Sending Router Advertiesement (Prefix option only)... ");
      pkt_tx = ra_rtr_gen(
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          mtu,
          pfx,
          dns);
      phy->send_pkt(pkt_tx);
      set_timeout = ROUTER_SOLICITATION_SETTLE_TIMEOUT;
      state = WAIT_RA_PFX_ONLY;
    }
    break;
  }
  case (WAIT_RA_PFX_ONLY):
  {
    if (!set_timeout--)
    {
      err = rtr_err_set_timeout;
      return true;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->rcv)
      state = CHECK_RA_PFX_ONLY;
    break;
  }
  case (CHECK_RA_PFX_ONLY):
  {
    err = check_opt(tb, false, true, false);
    state = SEND_TA_DNS_ONLY;
    break;
  }
  /////////////////////
  // DNS option only //
  /////////////////////
  case (SEND_TA_DNS_ONLY):
  {
    if (!phy->sending())
    {
      mtu.pres = false;
      pfx.pres = false;
      dns.pres = true;
      printf("Sending Router Advertiesement (RDNSS option only)... ");
      pkt_tx = ra_rtr_gen(
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          mtu,
          pfx,
          dns);
      phy->send_pkt(pkt_tx);
      set_timeout = ROUTER_SOLICITATION_SETTLE_TIMEOUT;
      state = WAIT_RA_DNS_ONLY;
    }
    break;
  }
  case (WAIT_RA_DNS_ONLY):
  {
    if (!set_timeout--)
    {
      err = rtr_err_set_timeout;
      return true;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->rcv)
      state = CHECK_RA_DNS_ONLY;
    break;
  }
  case (CHECK_RA_DNS_ONLY):
  {
    err = check_opt(tb, false, false, true);
    /////////////////
    // END OF TEST //
    /////////////////
    return true;
    break;
  }
  }
  return (err != rtr_no_error);
}

bool test_rtr_c::rs_rtr_chk(
    const pkt_t &pkt)
{
  return (pkt.meta.mac.ethertype == IPV6 &&
          pkt.meta.mac.dst == MAC_MULTICAST_ALL_ROUTERS &&
          pkt.meta.ip.proto == ICMP &&
          pkt.meta.ip.len == (ICMP_RS_HLEN + 8 * ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH) &&
          pkt.meta.icmp.type == ICMP_TYPE_ROUTER_SOLICITATION &&
          pkt.meta.icmp.code == 0 &&
          !pkt.meta.icmp.tar_pres &&
          !pkt.meta.icmp.opt.mtu.pres &&
          !pkt.meta.icmp.opt.pfx.pres &&
          !pkt.meta.icmp.opt.rdnss.pres &&
          pkt.meta.icmp.opt.src_lnka.pres &&
          !pkt.meta.icmp.opt.tar_lnka.pres);
}

pkt_c::pkt_t test_rtr_c::ra_rtr_gen(
    const mac_t &dst_mac,
    const ip_t &dst_ip,
    const ra_mtu_setting_t &mtu,
    const ra_pfx_setting_t &pfx,
    const ra_dns_setting_t &dns)
{
  pkt_t pkt;
  pkt.err_tx.eth = ERR_ETH_NONE;
  pkt.err_tx.ip = ERR_IP_NONE;
  pkt.err_tx.icmp = ERR_ICMP_NONE;
  pkt.err_tx.udp = ERR_UDP_NONE;
  pkt.err_tx.dns = ERR_DNS_NONE;
  pkt.err_tx.tcp = ERR_TCP_NONE;
  // Eth
  pkt.meta.mac.src = TB_MAC;
  pkt.meta.mac.dst = dst_mac;
  pkt.meta.mac.ethertype = IPV6;
  // IP
  pkt.meta.ip.src = TB_LA;
  pkt.meta.ip.dst = IP_MULTICAST_ALL_DEVICES;
  pkt.meta.ip.proto = ICMP;
  pkt.meta.ip.hops = 255;
  pkt.meta.ip.flow_label = 0xabcde;
  pkt.meta.ip.traffic_class = 0x35;
  // ICMP
  pkt.meta.icmp.type = ICMP_TYPE_ROUTER_ADVERTISEMENT;
  pkt.meta.icmp.code = 0xab;
  pkt.meta.icmp.tar_pres = false;
  pkt.meta.icmp.ra_flags = 0;
  pkt.meta.icmp.ra_router_lifetime = ROUTER_LIFETIME;
  pkt.meta.icmp.ra_reach_time = ROUTER_REACH_TIME;
  pkt.meta.icmp.ra_retrans_time = ROUTER_RETRANS_TIME;
  // MTU
  pkt.meta.icmp.opt.mtu.pres = mtu.pres;
  pkt.meta.icmp.opt.mtu.mtu = mtu.mtu;
  // Prefix
  pkt.meta.icmp.opt.pfx.pres = pfx.pres;
  pkt.meta.icmp.opt.pfx.len = pfx.len;
  pkt.meta.icmp.opt.pfx.flags = 0;
  pkt.meta.icmp.opt.pfx.plife = PREFIX_PREFFERED_LIFETIME;
  pkt.meta.icmp.opt.pfx.vlife = PREFIX_VALID_LIFETIME;
  pkt.meta.icmp.opt.pfx.ip = pfx.pfx;
  // RDNSS
  pkt.meta.icmp.opt.rdnss.pres = dns.pres;
  pkt.meta.icmp.opt.rdnss.life = RDNSS_LIFETIME;
  pkt.meta.icmp.opt.rdnss.dns_ip = dns.dns_ip;
  pkt.meta.icmp.opt.src_lnka.pres = false;
  pkt.meta.icmp.opt.tar_lnka.pres = false;
  return pkt;
}

err_c::err_rtr_t test_rtr_c::check_mtu_opt(
    Vtop *tb,
    const bool &pres)
{
  if (pres)
  {
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->mtu != RA_MTU)
      return rtr_err_mtu_mismatch;
  }
  return rtr_no_error;
}

err_c::err_rtr_t test_rtr_c::check_rdnss_opt(Vtop *tb, const bool &pres)
{
  if (pres)
  {
    if (!tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->dns_avl)
    {
      // printf("RDNSS option not detected by DUT\n");
      return rtr_err_no_rdnss_option;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->dns_life_s != RDNSS_LIFETIME)
      return rtr_err_rdnss_valid_lifetime_mismatch;
  }
  else if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->dns_avl)
    return rtr_err_unexpected_rdnss_option;
  return rtr_no_error;
}

err_c::err_rtr_t test_rtr_c::check_pfx_opt(Vtop *tb, const bool &pres)
{
  if (pres)
  {
    if (!tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->pfx_avl)
    {
      //  printf("Prefix Information option not detected by DUT\n");
      return rtr_err_no_prefix_information_option;
    }
    if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->pfx_life_s != PREFIX_VALID_LIFETIME)
      printf("Correct\n");
  }
  else if (tb->top->wrap->dut->core_inst->icmp_inst->rtr_inf_inst->pfx_avl)
    return rtr_err_no_prefix_information_option;
  return rtr_no_error;
}

err_c::err_rtr_t test_rtr_c::check_opt(
    Vtop *tb,
    const bool &mtu_pres,
    const bool &pfx_pres,
    const bool &dns_pres)
{
  err_rtr_t err;
  err = check_mtu_opt(tb, mtu_pres);
  if (err != rtr_no_error)
    return err;
  err = check_pfx_opt(tb, pfx_pres);
  if (err != rtr_no_error)
    return err;
  err = check_rdnss_opt(tb, dns_pres);
  if (err != rtr_no_error)
    return err;
  printf("Good\n");
  return rtr_no_error;
}
