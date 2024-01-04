#ifndef PKT_RX_TEST_C_H
#define PKT_RX_TEST_C_H

#include "model_ifc_c.h"
#include "pkt_c.h"
#include "err_c.h"
#include "prm_c.h"
#include <queue>

class test_pkt_filter_c : public pkt_c,
                          public err_c,
                          public prm_c
{
public:
    unsigned ns_packets;
    unsigned ns_packets_skip_count;
    unsigned na_delay_ctr;

    int nd_reply_tries; // Number of received ND packets till a reply is generated (random for each try)
    int pkt_rx_tries;   // Total number of DAD tries left
    unsigned pkt_rx_timeout;

    // bad preamble
    // 1 extra byte
    //
    // bad pcs
    enum
    {
        init_s,
        next_entry_s,
        next_err_s,
        send_s,
        wait_s,
        disp_good,
        disp_bad
    } state;

    ip_t dut_ip;
    unsigned timeout;

    static constexpr unsigned TIMEOUT = 1000;

    unsigned rejected_count;
    unsigned accepted_count;

    struct pres_t
    {
        bool
            eth,
            ip,
            icmp,
            udp,
            dns,
            tcp;
    };

    struct entry_t
    {
        bool done;
        pkt_t pkt;
        pro_t cur_pro;
        bool test_eth;
        bool test_ip;
        bool test_icmp;
        bool test_udp;
        bool test_dns;
        bool test_tcp;
        gen_err_t err;
        std::string str;
    };

    std::queue<entry_t> entries;

    entry_t cur;

    test_pkt_filter_c(Vtop *tb) : prm_c(tb)
    {
        state = init_s;
    }

    ~test_pkt_filter_c(){};

    void add_icmp(Vtop *tb)
    {
        entry_t ent;
        ent.done = false;

        // Default ICMP packet metadata
        ent.pkt = {0};
        ent.pkt.meta.mac.ethertype = pkt_c::IPV6;
        ent.pkt.meta.mac.src = TB_MAC;
        ent.pkt.meta.mac.dst = model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR);

        ent.pkt.meta.ip.traffic_class = 0;
        ent.pkt.meta.ip.flow_label = 0;
        ent.pkt.meta.ip.proto = pkt_c::ICMP;
        ent.pkt.meta.ip.hops = 255;
        ent.pkt.meta.ip.src = TB_LA;
        ent.pkt.meta.ip.dst = model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla);

        ent.pkt.meta.icmp.code = 0;
        ent.pkt.meta.icmp.tar_ip = model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla);
        ent.pkt.meta.icmp.tar_pres = true;
        ent.pkt.meta.icmp.opt = {0};
        // Set which headers will contain errors
        ent.test_eth = true;
        ent.test_ip = true;
        ent.test_icmp = true;
        ent.test_udp = false;
        ent.test_dns = false;
        ent.test_tcp = false;

        cur.pkt.err_tx.eth = static_cast<gen_err_eth_t>(0);
        cur.pkt.err_tx.ip = static_cast<gen_err_ip_t>(0);
        cur.pkt.err_tx.icmp = static_cast<gen_err_icmp_t>(0);
        // Type specific metadata
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_ADVERTISEMENT;
        ent.str = "=== ICMP NA ===\n";
        entries.push(ent);
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_NEIGHBOR_SOLICITATION;
        ent.str = "=== ICMP NS ===\n";
        entries.push(ent);
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_ROUTER_ADVERTISEMENT;
        ent.str = "=== ICMP RA ===\n";
        entries.push(ent);
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_ROUTER_SOLICITATION;
        ent.str = "=== ICMP RS ===\n";
        entries.push(ent);
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_ECHO_REQUEST;
        ent.str = "=== ICMP ECHO REQUEST ===\n";
        entries.push(ent);
        ent.pkt.meta.icmp.type = pkt_c::ICMP_TYPE_ECHO_REPLY;
        ent.str = "=== ICMP ECHO REPLY ===\n";
        entries.push(ent);
    }

    void add_good_dns_ans(Vtop *tb)
    {
        pkt_c::pkt_t pkt;
        pkt = {0};
        pkt.meta.mac.ethertype = pkt_c::IPV6;
        pkt.meta.mac.src = TB_MAC;
        pkt.meta.mac.dst = model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR);

        pkt.meta.ip.traffic_class = 0;
        pkt.meta.ip.flow_label = 0;
        pkt.meta.ip.proto = pkt_c::ICMP;
        pkt.meta.ip.hops = 255;
        pkt.meta.ip.src = TB_LA;
        pkt.meta.ip.dst = model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla);

        pkt.meta.udp.src = 12345;
        pkt.meta.udp.dst = DNS_PORT;

        pkt.meta.dns.id = 0;
        pkt.meta.dns.questions = 0;
        pkt.meta.dns.flags = 0;
        pkt.meta.dns.ans_rrs = 0;
        pkt.meta.dns.aut_rrs = 0;
        pkt.meta.dns.add_rrs = 0;
        pkt.meta.dns.query = 0;
        pkt.meta.dns.query_str = "";
        pkt.meta.dns.query_type = 0;
        pkt.meta.dns.query_class = 0;
        pkt.meta.dns.answer = 0;
        pkt.meta.dns.answer_name = 0;
        pkt.meta.dns.answer_type = 0;
        pkt.meta.dns.answer_class = 0;
        pkt.meta.dns.answer_ttl = 0;
        pkt.meta.dns.answer_data_len = 0;
        pkt.meta.dns.answer_addr = TB_LA;
        //
    }
    void add_good_dns_qry(Vtop *tb)
    {
        pkt_c::pkt_t pkt;
        pkt = {0};
        pkt.meta.mac.ethertype = pkt_c::IPV6;
        pkt.meta.mac.src = TB_MAC;
        pkt.meta.mac.dst = model_ifc_c::get_mac(tb->top->wrap->dut->MAC_ADDR);

        pkt.meta.ip.traffic_class = 0;
        pkt.meta.ip.flow_label = 0;
        pkt.meta.ip.proto = pkt_c::ICMP;
        pkt.meta.ip.hops = 255;
        pkt.meta.ip.src = TB_LA;
        pkt.meta.ip.dst = model_ifc_c::get_ip(tb->top->wrap->dut->core_inst->icmp_inst->lla);

        pkt.meta.udp.src = 12345;
        pkt.meta.udp.dst = DNS_PORT;

        pkt.meta.dns.id = 0;
        pkt.meta.dns.questions = 0;
        pkt.meta.dns.flags = 0;
        pkt.meta.dns.ans_rrs = 0;
        pkt.meta.dns.aut_rrs = 0;
        pkt.meta.dns.add_rrs = 0;
        pkt.meta.dns.query = 0;
        pkt.meta.dns.query_str = "";
        pkt.meta.dns.query_type = 0;
        pkt.meta.dns.query_class = 0;
        pkt.meta.dns.answer = 0;
        pkt.meta.dns.answer_name = 0;
        pkt.meta.dns.answer_type = 0;
        pkt.meta.dns.answer_class = 0;
        pkt.meta.dns.answer_ttl = 0;
        pkt.meta.dns.answer_data_len = 0;
        pkt.meta.dns.answer_addr = TB_LA;
    }
    void add_good_tcp(Vtop *tb)
    {
    }

    void display_err(const entry_t &ent)
    {
        switch (ent.cur_pro)
        {
        case (eth):
        {
            switch (ent.pkt.err_tx.eth)
            {
            case (ERR_ETH_NONE):
            {
                printf("No error... ");
                break;
            }
            case (ERR_PREAMBLE_BAD_BYTE):
            {
                printf("Bad preamble byte... ");
                break;
            }
            case (ERR_PREAMBLE_TOO_SHORT):
            {
                printf("Preamble too short... ");
                break;
            }
            case (ERR_PREAMBLE_TOO_LONG):
            {
                printf("Preamble too long... ");
                break;
            }
            case (ERR_PREAMBLE_SFD_SKIP):
            {
                printf("Preamble SFD lost... ");
                break;
            }
            case (ERR_PREAMBLE_SFD_BAD):
            {
                printf("Preamble bad SFD... ");
                break;
            }
            case (ERR_FCS_BAD_BYTE):
            {
                printf("Bad byte in FCS... ");
                break;
            }
            case (ERR_FCS_SKIP):
            {
                printf("FCS not present... ");
                break;
            }
            case (ERR_ETHERTYPE):
            {
                printf("Bad Ethertype... ");
                break;
            }
            case (ERR_DST_MAC):
            {
                printf("Bad Destination MAC... ");
                break;
            }
            case (ERR_EXTRA_BYTE):
            {
                printf("Extra byte in Ethernet header... ");
                break;
            }
            }
            break;
        }
        case (ip):
        {
            switch (ent.pkt.err_tx.ip)
            {
            case (ERR_IP_NONE):
            {
                printf("No error... ");
                break;
            }
            case (ERR_IP_VER_BAD):
            {
                printf("Bad IP version... ");
                break;
            }
            case (ERR_IP_LEN_ZERO):
            {
                printf("IP length zero... ");
                break;
            }
            case (ERR_IP_LEN_FFFF):
            {
                printf("IP length 0xffff... ");
                break;
            }
            case (ERR_IP_LEN_BAD_PLUS_1):
            {
                printf("IP bad length (+1)... ");
                break;
            }
            case (ERR_IP_LEN_BAD_MINUS_1):
            {
                printf("IP bad length (-1)... ");
                break;
            }
            case (ERR_IP_NXT_BAD):
            {
                printf("IP bad next long_int");
                break;
            }
            case (ERR_IP_HOP_ZERO):
            {
                printf("IP hops exhausted... ");
                break;
            }
            case (ERR_IP_DST_GROUP_BAD):
            {
                printf("IP bad destination group... ");
                break;
            }
            case (ERR_IP_DST_PREFIX_BAD):
            {
                printf("IP bad prefix... ");
                break;
            }
            case (ERR_IP_DST_INTERFACE_ID_BAD):
            {
                printf("IP bad interface ID... ");
                break;
            }
            }
        }
        }
    }
    /*
     * iterate over errors
     * return true when scanned through all errors
     */
    bool next_err(
        entry_t &entry)
    {
        if (entry.done)
            return true;
        switch (entry.cur_pro)
        {
        case (eth):
        {
            if (!entry.test_eth | entry.pkt.err_tx.eth == ERR_EXTRA_BYTE)
            {
                entry.cur_pro = ip;
                entry.pkt.err_tx.eth = ERR_ETH_NONE;
                return false;
            }
            else
                entry.pkt.err_tx.eth = static_cast<gen_err_eth_t>(entry.pkt.err_tx.eth + 1);
            break;
        }
        case (ip):
        {
            if (!entry.test_ip | entry.pkt.err_tx.ip == ERR_IP_DST_INTERFACE_ID_BAD)
            {
                entry.cur_pro = icmp;
                entry.pkt.err_tx.ip = ERR_IP_NONE;
                return false;
            }
            else
                entry.pkt.err_tx.ip = static_cast<gen_err_ip_t>(entry.pkt.err_tx.ip + 1);
            break;
        }
        case (icmp):
        {
            if (!entry.test_icmp | entry.pkt.err_tx.icmp == ERR_ICMP_CHECKSUM_BAD)
            {
                entry.cur_pro = udp;
                return false;
            }
            entry.pkt.err_tx.icmp = static_cast<gen_err_icmp_t>(entry.pkt.err_tx.icmp + 1);
            break;
        }
        case (udp):
        {
            if (!entry.test_udp | entry.pkt.err_tx.udp == ERR_UDP_LENGTH_BAD)
            {
                entry.cur_pro = udp;
                entry.done = true;
                return false;
            }
            entry.pkt.err_tx.udp = static_cast<gen_err_udp_t>(entry.pkt.err_tx.udp + 1);
            break;
        }
        }
        return false;
    }

    bool run(
        Vtop *tb,
        phy_c *phy,
        err_pkt_flt_t &err)
    {
        switch (state)
        {
        case (init_s):
        {
            add_icmp(tb);
            state = next_entry_s;
        }
        case (next_entry_s):
        {
            rejected_count = 0;
            accepted_count = 0;
            if (!entries.size())
                return true;
            state = (entries.size()) ? send_s : disp_bad;
            cur = entries.front();
            printf("%s", cur.str.c_str());
            entries.pop();
            break;
        }
        case (next_err_s):
        {
            state = (next_err(cur)) ? next_entry_s : send_s;
            break;
        }
        case (send_s):
        {
            phy->send_pkt(cur.pkt);
            state = wait_s;
            timeout = TIMEOUT;
            break;
        }
        case (wait_s):
        {
            if (!timeout--)
            {
                err = pkt_rx_err_timeout;
                return true;
            }
            if (tb->top->wrap->dut->rx_inst->fsm_rst)
            {
                state = next_err_s;
                display_err(cur);
                if (tb->top->wrap->dut->rx_inst->rcv)
                    printf(COLOR_GREEN "Accepted\n" COLOR_RESET);
                else
                    printf(COLOR_RED "Rejected\n" COLOR_RESET);
                break;
            }
            break;
        }
        case (disp_good):
        {
            printf("Good");
            return true;
            break;
        }
        case (disp_bad):
        {
            printf("Bad");
            return true;
            break;
        }
        }
        return false;
    }
};

#endif
/*
Packet receive test

    "Sending good ICMP Neighbor Solicitation... Received. Ok"
    "Sending bad ICMP Neighbor Solicitations... Received. Ok"

    ICMP NS
        ICMP NA
            ICMP RA
                ICMP RS
                    ICMP ECHO

                        DNS REPLY

                            TCP

if (ETH_PREAMBLE_BAD_BYTE) printf()
if (ETH_PREAMBLE_TOO_SHORT) printf()
if (ETH_PREAMBLE_TOO_LONG) printf()
if (ETH_PREAMBLE_SFD_SKIP) printf()
if (ETH_PREAMBLE_SFD_BAD) printf()
if (ETH_FCS_BAD_BYTE) printf()
if (ETH_FCS_SKIP) printf()
if (ETH_ETHERTYPE_NOT_IPV6) printf()
if (ETH_ETHERTYPE_TOO_SHORT) printf()
if (ETH_ETHERTYPE_TOO_LONG) printf()
if (ETH_DST_MAC_TOO_SHORT) printf()
if (ETH_DST_MAC_TOO_LONG) printf()
if (ETH_SRC_MAC_TOO_SHORT) printf()
if (ETH_SRC_MAC_TOO_LONG) printf()
if (ETH_EXTRA_BYTE) printf()
if (ERR_IP_VER_BAD) printf()
if (ERR_IP_PRI_BAD) printf()
if (ERR_IP_PRI_SKIP) printf()
if (ERR_IP_FLO_BAD) printf()
if (ERR_IP_FLO_SKIP) printf()
if (ERR_IP_LEN_ZERO) printf()
if (ERR_IP_LEN_FFFF) printf()
if (ERR_IP_LEN_BAD) printf()
if (ERR_IP_LEN_SKIP) printf()
if (ERR_IP_NXT_BAD) printf()
if (ERR_IP_NXT_SKIP) printf()
if (ERR_IP_HOP_ZERO) printf()
if (ERR_IP_HOP_SKIP) printf()
if (ERR_IP_SRC_BAD) printf()
if (ERR_IP_SRC_BYTE_SKIP) printf()
if (ERR_IP_SRC_BYTE_SKIP) printf()
if (ERR_IP_DST_BYTE_SKIP) printf()
if (ERR_IP_EXTRA_BYTE) printf()

*/