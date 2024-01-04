//  IPv6 router funcu
#ifndef RTR_TEST_C_H
#define RTR_TEST_C_H

#include "model_ifc_c.h"
#include "phy_c.h"
#include "err_c.h"
#include "prm_c.h"

class test_rtr_c : public pkt_c,
                   public err_c,
                   public prm_c

{

public:
    bool run(
        Vtop *tb,
        phy_c *phy);

    test_rtr_c(
        Vtop *tb);

    ~test_rtr_c(

    );

private:
    err_rtr_t err;
    ra_mtu_setting_t mtu;
    ra_pfx_setting_t pfx;
    ra_dns_setting_t dns;

    unsigned ra_delay_ctr;
    unsigned rs_packets;
    unsigned rs_timeout;
    unsigned set_timeout;

    enum
    {
        IDLE,
        WAIT_RS,
        WAIT_RA,
        SEND_RA_MINIMAL,
        WAIT_RA_MINIMAL,
        CHECK_RA_MINIMAL,
        SEND_RA_ALL_OPT,
        WAIT_RA_ALL_OPTS,
        CHECK_RA_ALL_OPT,
        SEND_RA_MTU_ONLY,
        WAIT_RA_MTU_ONLY,
        CHECK_RA_MTU_ONLY,
        SEND_RA_PFX_ONLY,
        WAIT_RA_PFX_ONLY,
        CHECK_RA_PFX_ONLY,
        SEND_TA_DNS_ONLY,
        WAIT_RA_DNS_ONLY,
        CHECK_RA_DNS_ONLY,
        RTR_CHECK,
        done_s
    } state;

    /*
     * Generate a random delay for  Router Advertiesment
     * after Router Solicitation received from DUT
     */
    unsigned gen_reply_timer(Vtop *tb);

    /*
     * Check Router Solicitation message from DUT
     * return true if it's good
     */
    bool rs_rtr_chk(
        const pkt_t &pkt);

    /*
     * Generate Router Advertiesment message for DUT
     * based on settings provided
     */
    pkt_t ra_rtr_gen(
        const mac_t &dst_mac,
        const ip_t &dst_ip,
        const ra_mtu_setting_t &mtu,
        const ra_pfx_setting_t &pfx,
        const ra_dns_setting_t &dns);

    /*
     * Check MTU option inside DUT
     * pres false => no option expected
     * pres true => option expected
     */
    err_rtr_t check_mtu_opt(Vtop *tb, const bool &pres);

    /*
     * Check RDNSS option inside DUT
     * pres false => no option expected
     * pres true => option expected
     */
    err_rtr_t check_rdnss_opt(Vtop *tb, const bool &pres);

    /*
     * Check Prefix information option inside DUT
     * pres false => no option expected
     * pres true => option expected
     */
    err_rtr_t check_pfx_opt(Vtop *tb, const bool &pres);

    err_rtr_t check_opt(
        Vtop *tb,
        const bool &mtu_pres,
        const bool &pfx_pres,
        const bool &dns_pres);
};

#endif
