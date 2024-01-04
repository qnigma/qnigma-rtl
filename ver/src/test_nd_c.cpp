#include "test_nd_c.h"

test_nd_c::test_nd_c(Vtop *tb) : prm_c(tb)
{
  state = IDLE;
}

test_nd_c::~test_nd_c()
{
  display_result(err);
}

bool test_nd_c::run(
    Vtop *tb,
    phy_c *phy)
{
  err = nd_no_error;
  pkt_c::pkt_t pkt_tx;
  pkt_c::pkt_t pkt_rx;
  switch (state)
  {
  case (IDLE):
  {
    printf("Running ICMP Neighbor Discovery test\n");
    state = send_norm_s;
    break;
  }
  case (send_norm_s):
  {
    if (!phy->sending())
    {
      printf("Sending normal ND... ");
      pkt_tx = nd_gen(
          tb,
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla));
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = check_norm_s;
      timeout = NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;
    }
    break;
  }
  case (check_norm_s):
  {
    if (!timeout--)
    {
      err = nd_err_timeout;
      return true;
    }
    if (phy->recv_pkt(pkt_rx))
      if (na_chk(tb,
                 cur_pkt,
                 pkt_rx,
                 err))
      {
        printf("NA received. Good\n");
        state = send_mac_mcast_s;
      }
    return (err != nd_no_error);
    break;
  }
  case (send_mac_mcast_s):
  {
    if (!phy->sending())
    {
      printf("Sending ND targeting multicast MAC... ");
      pkt_tx = nd_gen(
          tb,
          pkt_c::gen_mac_mcast(model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla)),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla));
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = check_mac_mcast_s;
      timeout = NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;
    }
    break;
  }
  case (check_mac_mcast_s):
  {
    if (!timeout--)
    {
      err = nd_err_timeout;
      return true;
    }
    if (phy->recv_pkt(pkt_rx))
      if (na_chk(tb,
                 cur_pkt,
                 pkt_rx,
                 err))
      {
        printf("NA received. Good\n");
        state = send_dst_ip_mcast_s;
      }
    return (err != nd_no_error);
    break;
  }
  case (send_dst_ip_mcast_s):
  {
    if (!phy->sending())
    {
      printf("Sending ND targeting multicast IP... ");
      pkt_tx = nd_gen(
          tb,
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          pkt_c::gen_ip_mcast(model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla)),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla));
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = check_dst_ip_mcast_s;
      timeout = NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;
    }
    break;
  }
  case (check_dst_ip_mcast_s):
  {
    if (!timeout--)
    {
      err = nd_err_timeout;
      return true;
    }
    if (phy->recv_pkt(pkt_rx))
      if (na_chk(tb,
                 cur_pkt,
                 pkt_rx,
                 err))
      {
        printf("NA received. Good\n");
        state = send_tar_ip_mcast_s;
      }
    return (err != nd_no_error);
    break;
  }
  case (send_tar_ip_mcast_s):
  {
    if (!phy->sending())
    {
      printf("Sending ND targeting multicast ICMP target IP... ");
      pkt_tx = nd_gen(
          tb,
          model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR),
          model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
          pkt_c::gen_ip_mcast(model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla)));
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = check_tar_ip_mcast_s;
      timeout = NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;
    }
    break;
  }
  case (check_tar_ip_mcast_s):
  {
    if (!timeout--)
    {
      err = nd_err_timeout;
      return true;
    }
    if (phy->recv_pkt(pkt_rx))
      if (na_chk(tb,
                 cur_pkt,
                 pkt_rx,
                 err))
      {
        printf("NA received. Good\n");
        state = send_tar_ip_glb_s;
      }
    return (err != nd_no_error);
    break;
  }
  /////
  case (send_tar_ip_glb_s):
  {
    if (!phy->sending())
    {
      printf("Sending ND targeting global ICMP target IP... ");
      pkt_tx = nd_gen(
          tb,
          model_ifc_c::get_mac(
              tb->top->wrap->dut->MAC_ADDR),
          pkt_c::gen_ip_mcast(model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla)),
          // model_ifc_c::get_ip(
          // tb->top->wrap->dut->core_inst->icmp_inst->lla),
          pkt_c::gen_ga(model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla),
                        PREFIX_IP,
                        PREFIX_LENGTH));
      cur_pkt = pkt_tx;
      phy->send_pkt(pkt_tx);
      state = check_tar_ip_glb_s;
      timeout = NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;
    }
    break;
  }

  // Send Neighbor Solicitation to DUT's global IP
  // *Assume RA with respective option has been provided to DUT
  case (check_tar_ip_glb_s):
  {
    if (!timeout--)
    {
      err = nd_err_timeout;
      return true;
    }
    if (phy->recv_pkt(pkt_rx))
      if (na_chk(tb,
                 cur_pkt,
                 pkt_rx,
                 err))
      {
        printf("NA received. Good\n");
        state = done_s;
      }
    return (err != nd_no_error);
    break;
  }
  case (done_s):
  {
    return true;
  }
  }
  return false;
}

bool test_nd_c::na_chk(
    Vtop *tb,
    const pkt_c::pkt_t &req, // What was the request
    const pkt_c::pkt_t &rsp, // What is the reply
    err_nd_t &err)
{
  if (rsp.meta.mac.ethertype == pkt_c::IPV6 &&
      rsp.meta.ip.proto == pkt_c::ICMP &&
      rsp.meta.icmp.type == pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT)
  {
    if (rsp.meta.mac.dst != req.meta.mac.src)
      err = nd_err_dst_mac_mismatch;
    if (rsp.meta.mac.src != model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR))
      err = nd_err_src_mac_mismatch;
    if (rsp.meta.ip.dst != req.meta.ip.src)
      err = nd_err_dst_ip_mismatch;
    if (rsp.meta.ip.src != model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla) &&
        rsp.meta.ip.src != model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->glb))
      err = nd_err_src_ip_mismatch;
    if (rsp.meta.ip.len != pkt_c::ICMP_NEIGHBOR_HLEN + pkt_c::ICMP_OPTION_SOURCE_LINK_LAYER_ADDRESS_LENGTH * 8)
      err = nd_err_bad_ip_length;
    if (rsp.meta.icmp.code != 0)
      err = nd_err_bad_icmp_code;
    if (!rsp.meta.icmp.tar_pres)
      err = nd_err_target_ip_not_present;
    if (rsp.meta.icmp.tar_ip != model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla) &&
        rsp.meta.icmp.tar_ip != model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->glb))
      err = nd_err_tar_ip_mismatch;
    if (rsp.meta.icmp.opt.mtu.pres)
      err = nd_err_mtu_option_present;
    if (rsp.meta.icmp.opt.pfx.pres)
      err = nd_err_pfx_option_present;
    if (rsp.meta.icmp.opt.rdnss.pres)
      err = nd_err_rdnss_option_present;
    if (rsp.meta.icmp.opt.src_lnka.pres)
      err = nd_err_src_lnka_option_present;
    if (rsp.meta.icmp.opt.tar_lnka.pres)
      err = nd_err_tar_lnka_option_present;
    return true;
  }
  return false;
}

/* Generate a Neigbour Discovery packet based on DUT current IP*/
pkt_c::pkt_t test_nd_c::nd_gen(
    Vtop *tb,
    const pkt_c::mac_t &dst_mac,
    const pkt_c::ip_t &dst_ip,
    const pkt_c::ip_t &tar_ip)
{
  pkt_c::pkt_t pkt;
  pkt.pld.clear();
  pkt.meta.mac.src = TB_MAC;
  pkt.meta.mac.dst = dst_mac;
  pkt.meta.mac.ethertype = pkt_c::IPV6;
  pkt.meta.ip.src = TB_LA;
  pkt.meta.ip.dst = dst_ip;
  pkt.meta.ip.proto = pkt_c::ICMP;
  pkt.meta.ip.hops = 255;
  pkt.meta.ip.flow_label = 0x12345;
  pkt.meta.ip.traffic_class = 0x00;
  pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION;
  pkt.meta.icmp.code = 0x00;
  pkt.meta.icmp.tar_ip = tar_ip;
  pkt.meta.icmp.opt.mtu.pres = false;
  pkt.meta.icmp.opt.pfx.pres = false;
  pkt.meta.icmp.opt.rdnss.pres = false;
  pkt.meta.icmp.opt.src_lnka.pres = false;
  pkt.meta.icmp.opt.tar_lnka.pres = false;
  return pkt;
}
