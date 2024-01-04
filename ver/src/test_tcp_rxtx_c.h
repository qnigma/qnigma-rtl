
#ifndef TCP_TEST_RXTX_C_H
#define TCP_TEST_RXTX_C_H

#include "test_tcp_c.h"

class test_tcp_rxtx_c : public test_tcp_c
{

public:
    bool run(Vtop *tb,
             phy_c *phy);

    test_tcp_rxtx_c(
        Vtop *tb,
        unsigned const _max_len);

    ~test_tcp_rxtx_c();

private:
    bool rx_ok;
    bool tx_ok;
    bool sent_to_dut;
    bool sent_to_tb;
    unsigned max_len;
    vector<uint8_t> test_data;
    err_tcp_t err;

    enum
    {
        IDLE,
        CONNECT_PASSIVE,
        TRANSMIT,
        TRY_DISCONNECT_PASSIVE
    } state;
};

#endif
