#ifndef TEST_ECHO_C_H
#define TEST_ECHO_C_H

#include "model_ifc_c.h"
#include "pkt_c.h"
#include "phy_c.h"
#include "prm_c.h"
#include "err_c.h"

/* Description:
 * Performs ICMP echo reply test
 * TB will generate ICMP Echo requests targeting DUT
 * containing random payload of random length
 * DUT should generate correct ICMP Echo reply messages
 * Parameters:
 * 1. echo_tries - number of collisions
 * 2. dad_timeout_ticks - amount of ticks DUT has to send a NS
 */

class test_echo_c : public pkt_c,
                    public err_c,
                    public prm_c
{
public:
    test_echo_c(
        Vtop *tb);

    ~test_echo_c();

    bool run(
        Vtop *tb,
        phy_c *phy);

private:
    err_echo_t err;
    unsigned timeout;
    int timer;        // Timer until a next Echo request is generated
    int packets_left; // Total number of Echo requests left to test
    pkt_c::pkt_t cur_pkt;

    enum
    {
        IDLE,
        send_echo_request_s,
        wait_echo_reply_s,
        echo_check_s,
        done_s
    } state;

    bool echo_chk(
        const pkt_c::pkt_t &req,
        const pkt_c::pkt_t &rsp,
        err_echo_t &err);

    pkt_c::pkt_t echo_gen(Vtop *tb);
};

#endif
