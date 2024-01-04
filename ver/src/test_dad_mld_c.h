#ifndef TEST_DAD_C_H
#define TEST_DAD_C_H

#include "model_ifc_c.h"
#include "pkt_c.h"
#include "phy_c.h"
#include "err_c.h"
#include "prm_c.h"
// #include <functional>

/*
 * Description:
 * Performs Duplicate Address Detection test
 * DUT should attempt do detemine if nodes with same IP
 * are present on the network by sending NS packets
 * TB will reply with NA to simuate collision
 * Parameters:
 * 1. dad_mld_fail_sim_times - number of collisions
 * 2. dad_mld_timeout_ticks - amount of ticks DUT has to send a NS
 */

class test_dad_mld_c : public pkt_c,
                       public err_c,
                       public prm_c
{
public:
    unsigned ns_packets;
    unsigned mld_packets;
    unsigned ns_packets_skip_count;
    unsigned na_delay_ctr;

    int nd_reply_tries; // Number of received ND packets till a reply is generated (random for each try)
    int dad_tries;      // Total number of DAD tries left
    unsigned mld_timeout;
    unsigned dad_timeout;

    enum
    {
        IDLE,
        wait_mld_s,
        wait_ns_s,
        delay_na_s,
        wait_set_ip_s,
        send_bad_na_s,
        send_na_s,
        done_s
    } state;

    err_dad_mld_t err;
    ip_t dut_ip;

    test_dad_mld_c(Vtop *tb);

    ~test_dad_mld_c();

    unsigned gen_reply_timer(
        Vtop *tb);

    unsigned gen_retries(
        Vtop *tb);

    bool run(
        Vtop *tb,
        phy_c *phy);

    bool ns_mld_chk(
        const pkt_c::pkt_t &pkt,
        const pkt_c::mac_t &mac,
        const pkt_c::ip_t &ip,
        err_dad_mld_t &err);

    bool ns_dad_chk(
        const pkt_c::pkt_t &pkt,
        const pkt_c::mac_t &mac,
        err_dad_mld_t &err);

    pkt_c::pkt_t gen_pkt_ns_dad_mld(
        const pkt_c::mac_t &dst_mac,
        const pkt_c::ip_t &dst_ip);
};

#endif
