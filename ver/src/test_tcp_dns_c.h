#ifndef TCP_TEST_DNS_C_H
#define TCP_TEST_DNS_C_H

#include "pkt_c.h"
#include "model_ifc_c.h"
#include "test_tcp_c.h"
#include <queue>
#include "Vtop__Syms.h"

class test_tcp_dns_c : public test_tcp_c
{

public:
    test_tcp_dns_c(
        Vtop *tb) : test_tcp_c(tb)
    {
        state = IDLE;
    };

    ~test_tcp_dns_c()
    {
        display_result(err);
    };

    err_tcp_t err;
    enum
    {
        IDLE,
        connect_active_s,
        dns_resolve_s,
        wait_connect_active_s,
        TRY_DISCONNECT_ACTIVE_s,
        wait_disconnect_active_s,
        done_s
    } state;

    bool run(
        Vtop *tb,
        phy_c *phy)
    {
        err = tcp_no_error;
        pkt_t pkt_rx;
        advance(tb, phy);
        switch (state)
        {
        case (IDLE):
        {
            printf("Running TCP test (connect/disconnect) using DNS... \n");
            ctr_rx = 0;
            state = connect_active_s;
            break;
        }

        case (connect_active_s):
        {
            if (connect_passive(tb,
                                true,
                                DNS_HOSTNAME))
                state = wait_connect_active_s;
            if (proc_pkt(pkt_dns_qry, phy, pkt_rx))
            {
                phy->send_pkt(gen_pkt(pkt_dns_ans, 0, tx_pld));
            }
            break;
        }
        case (wait_connect_active_s):
        {
            state = TRY_DISCONNECT_ACTIVE_s;
            break;
        }
        case (TRY_DISCONNECT_ACTIVE_s):
        {
            if (disconnect_active(tb))
                return true;
            break;
        }
        }
        return false;
    }
};

#endif
