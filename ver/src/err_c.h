#ifndef ERR_C_H
#define ERR_C_H

#define COLOR_RED "\x1b[31m"
#define COLOR_GREEN "\x1b[32m"
#define COLOR_YELLOW "\x1b[33m"
#define COLOR_BLUE "\x1b[34m"
#define COLOR_MAGENTA "\x1b[35m"
#define COLOR_CYAN "\x1b[36m"
#define COLOR_RESET "\x1b[0m"

class err_c
{

public:
  enum err_pkt_flt_t
  {
    pkt_rx_no_error,
    pkt_rx_err_timeout,
    pkt_rx_ignored
  };

  enum err_dad_mld_t
  {
    dad_mld_no_error,
    dad_mld_err_timeout,
    dad_mld_err_dst_mac_mismatch,
    dad_mld_err_src_mac_mismatch,
    dad_mld_err_src_ip_mismatch,
    dad_mld_err_bad_ip_length,
    dad_mld_err_bad_icmp_code,
    dad_mld_err_target_ip_not_present,
    dad_mld_err_target_ip,
    dad_mld_err_mtu_option_present,
    dad_mld_err_pfx_option_present,
    dad_mld_err_rdnss_option_present,
    dad_mld_err_src_lnka_option_present,
    dad_mld_err_tar_lnka_option_present,
    dad_mld_err_aux_dat_len_not_zero,
    dad_mld_err_mld_addr_mismatch,
    dad_mld_err_mld_number_of_sources_not_zero,
    dad_mld_err_mld_bad_rec_type,
    dad_mld_err_pld_pres,
    dad_mld_err_failed_to_set_lla,
    dad_mld_err_wrong_lla
  };

  enum err_nd_t
  {
    nd_no_error,
    nd_err_timeout,
    nd_err_dst_mac_mismatch,
    nd_err_src_mac_mismatch,
    nd_err_dst_ip_mismatch,
    nd_err_src_ip_mismatch,
    nd_err_tar_ip_mismatch,
    nd_err_bad_ip_length,
    nd_err_bad_icmp_code,
    nd_err_target_ip_not_present,
    nd_err_mtu_option_present,
    nd_err_pfx_option_present,
    nd_err_rdnss_option_present,
    nd_err_src_lnka_option_present,
    nd_err_tar_lnka_option_present,
    nd_err_icmp_bad_state
  };

  enum err_echo_t
  {
    echo_no_error,
    echo_err_timeout,
    echo_err_dst_mac_mismatch,
    echo_err_src_mac_mismatch,
    echo_err_dst_ip_mismatch,
    echo_err_src_ip_mismatch,
    echo_err_bad_ip_length,
    echo_err_bad_icmp_code,
    echo_err_target_ip_present,
    echo_err_mtu_option_present,
    echo_err_pfx_option_present,
    echo_err_rdnss_option_present,
    echo_err_src_lnka_option_present,
    echo_err_tar_lnka_option_present,
    echo_err_pld_mismatch,
    echo_err_icmp_bad_state
  };

  enum err_rtr_t
  {
    rtr_no_error,
    rtr_err_timeout,
    rtr_err_rs_timeout,
    rtr_err_set_timeout,
    rtr_err_dst_mac_mismatch,
    rtr_err_src_mac_mismatch,
    rtr_err_src_ip_mismatch,
    rtr_err_bad_ip_length,
    rtr_err_bad_icmp_code,
    rtr_err_target_ip_present,
    rtr_err_target_ip_mismatch,
    rtr_err_mtu_option_present,
    rtr_err_pfx_option_present,
    rtr_err_rdnss_option_present,
    rtr_err_src_lnka_option_present,
    rtr_err_tar_lnka_option_present,
    rtr_err_pld_present,
    rtr_err_bad_state,
    rtr_err_router_lifetime_mismatch,
    rtr_err_rdnss_valid_lifetime_mismatch,
    rtr_prefix_valid_lifetime_mismatch,
    rtr_err_mtu_mismatch,
    rtr_err_unexpected_prefix_information_option,
    rtr_err_unexpected_rdnss_option,
    rtr_err_unexpected_mtu_option,
    rtr_err_no_prefix_information_option,
    rtr_err_no_rdnss_option,
    rtr_err_no_mtu_option
  };

  enum err_tcp_t
  {
    tcp_no_error,
    tcp_err_con_timeout,
    tcp_err_dcn_timeout,
    tcp_err_ack_timeout,
    tcp_err_acked_unseen,
    tcp_err_rx_mismatch,
    tcp_err_tx_mismatch
  };

  static void display_result(err_tcp_t &err)
  {
    switch (err)
    {
    case tcp_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case tcp_err_con_timeout:
    {
      printf("TCP connection timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case tcp_err_dcn_timeout:
    {
      printf("TCP disconnect timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case tcp_err_ack_timeout:
    {
      printf("TCP Ack timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case tcp_err_acked_unseen:
    {
      printf("TCP Acked unseen segment" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case tcp_err_rx_mismatch:
    {
      printf("TCP rx payload mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case tcp_err_tx_mismatch:
    {
      printf("TCP tx payload mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    }
  }

  err_c(){};
  ~err_c(){};

  static void display_result(err_dad_mld_t &err)
  {
    switch (err)
    {
    case dad_mld_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_timeout:
    {
      printf("Neighbor Discovery Timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_dst_mac_mismatch:
    {
      printf("Neighbor Discovery reply destination MAC mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_src_mac_mismatch:
    {
      printf("Neighbor Discovery reply source MAC mismatch " COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_src_ip_mismatch:
    {
      printf("Neighbor Discovery reply source IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_bad_ip_length:
    {
      printf("Neighbor Discovery reply Bad IP length" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_bad_icmp_code:
    {
      printf("Neighbor Discovery reply bad ICMP code" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_target_ip_not_present:
    {
      printf("Neighbor Discovery Target IP not present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_target_ip:
    {
      printf("Neighbor Discovery bad Target IP" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_mtu_option_present:
    {
      printf("Neighbor Discovery reply MTU option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_pfx_option_present:
    {
      printf("Neighbor Discovery reply Prefix option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_rdnss_option_present:
    {
      printf("Neighbor Discovery reply RDNSS option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_src_lnka_option_present:
    {
      printf("Neighbor Discovery reply unexpected Source link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_tar_lnka_option_present:
    {
      printf("Neighbor Discovery reply unexpected Target link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }

    case dad_mld_err_aux_dat_len_not_zero:
    {
      printf("Neighbor Discovery MLDv2 packet: auxilary data length field no zero" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }

    case dad_mld_err_mld_addr_mismatch:
    {
      printf("Neighbor Discovery MLDv2 packet: Multicast address mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }

    case dad_mld_err_mld_number_of_sources_not_zero:
    {
      printf("Neighbor Discovery MLDv2 packet: Multicast recored number of sources not zero" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_mld_bad_rec_type:
    {
      printf("Neighbor Discovery MLDv2 packet: Bad record type" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_pld_pres:
    {
      printf("Neighbor Discovery unexpected payload" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_wrong_lla:
    {
      printf("Neighbor Discovery LLA does not match expected" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case dad_mld_err_failed_to_set_lla:
    {
      printf("Neighbor Discovery failed to set LLA" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    default:
      printf("Neighbor Discovery unknown error" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
  }

  static void display_result(err_nd_t &err)
  {
    switch (err)
    {
    case nd_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case nd_err_timeout:
    {
      printf("Neighbor Discovery timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_dst_mac_mismatch:
    {
      printf("Neighbor Discovery reply destination MAC mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_src_mac_mismatch:
    {
      printf("Neighbor Discovery reply source MAC mismatch " COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_dst_ip_mismatch:
    {
      printf("Neighbor Discovery reply destination IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_src_ip_mismatch:
    {
      printf("Neighbor Discovery reply source IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_bad_ip_length:
    {
      printf("Neighbor Discovery reply Bad IP length" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_bad_icmp_code:
    {
      printf("Neighbor Discovery reply bad ICMP code" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_target_ip_not_present:
    {
      printf("Neighbor Discovery reply no target IP present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_tar_ip_mismatch:
    {
      printf("Neighbor Discovery target IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_mtu_option_present:
    {
      printf("Neighbor Discovery reply MTU option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_pfx_option_present:
    {
      printf("Neighbor Discovery reply Prefix option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_rdnss_option_present:
    {
      printf("Neighbor Discovery reply RDNSS option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_src_lnka_option_present:
    {
      printf("Neighbor Discovery reply unexpected Source link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_tar_lnka_option_present:
    {
      printf("Neighbor Discovery reply unexpected Terget link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case nd_err_icmp_bad_state:
    {
      printf("Neighbor Discovery test ended in bad ICMP FSM state" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
    default:
      printf("Neighbor Discovery unknown error" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
  }

  static void display_result(err_echo_t &err)
  {
    switch (err)
    {
    case echo_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case echo_err_timeout:
    {
      printf("Echo timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_dst_mac_mismatch:
    {
      printf("Echo reply destination MAC mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_src_mac_mismatch:
    {
      printf("Echo reply source MAC mismatch " COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_dst_ip_mismatch:
    {
      printf("Echo reply destination IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_src_ip_mismatch:
    {
      printf("Echo reply source IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_bad_ip_length:
    {
      printf("Echo reply Bad IP length" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_bad_icmp_code:
    {
      printf("Echo reply bad ICMP code" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_target_ip_present:
    {
      printf("Echo reply unexpected target IP present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_mtu_option_present:
    {
      printf("Echo reply MTU option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_pfx_option_present:
    {
      printf("Echo reply Prefix option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_rdnss_option_present:
    {
      printf("Echo reply RDNSS option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_src_lnka_option_present:
    {
      printf("Echo reply unexpected Source link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_tar_lnka_option_present:
    {
      printf("Echo reply unexpected Terget link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_pld_mismatch:
    {
      printf("Echo payload mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case echo_err_icmp_bad_state:
    {
      printf("Echo test ended in bad ICMP FSM state" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
    default:
      printf("Echo unknown error" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
  }

  static void display_result(err_rtr_t &err)
  {
    switch (err)
    {

    case rtr_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case rtr_err_set_timeout:
    {
      printf("Router Advertisement was not processed in time" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_rs_timeout:
    {
      printf("Did not receive Router Solicitation in time" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_dst_mac_mismatch:
    {
      printf("Router Solicitation reply destination MAC mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_src_mac_mismatch:
    {
      printf("Router Solicitation reply source MAC mismatch " COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_src_ip_mismatch:
    {
      printf("Router Solicitation reply source IP mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_bad_ip_length:
    {
      printf("Router Solicitation reply Bad IP length" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_bad_icmp_code:
    {
      printf("Router Solicitation reply bad ICMP code" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_target_ip_present:
    {
      printf("Router Solicitation reply unexpected target IP present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_mtu_option_present:
    {
      printf("Router Solicitation reply MTU option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_pfx_option_present:
    {
      printf("Router Solicitation reply Prefix option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_rdnss_option_present:
    {
      printf("Router Solicitation reply RDNSS option present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_src_lnka_option_present:
    {
      printf("Router Solicitation reply unexpected Source link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_tar_lnka_option_present:
    {
      printf("Router Solicitation reply unexpected Terget link-layer address present" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_pld_present:
    {
      printf("Router Solicitation unexpected payload" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_bad_state:
    {
      printf("Router Solicitation ended in bad ICMP FSM state" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_router_lifetime_mismatch:
    {
      printf("Router Solicitation router valid lifetime mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_rdnss_valid_lifetime_mismatch:
    {
      printf("Router Solicitation RDNSS valid lifetime mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_prefix_valid_lifetime_mismatch:
    {
      printf("Router Solicitation prefix valid lifetime mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_mtu_mismatch:
    {
      printf("Router Solicitation MTU option value mismatch" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_unexpected_prefix_information_option:
    {
      printf("Router Solicitation Unexpected Prefix Information option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_unexpected_rdnss_option:
    {
      printf("Router Solicitation Unexpected RDNSS option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_unexpected_mtu_option:
    {
      printf("Router Solicitation Unexpected MTU option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_no_prefix_information_option:
    {
      printf("Router Solicitation no Prefix Information option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_no_rdnss_option:
    {
      printf("Router Solicitation no RDNSS option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case rtr_err_no_mtu_option:
    {
      printf("Router Solicitation no MTU option" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    default:
      printf("Router Solicitation unknown error" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
  }

  static void display_result(err_pkt_flt_t &err)
  {
    switch (err)
    {
    case pkt_rx_no_error:
    {
      printf(COLOR_GREEN "[ OK ]\n" COLOR_RESET);
      break;
    }
    case pkt_rx_err_timeout:
    {
      printf("Packet Parse Test timeout" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    case pkt_rx_ignored:
    {
      printf("Packet Parse Test Good packet ignored" COLOR_RED " [FAIL]\n" COLOR_RESET);
      break;
    }
    default:
      printf("Packet Parse Test unknown error" COLOR_RED " [FAIL]\n" COLOR_RESET);
    }
  }
};
#endif