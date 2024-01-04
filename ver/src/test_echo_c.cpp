#include "test_echo_c.h"

test_echo_c::test_echo_c(Vtop *tb) : prm_c(tb)
{
  packets_left = ECHO_TRIES;
  timer = 0;
  state = IDLE;
};

test_echo_c::~test_echo_c()
{
  display_result(err);
}

bool test_echo_c::run(
    Vtop *tb,
    phy_c *phy)
{
  err = echo_no_error;
  pkt_c::pkt_t pkt_tx;
  pkt_c::pkt_t pkt_rx;
  switch (state)
  {
  case (IDLE):
  {
    printf("Running ICMP Echo test with %d tries...\n", ECHO_TRIES);
    state = send_echo_request_s;
    break;
  }
  case (send_echo_request_s):
  {
    if (!phy->sending())
    {
      pkt_tx = echo_gen(tb);
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = wait_echo_reply_s;
      timeout = ECHO_TIMEOUT_TICKS;
    }
    break;
  }
  case (wait_echo_reply_s):
  {
    if (!timeout--)
      err = echo_err_timeout;
    if (phy->recv_pkt(pkt_rx))
      if (echo_chk(cur_pkt, pkt_rx, err))
      {
        state = (packets_left == 0) ? echo_check_s : send_echo_request_s;
        packets_left--;
      }
    return (err != echo_no_error);
    break;
  }
  case (echo_check_s):
  {
    printf("Echo replies good\n");
    return true;
    break;
  }
  }
  return false;
}

bool test_echo_c::echo_chk(
    const pkt_c::pkt_t &req,
    const pkt_c::pkt_t &rsp,
    err_echo_t &err)
{
  if (rsp.meta.mac.ethertype == pkt_c::IPV6 &&
      rsp.meta.ip.proto == pkt_c::ICMP &&
      rsp.meta.icmp.type == pkt_c::ICMP_TYPE_ECHO_REPLY)
  {
    if (rsp.meta.mac.dst != req.meta.mac.src)
      err = echo_err_dst_mac_mismatch;
    if (rsp.meta.mac.src != req.meta.mac.dst)
      err = echo_err_src_mac_mismatch;
    if (rsp.meta.ip.dst != req.meta.ip.src)
      err = echo_err_dst_ip_mismatch;
    if (rsp.meta.ip.src != req.meta.ip.dst)
      err = echo_err_src_ip_mismatch;
    if (rsp.meta.ip.len != (req.pld.size() + pkt_c::ICMP_ECHO_HLEN))
      err = echo_err_bad_ip_length;
    if (rsp.meta.icmp.code != 0)
      err = echo_err_bad_icmp_code;
    if (rsp.meta.icmp.tar_pres)
      err = echo_err_target_ip_present;
    if (rsp.meta.icmp.opt.mtu.pres)
      err = echo_err_mtu_option_present;
    if (rsp.meta.icmp.opt.pfx.pres)
      err = echo_err_pfx_option_present;
    if (rsp.meta.icmp.opt.rdnss.pres)
      err = echo_err_rdnss_option_present;
    if (rsp.meta.icmp.opt.src_lnka.pres)
      err = echo_err_src_lnka_option_present;
    if (rsp.meta.icmp.opt.tar_lnka.pres)
      err = echo_err_tar_lnka_option_present;
    if (req.pld != rsp.pld)
      err = echo_err_pld_mismatch;
    return true;
  }
  return false;
}

pkt_c::pkt_t test_echo_c::echo_gen(
    Vtop *tb)
{
  pkt_c::pkt_t pkt;
  pkt.pld.clear();
  pkt.meta.mac.src = TB_MAC;
  pkt.meta.mac.dst = model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR);
  pkt.meta.mac.ethertype = pkt_c::IPV6;
  pkt.meta.ip.src = TB_LA;
  pkt.meta.ip.dst = model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla);
  pkt.meta.ip.proto = pkt_c::ICMP;
  pkt.meta.ip.hops = 255;
  pkt.meta.ip.flow_label = 0x12345;
  pkt.meta.ip.traffic_class = 0x00;
  pkt.meta.icmp.type = pkt_c::ICMP_TYPE_ECHO_REQUEST;
  pkt.meta.icmp.code = 0x00;
  pkt.meta.icmp.opt.mtu.pres = false;
  pkt.meta.icmp.opt.pfx.pres = false;
  pkt.meta.icmp.opt.rdnss.pres = false;
  pkt.meta.icmp.opt.src_lnka.pres = false;
  pkt.meta.icmp.opt.tar_lnka.pres = false;
  size_t len = rand() % (ECHO_MAX_DATA_LEN - ECHO_MIN_DATA_LEN) + ECHO_MIN_DATA_LEN;
  for (int i = 0; i < len; i++)
    pkt.pld.push_back(rand() % 255);

  return pkt;
}
