#include "test_dad_mld_c.h"

test_dad_mld_c::test_dad_mld_c(Vtop *tb) : prm_c(tb)
{
  ns_packets = 0;
  mld_packets = 0;
  ns_packets_skip_count = gen_retries(tb);
  na_delay_ctr = gen_reply_timer(tb);
  dad_tries = DAD_FAIL_SIM_TIMES;
  state = IDLE;
}

test_dad_mld_c::~test_dad_mld_c()
{
  display_result(err);
}

unsigned test_dad_mld_c::gen_reply_timer(
    Vtop *tb)
{
  return (rand() % (tb->top->wrap->PARAM_DAD_TIMEOUT_MS * tb->top->wrap->TICKS_PER_MS));
}

unsigned test_dad_mld_c::gen_retries(
    Vtop *tb)
{
  return (rand() % (DAD_DUT_PACKETS - 1) + 1);
}

bool test_dad_mld_c::ns_mld_chk(
    const pkt_c::pkt_t &pkt,
    const pkt_c::mac_t &mac,
    const pkt_c::ip_t &ip,
    err_dad_mld_t &err)
{

  if (pkt.meta.mac.ethertype != pkt_c::IPV6)
    return false;

  if (pkt.meta.ip.proto != pkt_c::ICMP)
    return false;

  if (pkt.meta.icmp.type != pkt_c::ICMP_TYPE_MULTICAST_LISTENER_REPORT_V2)
    return false;

  err = dad_mld_no_error;

  if (pkt.meta.mac.src != mac)
    err = dad_mld_err_src_mac_mismatch;
  if (pkt.meta.mac.dst != pkt_c::MAC_MULTICAST_MLD)
    err = dad_mld_err_dst_mac_mismatch;
  if (pkt.meta.ip.src != ip)
    err = dad_mld_err_src_ip_mismatch;
  if (pkt.meta.ip.len != pkt_c::ICMP_MLD_HLEN)
    err = dad_mld_err_bad_ip_length;
  if (pkt.meta.icmp.code != 0)
    err = dad_mld_err_bad_icmp_code;
  if (pkt.meta.ip.dst != IP_MULTICAST_MLD)
    err = dad_mld_err_target_ip;
  if (pkt.meta.icmp.opt.mtu.pres)
    err = dad_mld_err_mtu_option_present;
  if (pkt.meta.icmp.opt.pfx.pres)
    err = dad_mld_err_pfx_option_present;
  if (pkt.meta.icmp.opt.rdnss.pres)
    err = dad_mld_err_rdnss_option_present;
  if (pkt.meta.icmp.opt.src_lnka.pres)
    err = dad_mld_err_src_lnka_option_present;
  if (pkt.meta.icmp.opt.tar_lnka.pres)
    err = dad_mld_err_tar_lnka_option_present;
  if (pkt.meta.icmp.mld.aux_dat_len != 0)
    err = dad_mld_err_aux_dat_len_not_zero;
  // if (pkt.meta.icmp.mld.mcast_addr != IP_MULTICAST_MLD)
  // {
  //   err = dad_mld_err_mld_addr_mismatch; // todo
  // }
  if (pkt.meta.icmp.mld.num_src != 0)
    err = dad_mld_err_mld_number_of_sources_not_zero;
  if (pkt.meta.icmp.mld.rec_typ != 3)
    err = dad_mld_err_mld_bad_rec_type;
  if (pkt.pld.size())
    err = dad_mld_err_pld_pres;
  return (err == dad_mld_no_error);
}

bool test_dad_mld_c::ns_dad_chk(
    const pkt_c::pkt_t &pkt,
    const pkt_c::mac_t &mac,
    err_dad_mld_t &err)
{
  if (pkt.meta.mac.ethertype != pkt_c::IPV6)
    return false;
  if (pkt.meta.ip.proto != pkt_c::ICMP)
    return false;
  if (pkt.meta.icmp.type != pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION)
    return false;
  err = dad_mld_no_error;
  if (pkt.meta.mac.src != mac)
    err = dad_mld_err_src_mac_mismatch;
  if (!is_solicited_multicast(pkt.meta.icmp.tar_ip, pkt.meta.mac.dst))
    err = dad_mld_err_dst_mac_mismatch;
  if (pkt.meta.ip.src != pkt_c::IP_UNSPECIFIED)
    err = dad_mld_err_src_ip_mismatch;
  if (pkt.meta.ip.len != pkt_c::ICMP_NEIGHBOR_HLEN)
    err = dad_mld_err_bad_ip_length;
  if (pkt.meta.icmp.code != 0)
    err = dad_mld_err_bad_icmp_code;
  if (!pkt.meta.icmp.tar_pres)
    err = dad_mld_err_target_ip_not_present;
  if (!is_solicited_multicast(pkt.meta.icmp.tar_ip, pkt.meta.ip.dst))
    err = dad_mld_err_target_ip;
  if (pkt.meta.icmp.opt.mtu.pres)
    err = dad_mld_err_mtu_option_present;
  if (pkt.meta.icmp.opt.pfx.pres)
    err = dad_mld_err_pfx_option_present;
  if (pkt.meta.icmp.opt.rdnss.pres)
    err = dad_mld_err_rdnss_option_present;
  if (pkt.meta.icmp.opt.src_lnka.pres)
    err = dad_mld_err_src_lnka_option_present;
  if (pkt.pld.size())
    err = dad_mld_err_pld_pres;
  return (err == dad_mld_no_error);
}

bool test_dad_mld_c::run(
    Vtop *tb,
    phy_c *phy)
{
  err = dad_mld_no_error;
  pkt_c::pkt_t pkt_tx;
  pkt_c::pkt_t pkt_rx;

  switch (state)
  {
  case (IDLE):
  {
    state = wait_ns_s;
    dad_timeout = DAD_TIMEOUT_TICKS;
    mld_timeout = MLD_TIMEOUT_TICKS;
    printf("Running Duplicate Address Detection test with %d collisions...\n", dad_tries);
    break;
  }
  case (wait_ns_s):
  {
    if (!dad_timeout--)
      err = dad_mld_err_timeout; // Did not receive ND packet in time
    if (phy->recv_pkt(pkt_rx))   // Packet received
    {
      if (ns_dad_chk(pkt_rx, model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR), err))
      {
        printf("NS for ");
        model_ifc_c::display_ip(pkt_rx.meta.icmp.tar_ip);
        printf("\n");
        dut_ip = pkt_rx.meta.icmp.tar_ip;
        dad_timeout = DAD_TIMEOUT_TICKS;
        ns_packets++;
      }
      if (dad_tries) // DAD collisions done
      {
        if (ns_packets == ns_packets_skip_count)
        {
          state = delay_na_s;
        }
        break;
      }
      else if (ns_packets == DAD_DUT_PACKETS)
        state = wait_mld_s;
    }
    return (err != dad_mld_no_error);
    break;
  }
  case (delay_na_s):
  {
    if (!na_delay_ctr--)
      state = send_na_s;
    break;
  }
  case (send_na_s):
  {
    if (!phy->sending())
    {
      na_delay_ctr = gen_reply_timer(tb);
      ns_packets_skip_count = gen_retries(tb);
      ns_packets = 0;
      pkt_tx = gen_pkt_ns_dad_mld(model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR), dut_ip);
      // val_tx = true;
      phy->send_pkt(pkt_tx);
      dad_tries--;
      state = wait_ns_s;
    }
    break;
  }
  case (wait_mld_s):
  {
    if (!mld_timeout--)
      err = dad_mld_err_timeout; // Did not receive MLD packet in time
    if (phy->recv_pkt(pkt_rx))   // Packet received
    {
      if (ns_mld_chk(pkt_rx, model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR), dut_ip, err))
      {
        printf("MLDv2 from ");
        model_ifc_c::display_ip(pkt_rx.meta.ip.src);
        printf("\n");
        mld_timeout = MLD_TIMEOUT_TICKS;
        mld_packets++;
      }
    }
    if (mld_packets == MLD_DUT_PACKETS)
    {
      state = wait_set_ip_s;
    }
    return (err != dad_mld_no_error);
    break;
  }
  case (wait_set_ip_s):
  {
    if (model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla) == dut_ip)
    {
      printf("IP set to ");
      model_ifc_c::display_ip(dut_ip);
      printf("\n");
      err = dad_mld_no_error;
      return true;
    }
    else if (!dad_timeout--)
    {
      err = dad_mld_err_failed_to_set_lla;
      return true;
    }
    break;
  }
  }
  return (err != dad_mld_no_error);
}

pkt_c::pkt_t test_dad_mld_c::gen_pkt_ns_dad_mld(
    const pkt_c::mac_t &dst_mac,
    const pkt_c::ip_t &dst_ip)
{
  pkt_c::pkt_t pkt;
  pkt.meta.mac.src = TB_MAC;
  pkt.meta.mac.dst = dst_mac;
  pkt.meta.mac.ethertype = pkt_c::IPV6;
  pkt.meta.ip.src = dst_ip;
  pkt.meta.ip.dst = pkt_c::IP_MULTICAST_ALL_DEVICES;
  pkt.meta.ip.proto = pkt_c::ICMP;
  pkt.meta.ip.hops = 255;
  pkt.meta.ip.flow_label = 0x12345;
  pkt.meta.ip.traffic_class = 0x35;
  pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT;
  pkt.meta.icmp.code = 0xab;
  pkt.meta.icmp.tar_ip = dst_ip;
  pkt.meta.icmp.opt.mtu.pres = false;
  pkt.meta.icmp.opt.pfx.pres = false;
  pkt.meta.icmp.opt.rdnss.pres = false;
  pkt.meta.icmp.opt.src_lnka.pres = false;
  pkt.meta.icmp.opt.tar_lnka.pres = false;
  return pkt;
}