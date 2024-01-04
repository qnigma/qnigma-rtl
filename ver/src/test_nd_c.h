#ifndef TEST_NEIGHBOR_DISCOVERY_C_H
#define TEST_NEIGHBOR_DISCOVERY_C_H

#include "model_ifc_c.h"
#include "pkt_c.h"
#include "phy_c.h"
#include "prm_c.h"
#include "err_c.h"

/* Description:
 * Performs Neighbor Discovery test
 * TB will generate ICMP Neighbor Discovery requests targeting DUT
 * The packets generated have various combinations of:
 *  - destination IP (IP long_int) - Link-local or multicast
 *  - target IP (ICMP long_int) - Link-local or multicast
 *  - target MAC - Actual MAC or multicast
 * DUT is expected to generate correct ICMP Neighbor Adverisement messages
 */

class test_nd_c : public pkt_c,
                  public err_c,
                  public prm_c
{
public:
    test_nd_c(
        Vtop *tb);

    ~test_nd_c();

    bool run(
        Vtop *tb,
        phy_c *phy);

private:
    err_nd_t err;
    unsigned timeout;
    pkt_c::pkt_t cur_pkt;

    enum
    {
        IDLE,
        send_norm_s,
        check_norm_s,
        send_mac_mcast_s,
        check_mac_mcast_s,
        send_dst_ip_mcast_s,
        check_dst_ip_mcast_s,
        send_tar_ip_mcast_s,
        check_tar_ip_mcast_s,
        send_tar_ip_glb_s,
        check_tar_ip_glb_s,
        done_s
    } state;

    /* Check NA reply from DUT */
    bool na_chk(
        Vtop *tb,
        const pkt_c::pkt_t &req,
        const pkt_c::pkt_t &rsp,
        err_nd_t &err);

    /* Generate ND request with configurable dst/tar IPs */
    pkt_c::pkt_t nd_gen(
        Vtop *tb,
        const pkt_c::mac_t &dst_mac, // Target IP (ICMP header)
        const pkt_c::ip_t &dst_ip,   // Destination IP (IP header)
        const pkt_c::ip_t &tar_ip    // Target IP (ICMP header)
    );
};

#endif
