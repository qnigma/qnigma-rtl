
module qnigma_dns 
  import 
    qnigma_pkg::*;
(
  input logic                     clk,
  input logic                     rst,
  input logic                     tick_ms,
  input logic                     tick_s,
  // DNS configuration
  input logic                     dns_avl,  // DNS server available from RA RDNSS option
  input logic                     dns_pres, // DNS IP present from RA RDNSS option
  input ip_t                      dns_ip,   // DNS IP value from RA RDNSS option
  output logic [7:0]              dns_idx,
  // request for hostname
  input hostname_t                hostname,
  input logic                     req,
  output logic                    acc,
  output logic                    err,
  output logic                    val,
  output ip_t                     addr,
  // receive interface
  input  meta_mac_t               rx_meta_mac,
  input  meta_ip_t                rx_meta_ip,
  input  meta_udp_t               rx_meta_udp,
  input  meta_dns_t               rx_meta_dns,
  input  logic                    rcv,
  // tranmsit interface
  output meta_mac_t               tx_meta_mac,
  output meta_ip_t                tx_meta_ip,
  output meta_udp_t               tx_meta_udp,
  output meta_dns_t               tx_meta_dns,
  output logic                    tx_pend,
  input  logic                    tx_acpt,
  input  logic                    tx_done,
  // update DNS IP
  output logic                    rs_send
);
  parameter [15:0] DEFAULT_TID = 12345;

  enum logic [3:0] {
    IDLE,
    shift_str_s,
    REQUEST,
    RESPOND,
    NEXT_SERV
  } state;

  logic [$clog2(DNS_TIMEOUT_MS +1)-1:0] tmr;
  logic [$clog2(DNS_TRIES      +1)-1:0] try;
  
  always_ff @ (posedge clk) begin
    if (rst) begin
      state           <= IDLE;
      err             <= 0;
      val             <= 0;
      acc             <= 0;
      tx_pend         <= 0;
      tmr             <= 0;
      try             <= 0;
      tx_meta_dns.tid <= DEFAULT_TID;
      dns_idx         <= 0;
    end
    else begin
      // constant fields for DNS
      tx_meta_ip.hop      <= 64;
      tx_meta_ip.pro      <= UDP;
      tx_meta_ip.loc_ref  <= ref_ip_glb;
      tx_meta_ip.rem      <= (dns_avl) ? dns_ip : DNS_IP_ADDR_PRI;
      tx_meta_ip.lng      <= UDP_HEADER_LEN + DNS_HEADER_LEN + DNS_QUERY_INFO_LEN + hostname.lng + 1;
      tx_meta_udp.src     <= DNS_DEFAULT_LOCAL_PORT;
      tx_meta_udp.dst     <= DNS_QUERY_PORT;
      tx_meta_udp.lng     <= UDP_HEADER_LEN + DNS_HEADER_LEN + DNS_QUERY_INFO_LEN + hostname.lng + 1;
      tx_meta_dns.tid     <= DEFAULT_TID;
      tx_meta_dns.flg     <= 16'h0100;
      tx_meta_dns.num     <= 1;
      tx_meta_dns.ans     <= 0;
      tx_meta_dns.aut     <= 0;
      tx_meta_dns.add     <= 0;
      tx_meta_dns.inf.cls <= 1;
      tx_meta_dns.inf.typ <= 28;
      
      // state machine
      case (state)
        IDLE : begin
          if (req) state      <= REQUEST; // requested name resolution
          tx_meta_dns.hst.str <= hostname.str;
          tx_meta_dns.hst.lng <= hostname.lng;
          rs_send             <= 0;
          acc                 <= 0;
          val                 <= 0;
        end
        REQUEST : begin // send a query to DNS server
          err     <= 0;
          acc     <= 1; // accepted NS request
          tx_pend <= 1;
          tmr     <= 0;
          try     <= try + 1;
          state   <= RESPOND;
        end
        RESPOND : begin // wait for DNS server to resond
          if (tx_acpt) tx_pend <= 0;
          if (tick_ms) tmr <= tmr + 1;
          if (tmr == DNS_TIMEOUT_MS) begin // DNS query timeout
            state <= (try == DNS_TRIES) ? NEXT_SERV : REQUEST; // Tried several times, but no reply -> abort
            if (try == DNS_TRIES) err <= 1;
          end
          else if (rcv && rx_meta_udp.src == DNS_QUERY_PORT) begin
            state <= IDLE;
            val   <= 1;
            addr  <= rx_meta_dns.addr;
          end
        end
        NEXT_SERV : begin // DNS failed, set next DNS entry to exctract from RA
          dns_idx <= (dns_idx == MAX_DNS_SRV-1) ? 0 : dns_idx; // increment the index of IP to be extracted from RDNSS option
          rs_send <= 1; // request new RA to select next DNS IP from ir
          state   <= IDLE;
        end
        default :;
      endcase
    end
  end


endmodule : qnigma_dns
