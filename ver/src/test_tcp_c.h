#ifndef TCP_TEST_C_H
#define TCP_TEST_C_H

#include "model_ifc_c.h"
#include "err_c.h"
#include "prm_c.h"
#include "pkt_c.h"
#include "phy_c.h"
#include <queue>

class test_tcp_c : public pkt_c,
                   public err_c,
                   public prm_c
{
public:
    test_tcp_c(
        Vtop *tb);

    ~test_tcp_c(){};

    /* Advance TB TCP state machine */
    void advance(
        Vtop *tb,
        phy_c *phy);

    bool icmp_ra_sent;
    ip_t dns_ip;
    meta_dns_t meta_dns_qry;
    unsigned bytes_sent;
    bool rx_auto;
    bool ka_ack_ena;
    bool timeout_ctr_enable;
    unsigned timeout;

    typedef enum
    {
        tcp_cli,
        tcp_srv
    } mode_t;

    struct
    {
        mac_t loc_mac;
        mac_t rem_mac;
        ip_t loc_ip;
        ip_t rem_ip;
        uint16_t loc_port;
        uint16_t rem_port;
        uint32_t loc_seq;
        uint32_t ini_seq;
        uint32_t loc_ack;
        uint32_t rem_seq;
        uint32_t rem_ack;
        uint16_t rem_mss;
        bool rem_mss_pres;
        uint32_t rem_wnd;
        uint32_t rem_scale;
        tcp_opt_sack_t rem_sack;
        tcp_opt_sack_t loc_sack;
        uint32_t loc_wnd;
        mode_t mode;
    } tcb;

    struct pkt_entry_t
    {
        vector<uint8_t> pld;
        uint32_t seq;
        unsigned tries;
        unsigned timer;
    };

    enum
    {
        tcp_idle,
        listen_s,
        send_ns_s,
        wait_na_s,
        send_con_syn_s,
        send_con_synack_s,
        send_con_ack_s,
        wait_con_synack_s,
        wait_con_ack_s,
        send_dcn_fin_s,
        send_dcn_finack_s,
        send_dcn_ack_s,
        wait_dcn_fin_s,
        wait_dcn_ack_s,
        connected_s
    } tcp_state;

    enum
    {
        tb_to_dut_IDLE,
        tb_to_dut_tx_s
    } tb_to_dut_state;

    enum tcp_pkt_t
    {
        pkt_con_syn,
        pkt_con_synack,
        pkt_con_ack,
        pkt_dcn_fin,
        pkt_dcn_finack,
        pkt_dcn_ack,
        pkt_ack,
        pkt_ka,
        pkt_ka_ack,
        pkt_icmp_ns,
        pkt_icmp_na,
        pkt_icmp_ra,
        pkt_pld,
        pkt_dns_qry,
        pkt_dns_ans
    };

    unsigned ctr_rx;
    vector<uint8_t> tx_check_vect;
    unsigned cur_tx_seg;
    unsigned timer_start;

    vector<uint8_t> tx_pld;
    vector<uint8_t> rx_buf;

    struct tx_buf_t
    {
        uint32_t seq;
        vector<uint8_t> pld;
        bool valid;
    };

    // packets to be transmitted by TB phy
    // this is the main buffer for this TB's TCP transmission
    vector<tx_buf_t> tx_pkts;

    unsigned ctr_dut_to_tb;

    bool dcn_fin_sent;
    bool fin_acked;

    /* Send data to DUT with data portions of 'size'
     * Maximum size is MSS
     */
    void add_to_queue(
        phy_c *phy,
        const vector<uint8_t> &pld,         // Whole payload to be sent
        const vector<unsigned> &lost_blk,   // Packets to 'loose' when generating data
        const uint32_t seq,                 // First byte sequence number
        const unsigned max_payload_length); // Maximum payload length per pkt (mss) todo

    /* Send payload to DUT
     * If split is 'true', send pld in portions with an interval
     */
    bool send_to_tb(
        const vector<uint8_t> &pld,
        Vtop *tb);

    /* Process packets from DUT */
    void process_in(phy_c *phy);

    /* Process packets to DUT */
    void process_out(phy_c *phy);

    /* Process packet 'pkt' with expected type 'typ' */
    bool proc_pkt(
        const tcp_pkt_t &typ,
        phy_c *phy,
        pkt_t &pkt);

    /* Generate packet of type 'typ'. If it's a payload packet, set 'seq' and 'pld' */
    pkt_c::pkt_t gen_pkt(
        tcp_pkt_t typ,
        const uint32_t &seq,
        const vector<uint8_t> &pld);

    /* Attempt to connect TB (cli) to DUT (srv) */
    bool connect_active(
        Vtop *tb);

    /* Attempt to connect DUT (cli) to TB (srv) */
    bool connect_passive(
        Vtop *tb,
        const bool &by_name,
        const std::string &hostname);

    /* Attempt to disconnect from DUT */
    bool disconnect_passive(
        Vtop *tb);

    bool disconnect_active(
        Vtop *tb);

    /* Initialize TB TCB struct */
    void init_tcb(
        const ip_t &rem_ip,
        const ip_t &loc_ip,
        const uint16_t &port);

    /* Initialize DUT ports */
    void init_dut(
        Vtop *tb);
};

#endif
