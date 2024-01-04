#ifndef TCP_TEST_LOSS_TX_C_H
#define TCP_TEST_LOSS_TX_C_H

#include "test_tcp_c.h"

/*
 * Verify that DUT generates SACK option and
 * Procesees retransmissions blocks correctly
 */
class test_tcp_sack_c : public test_tcp_c
{

public:
    test_tcp_sack_c(
        Vtop *tb) : test_tcp_c(tb)
    {
        state = IDLE;
        rx_ok = false;
        tx_ok = false;
        sent_to_dut = false;
        sent_to_tb = false;
    }

    vector<vector<uint8_t>> pld;
    bool rx_ok;
    bool tx_ok;
    bool sent_to_dut;
    bool sent_to_tb;

    const uint8_t PAYLOAD_PACKETS = 3;
    const unsigned PAYLOAD_LENGTH = 10;

    vector<uint8_t> test_data;

    ~test_tcp_sack_c(){

    };

    enum
    {
        IDLE,
        gen_pld_s,
        connect_s,
        send_second_s,
        send_third_s,
        check_sack_s,
        check_s,
        add_0_5k_s,
        send_pld_s,
        send_5k5_8k5_s,
        add_5k5_8k5_s,
        check_ack_s,
        rtx_s,

        connect_active_s,
        wait_connect_active_s,
        TRY_DISCONNECT_ACTIVE_s,
        wait_disconnect_active_s,
        done_s
    } state;

    vector<unsigned> lost_blk;

    bool check_sack(
        const tcp_opt_sack_t sack,
        pkt_t &pkt,
        const bool &check_first)

    {
        bool match = true;

        unsigned start_blk = (check_first) ? 1 : 0;
        // first block must match
        if (check_first && pkt.meta.tcp.opt.sack.b[0] != sack.b[0])
            return false;
        // other blocks may be mixed
        for (unsigned pkt_idx = start_blk; pkt_idx < 4; pkt_idx++)
        {
            if (pkt.meta.tcp.opt.sack.b[pkt_idx].pres)
                match = false; // assume block received has no match in expected blocks
            for (int exp_idx = start_blk; exp_idx < 4; exp_idx++)
            {
                if (sack.b[exp_idx].pres && pkt.meta.tcp.opt.sack.b[pkt_idx] == sack.b[exp_idx])
                    match = true; // match detected
            }
            if (!match)
                return false;
        }
        return true;
    }
};
#endif
