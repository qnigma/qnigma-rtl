#ifndef TCP_TEST_CON_DCN_C_H
#define TCP_TEST_CON_DCN_C_H

#include "pkt_c.h"
#include "model_ifc_c.h"
#include "test_tcp_c.h"
#include <queue>
#include "Vtop__Syms.h"

class test_tcp_con_dcn_c : public test_tcp_c
{

public:
    test_tcp_con_dcn_c(
        Vtop *tb) : test_tcp_c(tb)
    {
        ka_pkt = 0;
        state = IDLE;
    };

    ~test_tcp_con_dcn_c()
    {
        display_result(err);
    }

    unsigned ka_pkt;

    int KEEPALIVES_CHECK = 5;

    int keepalives_rx = 0;
    int keepalives_tx = 0;

    err_tcp_t err;

    enum
    {
        IDLE,
        CONNECT_PASSIVE,
        WAIT_KEEPALIVE,
        SEND_KEEPALIVE,
        WAIT_KEEPALIVE_ACK,
        TRY_DISCONNECT_PASSIVE,
        wait_disCONNECT_PASSIVE,
        CONNECT_ACTIVE,
        WAIT_CONNECT_ACTIVE,
        TRY_DISCONNECT_ACTIVE,
        connect_active_ka_abort_s,
        wait_disCONNECT_ACTIVE,
        CONNECT_ACTIVE_KA_DISCONNECT,
        WAIT_DISCONNECT,
        WAIT_KA_DISCONNECT,
        done_s
    } state;

    bool run(
        Vtop *tb,
        phy_c *phy)
    {
        pkt_t pkt_rx;
        err = tcp_no_error;
        advance(tb, phy);
        switch (state)
        {
        case (IDLE):
        {
            printf("Running TCP test (connect/disconnect and keepalive)... \n");
            ctr_rx = 0;
            state = CONNECT_ACTIVE;
            break;
        }
        case (CONNECT_ACTIVE):
        {
            if (connect_active(tb))
            {
                state = WAIT_KEEPALIVE;
                printf("Testing keepalive... ");
            }
            break;
        }
        case (WAIT_KEEPALIVE):
        {
            if (proc_pkt(pkt_ka, phy, pkt_rx))
            {
                if (keepalives_rx++ == KEEPALIVES_CHECK)
                {
                    printf("%d keepalives received. Good.\n", KEEPALIVES_CHECK);
                    state = SEND_KEEPALIVE;
                }
            }
            break;
        }
        case (SEND_KEEPALIVE):
        {
            if (!phy->sending())
            {
                printf("Testing keepalive Ack... ");
                phy->send_pkt(gen_pkt(pkt_ka, 0, tx_pld));
                state = WAIT_KEEPALIVE_ACK;
            }
            break;
        }
        case (WAIT_KEEPALIVE_ACK):
        {
            if (proc_pkt(pkt_ka, phy, pkt_rx))
            {
                printf("Keepalive Ack received. Good.\n");
                state = TRY_DISCONNECT_PASSIVE;
            }
            break;
        }
        case (TRY_DISCONNECT_PASSIVE):
        {
            if (disconnect_passive(tb))
                state = CONNECT_PASSIVE;
            break;
        }
        case (CONNECT_PASSIVE):
        {
            if (connect_passive(tb, false, ""))
            {
                state = WAIT_CONNECT_ACTIVE;
            }
            break;
        }
        case (WAIT_CONNECT_ACTIVE):
        {
            printf("Disconnecting from DUT...\n");
            state = TRY_DISCONNECT_ACTIVE;
            break;
        }
        case (TRY_DISCONNECT_ACTIVE):
        {
            if (disconnect_active(tb))
            {
                printf("Testing DUT keepalives ignored...\n");
                state = CONNECT_ACTIVE_KA_DISCONNECT;
            }
            break;
        }
        case (CONNECT_ACTIVE_KA_DISCONNECT):
        {
            if (connect_passive(tb, false, ""))
                state = WAIT_KA_DISCONNECT;
            break;
        }
        case (WAIT_KA_DISCONNECT):
        {
            ka_ack_ena = false; // Disabling Keepalive Ack reply

            if (proc_pkt(pkt_ka, phy, pkt_rx))
            {
                ka_pkt++;
            }
            if (proc_pkt(pkt_dcn_fin, phy, pkt_rx))
            {
                if (ka_pkt != tb->top->wrap->PARAM_TCP_KEEPALIVE_TRIES)
                    printf("Got %d Keepalives before disconnecting", ka_pkt);
                state = WAIT_DISCONNECT;
                printf("Received %d Keepalives...\n", ka_pkt);
            }
            break;
        }
        case (WAIT_DISCONNECT):
        {
            if (tcp_state == tcp_idle)
            {
                printf("DUT aborted connection due to lack of keepalive Ack [intented]. Good\n");
                return true;
            }
            break;
        }
        }
        return false;
    }
};

#endif
