#include "test_tcp_rxtx_c.h"

test_tcp_rxtx_c::test_tcp_rxtx_c(
    Vtop *tb,
    unsigned const _max_len) : test_tcp_c(tb)
{
    max_len = _max_len;
    state = IDLE;
    rx_ok = false; /* Set receive/transmit test to not yet passed */
    tx_ok = false;
    sent_to_dut = false;
    sent_to_tb = false;
    test_data.clear();
    for (int i = 0; i < TCP_PLD_BYTES; i++)
    {
        test_data.push_back(i);
    }
};

test_tcp_rxtx_c::~test_tcp_rxtx_c()
{
    /* Display result and error when test is complete */
    display_result(err);
}

bool test_tcp_rxtx_c::run(
    Vtop *tb,
    phy_c *phy)
{

    err = tcp_no_error;
    advance(tb, phy);
    switch (state)
    {
    case (IDLE):
    {
        printf("Running TCP test (transmission TB<->DUT, no loss)... \n");
        ctr_rx = 0;
        state = CONNECT_PASSIVE; //
        break;
    }
    case (CONNECT_PASSIVE):
    {
        if (connect_active(tb)) // Connection success
            state = TRANSMIT;
        break;
    }
    case (TRANSMIT):
    {
        if (!sent_to_dut)
        {
            vector<unsigned> lost_blk;
            // Split data in packet and add them to queue
            add_to_queue(phy, test_data, lost_blk, tcb.loc_seq, max_len);
            printf("Sent %d bytes to DUT... \n", (int)test_data.size());
            sent_to_dut = true;
        }
        if (!sent_to_tb)
        {
            if (send_to_tb(test_data, tb)) // Here we send payload through DUT TCP path
            {
                sent_to_tb = true;
                printf("Sent %d bytes from DUT... \n", (int)test_data.size());
            }
        }
        if (tcb.rem_ack == tcb.loc_seq && tx_check_vect == test_data && !tx_ok)
        {
            printf("TX Payload matched.\n");
            tx_ok = true;
        }
        if (rx_buf == test_data && !rx_ok)
        {
            printf("RX Payload matched.\n");
            rx_ok = true;
        }
        if (rx_ok && tx_ok)
            state = TRY_DISCONNECT_PASSIVE;
        break;
    }
    case (TRY_DISCONNECT_PASSIVE):
    {
        return (disconnect_passive(tb));
        break;
    }
    }
    return false;
};