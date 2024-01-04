#ifndef TCP_SACK_RFC2018_CASE2_TB_C_H
#define TCP_SACK_RFC2018_CASE2_TB_C_H

#include "test_tcp_sack_c.h"

/*
 * Verify that DUT generates SACK option and
 * Procesees retransmissions blocks correctly
 */
class test_tcp_sack_tb2dut_c : public test_tcp_sack_c
{

public:
    test_tcp_sack_tb2dut_c(
        Vtop *tb) : test_tcp_sack_c(tb)
    {
        state = IDLE;
    }

    const uint8_t PAYLOAD_PACKETS = 3;
    const unsigned PAYLOAD_LENGTH = 10;

    vector<uint8_t> test_data;

    err_tcp_t err;
    ~test_tcp_sack_tb2dut_c()
    {
        display_result(err);
    };

    enum
    {
        IDLE,
        gen_pld_s,
        connect_s,
        send_second_s,
        send_third_s,
        check_sack4_s,
        check_sack3_s,
        check_sack2_s,
        check_sack1_s,
        check_ack_s,
        add_0_5k_s,
        send_pld_s,
        rtx1_s,
        rtx2_s,
        rtx3_s,
        rtx4_s,

        connect_active_s,
        wait_connect_active_s,
        check_payload_s,
        TRY_DISCONNECT_ACTIVE_s,
        wait_disconnect_active_s,
        done_s
    } state;

    bool run(
        Vtop *tb,
        phy_c *phy)
    {
        err = tcp_no_error;
        advance(tb, phy);
        switch (state)
        {
        case (IDLE):
        {
            printf("Testing DUT SACK option...\n");
            printf("TB connecting to DUT... ");
            state = gen_pld_s;
            break;
        }
        case (gen_pld_s):
        {
            state = connect_s;
            break;
        }
        case (connect_s):
        {
            if (connect_active(tb))
                state = send_pld_s;
            break;
        }
        case (send_pld_s):
        {
            test_data.clear();
            lost_blk.clear();
            for (int i = 0; i < 11000; i++)
                test_data.push_back((rand() % 255));
            printf("Sending packet with lost segments 11, 13, 15 and 17...\n");
            lost_blk.push_back(11);
            lost_blk.push_back(13);
            lost_blk.push_back(15);
            lost_blk.push_back(17);
            add_to_queue(phy, test_data, lost_blk, tcb.loc_seq, 500);
            state = check_sack1_s;
            break;
        }
        case (check_sack1_s):
        {
            pkt_t pkt;
            if (phy->recv_pkt(pkt))
            {
                tcp_opt_sack_t exp_sack;
                exp_sack.b[0].pres = true;
                exp_sack.b[1].pres = true;
                exp_sack.b[2].pres = true;
                exp_sack.b[3].pres = true;
                // first expected SACK block must represent latest loss
                exp_sack.b[0].left = tcb.ini_seq + 500 * (lost_blk[3] + 1);
                exp_sack.b[0].right = tcb.ini_seq + test_data.size();

                exp_sack.b[1].left = tcb.ini_seq + 500 * (lost_blk[0] + 1);
                exp_sack.b[1].right = tcb.ini_seq + 500 * (lost_blk[0] + 2);
                exp_sack.b[2].left = tcb.ini_seq + 500 * (lost_blk[1] + 1);
                exp_sack.b[2].right = tcb.ini_seq + 500 * (lost_blk[1] + 2);
                exp_sack.b[3].left = tcb.ini_seq + 500 * (lost_blk[2] + 1);
                exp_sack.b[3].right = tcb.ini_seq + 500 * (lost_blk[2] + 2);
                if (!check_sack(exp_sack, pkt, true))
                    return false;
                if (pkt.meta.tcp.ack != tcb.ini_seq + 500 * lost_blk[0])
                    return false;
                printf("Checking SACK... Correct. \n");
                state = rtx1_s;
            }
            break;
        }
        case (rtx1_s):
        {
            printf("Retransmitting 1st lost segment... \n");
            vector<uint8_t> rtx_segment;
            lost_blk.clear();
            rtx_segment = {test_data.begin() + 5500,
                           test_data.begin() + 6000};
            add_to_queue(phy, rtx_segment, lost_blk, tcb.ini_seq + 5500, 500);
            state = check_sack2_s;
            break;
        }
        case (check_sack2_s):
        {
            pkt_t pkt;
            if (phy->recv_pkt(pkt))
            {
                tcp_opt_sack_t exp_sack;
                exp_sack.b[0].pres = true;
                exp_sack.b[1].pres = true;
                exp_sack.b[2].pres = true;
                exp_sack.b[3].pres = false;
                // first expected SACK block must represent latest loss
                exp_sack.b[0].left = tcb.ini_seq + 500 * (lost_blk[3] + 1);
                exp_sack.b[0].right = tcb.ini_seq + test_data.size();
                exp_sack.b[1].left = tcb.ini_seq + 500 * (lost_blk[1] + 1);
                exp_sack.b[1].right = tcb.ini_seq + 500 * (lost_blk[1] + 2);
                exp_sack.b[2].left = tcb.ini_seq + 500 * (lost_blk[2] + 1);
                exp_sack.b[2].right = tcb.ini_seq + 500 * (lost_blk[2] + 2);

                if (!check_sack(exp_sack, pkt, false))
                    return false;
                if (pkt.meta.tcp.ack != tcb.ini_seq + 500 * lost_blk[1])
                    return false;
                printf("Checking SACK... Correct. \n");
                state = rtx2_s;
            }
            break;
        }
        case (rtx2_s):
        {
            printf("Retransmitting 2nd lost segment... \n");
            vector<uint8_t> rtx_segment;
            lost_blk.clear();
            rtx_segment = {test_data.begin() + 6500,
                           test_data.begin() + 7000};
            add_to_queue(phy, rtx_segment, lost_blk, tcb.ini_seq + 6500, 500);
            state = check_sack3_s;
            break;
        }

        case (check_sack3_s):
        {
            pkt_t pkt;
            if (phy->recv_pkt(pkt))
            {
                tcp_opt_sack_t exp_sack;
                exp_sack.b[0].pres = true;
                exp_sack.b[1].pres = true;
                exp_sack.b[2].pres = false;
                exp_sack.b[3].pres = false;
                // first expected SACK block must represent latest loss
                exp_sack.b[0].left = tcb.ini_seq + 500 * (lost_blk[3] + 1);
                exp_sack.b[0].right = tcb.ini_seq + test_data.size();
                exp_sack.b[1].left = tcb.ini_seq + 500 * (lost_blk[2] + 1);
                exp_sack.b[1].right = tcb.ini_seq + 500 * (lost_blk[2] + 2);

                if (!check_sack(exp_sack, pkt, false))
                    return false;
                if (pkt.meta.tcp.ack != tcb.ini_seq + 500 * lost_blk[2])
                    return false;
                printf("Checking SACK... Correct. \n");
                state = rtx3_s;
            }
            break;
        }
        case (rtx3_s):
        {
            printf("Retransmitting 3rd lost segment... \n");
            vector<uint8_t> rtx_segment;
            lost_blk.clear();
            rtx_segment = {test_data.begin() + 7500,
                           test_data.begin() + 8000};
            add_to_queue(phy, rtx_segment, lost_blk, tcb.ini_seq + 7500, 500);
            state = check_sack4_s;
            break;
        }
        case (check_sack4_s):
        {
            pkt_t pkt;
            if (phy->recv_pkt(pkt))
            {
                tcp_opt_sack_t exp_sack;
                exp_sack.b[0].pres = true;
                exp_sack.b[1].pres = false;
                exp_sack.b[2].pres = false;
                exp_sack.b[3].pres = false;
                // first expected SACK block must represent latest loss
                exp_sack.b[0].left = tcb.ini_seq + 500 * (lost_blk[3] + 1);
                exp_sack.b[0].right = tcb.ini_seq + test_data.size();

                if (!check_sack(exp_sack, pkt, false))
                    return false;
                if (pkt.meta.tcp.ack != tcb.ini_seq + 500 * lost_blk[3])
                    return false;
                printf("Checking SACK... Correct. \n");
                state = rtx4_s;
            }
            break;
        }
        case (rtx4_s):
        {
            printf("Retransmitting 4th lost segment... \n");
            vector<uint8_t> rtx_segment;
            lost_blk.clear();
            rtx_segment = {test_data.begin() + 8500,
                           test_data.begin() + 9000};
            add_to_queue(phy, rtx_segment, lost_blk, tcb.ini_seq + 8500, 500);
            state = check_ack_s;
            break;
        }
        case (check_ack_s):
        {
            pkt_t pkt;
            if (phy->recv_pkt(pkt))
            {
                tcp_opt_sack_t exp_sack;
                exp_sack.b[0].pres = false;
                exp_sack.b[1].pres = false;
                exp_sack.b[2].pres = false;
                exp_sack.b[3].pres = false;

                if (!check_sack(exp_sack, pkt, false))
                    return false;
                if (pkt.meta.tcp.ack != tcb.ini_seq + 11000)
                    return false;
                printf("Checking Ack and payload... ");
                state = check_payload_s;
            }
        }
        case (check_payload_s):
        {
            if (tcb.rem_ack == tcb.loc_seq && tx_check_vect == test_data)
            {
                printf("OK (%d bytes received) \n", (unsigned)tx_check_vect.size());
                state = TRY_DISCONNECT_ACTIVE_s;
            }
            break;
        }
        case (TRY_DISCONNECT_ACTIVE_s):
        {
            return (disconnect_passive(tb));
            break;
        }
        }
        return false;
    }
};
#endif
