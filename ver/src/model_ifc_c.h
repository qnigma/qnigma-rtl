#ifndef MODEL_IFC_C_H
#define MODEL_IFC_C_H

#include "pkt_c.h"
#include "Vtop__Syms.h"

class model_ifc_c
{

public:
    pkt_c::ip_t prefix;

    enum icmp_state_t
    {
        icmp_gen_lla_s,
        icmp_mld_send_s,
        icmp_mld_sending_s,
        icmp_mld_wait_s,
        icmp_dad_send_s,
        icmp_dad_sending_s,
        icmp_dad_wait_s,
        icmp_rs_wait_s,
        icmp_rs_send_s,
        icmp_rs_sending_s,
        icmp_IDLE,
        icmp_wait_tx_s,
        icmp_unknown_s
    };

    enum rx_state_t
    {
        rx_IDLE,
        rx_preamble_s,
        rx_eth_hdr_s,
        rx_ip_hdr_s,
        rx_ip_src_s,
        rx_ip_dst_s,
        rx_hdr_ip_ext_s,
        rx_icmp_hdr_s,
        rx_icmp_opt_s,
        rx_icmp_tar_s,
        rx_data_write_s,
        rx_data_read_s,
        rx_tcp_hdr_s,
        rx_udp_hdr_s,
        rx_hdr_udp_s,
        rx_drop_s,
        rx_payload_s
    };

    enum tx_state_t
    {
        tx_IDLE,
        tx_pre_s,
        tx_hdr_eth_s,
        tx_hdr_ip_s,
        tx_ip_dst_s,
        tx_ip_src_s,
        tx_hdr_ip_pseudo_s,
        tx_icmp_hdr_s,
        tx_icmp_opt_s,
        tx_icmp_tar_s,
        tx_data_s,
        tx_crc_s,
        tx_ifg_s
    };

    enum err_t
    {
        err_none,
        err_bad_src_mac,
        err_bad_dst_mac,
        err_bad_ethertype,
        err_bad_src_ip,
        err_bad_dst_ip,
        err_bad_ip_proto,
        err_bad_icmp_target_ip,
        err_bad_icmp_type,
        err_icmp_bad_code,
        err_icmp_no_tar_ip,
        err_icmp_bad_tar
    };

    model_ifc_c(

    );

    ~model_ifc_c(

    ){};

    void display_error_message(
        err_t &err);

    err_t check_pkt_ns_dad(
        pkt_c::meta_t &meta,
        pkt_c::mac_t &mac);

    model_ifc_c::err_t check_pkt_rs(
        pkt_c::meta_t &meta,
        pkt_c::ip_t &ip,
        pkt_c::mac_t &mac);

    model_ifc_c::err_t check_pkt(
        const pkt_c::meta_t &meta,
        const uint8_t &proto,
        const uint8_t &typ,
        const pkt_c::ip_t &src_ip,
        const pkt_c::ip_t &dst_ip,
        const pkt_c::mac_t &src_mac,
        const pkt_c::mac_t &dst_mac);

    static icmp_state_t get_state_icmp(
        Vtop *tb);

    static rx_state_t get_state_rx(
        Vtop *tb);

    static tx_state_t get_state_tx(
        Vtop *tb);

    static void display_mac(
        const pkt_c::mac_t &mac);

    static void display_ip(
        const pkt_c::ip_t &ip);

    static pkt_c::mac_t get_mac(
        QData raw);

    static pkt_c::ip_t get_ip(
        const WData raw[4]);

    static pkt_c::ip_t get_ip(
        QData raw);

    static void set_ip(
        WData *raw,
        const pkt_c::ip_t ip);

    static void set_port(
        SData &raw,
        uint16_t port);

    static void set_str(
        WData *raw,
        const std::string str);

    static pkt_c::meta_mac_t get_meta_mac_rx(
        Vtop *tb);

    static pkt_c::meta_ip_t get_meta_ip_rx(
        Vtop *tb);

    static pkt_c::meta_icmp_t get_meta_icmp_rx(
        Vtop *tb);

    static pkt_c::meta_t get_meta_rx(
        Vtop *tb);

    bool meta_compare(
        const pkt_c::meta_t &dut,
        const pkt_c::meta_t &tb,
        const char *dir);

private:
};

#endif