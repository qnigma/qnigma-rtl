#ifndef TEST_C_H
#define TEST_C_H

#include "pkt_c.h"
#include "phy_c.h"
#include "test_tcp_c.h"
#include "test_tcp_con_dcn_c.h"
#include "test_tcp_rxtx_c.h"
#include "test_tcp_sack_c.h"
#include "test_tcp_sack_tb2dut_c.h"
#include "test_tcp_sack_dut2tb_c.h"

#include "test_tcp_dns_c.h"
#include "test_rtr_c.h"
#include "test_dad_mld_c.h"
#include "test_nd_c.h"
#include "test_echo_c.h"
#include "test_pkt_filter_c.h"
#include "model_ifc_c.h"
#include "crc_gen_c.h"
#include "err_c.h"
#include "prm_c.h"

class test_c
{
public:
    phy_c *phy;
    // Test instances
    test_tcp_dns_c *test_tcp_dns;
    test_tcp_con_dcn_c *test_tcp_con_dcn;
    test_tcp_rxtx_c *test_tcp_rxtx;
    test_tcp_sack_tb2dut_c *test_tcp_sack_tb2dut;
    test_tcp_sack_dut2tb_c *test_tcp_sack_dut2tb;
    test_rtr_c *test_rtr;
    test_dad_mld_c *test_dad;
    test_pkt_filter_c *test_pkt_filter;
    test_nd_c *test_nd;
    test_echo_c *test_echo;
    crc_gen_c *crc_gen;

    static const unsigned RESET_HIGH_TICKS = 100;
    const unsigned TESTS_TOTAL = 8;

    int cur_test; // Current test running

    enum
    {
        init_s,
        dad_setup_s,
        test_dad_s,
        dad_finish_s,
        test_rtr_minimal_s,
        test_nd_s,
        test_echo_s,
        test_tcp_minimal_s,
        test_tcp_rxtx_s,
        test_tcp_sack_tb2dut_s,
        test_tcp_dns_s,
        packet_filter_test_s,
        finish_s
    } state;

    test_c()
    {
        phy = new phy_c();
        crc_gen = new crc_gen_c();
        cur_test = 0;
        state = init_s;
    }

    ~test_c()
    {
        phy->~phy_c();
        crc_gen->~crc_gen_c();
    }

    bool run(
        Vtop *tb,
        unsigned &tim)
    {
        bool val_rx;
        pkt_c::pkt_t pkt_rx;
        bool val_tx;
        pkt_c::pkt_t pkt_tx;

        uint8_t phy_dat_rx;
        bool phy_val_rx;
        uint8_t phy_dat_tx;
        bool phy_val_tx;

        phy_val_rx = tb->phy_tx_val;
        phy_dat_rx = tb->phy_tx_dat;

        reset_dut(tb, tim);

        pkt_c::parse_err_t pkt_err;
        phy->process_phy(
            phy_dat_rx,
            phy_val_rx,
            phy_dat_tx,
            phy_val_tx,
            pkt_err);

        tb->phy_rx_val = phy_val_tx;
        tb->phy_rx_dat = phy_dat_tx;

        // val_rx = phy->recv_pkt(pkt_rx);

        bool done = run_test(tb, phy->tim, phy);
        tim = phy->tim;

        // if (val_tx)
        //     phy->send_pkt(pkt_tx);

        return done;
    }

    void reset_dut(Vtop *tb, const unsigned &tim)
    {
        tb->rst = (tim < RESET_HIGH_TICKS);
    }

    bool run_test(
        Vtop *tb,
        const unsigned &tim,
        phy_c *phy)
    {
        switch (state)
        {
        case (init_s):
        {
            test_dad = new test_dad_mld_c(tb);
            test_rtr = new test_rtr_c(tb);
            test_nd = new test_nd_c(tb);
            test_echo = new test_echo_c(tb);
            test_pkt_filter = new test_pkt_filter_c(tb);
            test_tcp_con_dcn = new test_tcp_con_dcn_c(tb);
            test_tcp_dns = new test_tcp_dns_c(tb);
            test_tcp_rxtx = new test_tcp_rxtx_c(tb, 1400);
            test_tcp_sack_tb2dut = new test_tcp_sack_tb2dut_c(tb);
            // test_tcp_sack_dut2tb = new test_tcp_sack_dut2tb_c(tb);
            state = test_dad_s;
            printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
            printf(COLOR_YELLOW "[ICMP Duplicate Address Detection]\n" COLOR_RESET);
            break;
        }
        case (test_dad_s):
        {
            if (test_dad->run(tb, phy))
            {
                state = test_rtr_minimal_s;
                test_dad->~test_dad_mld_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[ICMP Router Discovery]\n" COLOR_RESET);
            }
            break;
        }
        case (test_rtr_minimal_s):
        {
            if (test_rtr->run(tb, phy))
            {
                state = test_nd_s;
                test_rtr->~test_rtr_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[ICMP Neighbor Discovery]\n" COLOR_RESET);
            }
            break;
        }
        case (test_nd_s):
        {
            if (test_nd->run(tb, phy))
            {
                state = test_echo_s;
                test_nd->~test_nd_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[TCP Echo]\n" COLOR_RESET);
            }
            break;
        }
        case (test_echo_s):
        {
            if (test_echo->run(tb, phy))
            {
                state = test_tcp_minimal_s;
                test_echo->~test_echo_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[TCP minimal]\n" COLOR_RESET);
            }
            break;
        }
        case (test_tcp_minimal_s):
        {
            if (test_tcp_con_dcn->run(tb, phy))
            {
                state = test_tcp_rxtx_s;
                test_tcp_con_dcn->~test_tcp_con_dcn_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[TCP receive/transmit]\n" COLOR_RESET);
            }
            break;
        }
        case (test_tcp_rxtx_s):
        {
            if (test_tcp_rxtx->run(tb, phy))
            {
                state = test_tcp_sack_tb2dut_s;
                test_tcp_rxtx->~test_tcp_rxtx_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[TCP SACK RFC2018 Case 2]\n" COLOR_RESET);
            }
            break;
        }

        case (test_tcp_sack_tb2dut_s):
        {
            if (test_tcp_sack_tb2dut->run(tb, phy))
            {
                state = test_tcp_dns_s;
                test_tcp_sack_tb2dut->~test_tcp_sack_tb2dut_c();
                printf("Test %d of %d\n", ++cur_test, TESTS_TOTAL);
                printf(COLOR_YELLOW "[TCP client using DNS]\n" COLOR_RESET);
            }
            break;
        }
        case (test_tcp_dns_s):
        {
            if (test_tcp_dns->run(tb, phy))
            {
                state = finish_s;
                test_tcp_dns->~test_tcp_dns_c();
            }
            break;
        }
        case (finish_s):
        {
            printf(COLOR_GREEN "[PASS]\n" COLOR_RESET);
            return true;
        }
        }
        return false;
    }
};

#endif
