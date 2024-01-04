#ifndef PHY_C_H
#define PHY_C_H

#include "pkt_c.h"

class phy_c
{
public:
    // typedef void (*send_pkt_ptr_t)(phy_c *obj, pkt_c::pkt_t pkt);
    static constexpr int IFG_TICKS = 20;

    unsigned tim;

    phy_c();

    ~phy_c();

    // Add a packet to tx queue
    void send_pkt(
        const pkt_c::pkt_t &pkt);

    bool recv_pkt(
        pkt_c::pkt_t &pkt);

    bool sending();

    // private:
    enum
    {
        IDLE,
        tx_s,
        ifg_s
    } fsm_tx;

    /////////////

    unsigned tx_ptr;
    unsigned ifg_ctr;

    // pcap log
    pcap *pcap_log;
    int tx_idx = 0;
    // queue of packets
    pkt_c::pkt_t pkt_rx;
    bool val_rx;
    vector<pkt_c::pkt_t> tx_buf;

    vector<uint8_t> raw_rx; // current packet being received
    vector<uint8_t> raw_tx; // current packet being transmitted

    void process_phy(
        const uint8_t &phy_dat_rx,
        const bool &phy_val_rx,
        uint8_t &phy_dat_tx,
        bool &phy_val_tx,
        pkt_c::parse_err_t &err);

    void process_rx(
        const uint8_t &phy_dat,
        const bool &phy_val,
        pkt_c::parse_err_t &err);

    // Process outgoing PHY stream
    // Packets are loaded from tx_buf
    void process_tx(
        uint8_t &phy_dat,
        bool &phy_val);
};
#endif
