// qnigma_core module
// Functions:
// - top-level of all procol logic modules
// - tx multiplexing for IP
// Intended for v6 use only without even support for ARP

module qnigma_core
  import 
    qnigma_pkg::*;
#(
  parameter mac_t MAC_ADDR = '0
)
(
  input logic             clk,
  input logic             rst,
  input logic             tick_ms,
  input logic             tick_s,


  output iid_t             iid,
  output pfx_t             pfx,
  output mac_t             rtr_mac,

  output logic [7:0]       dns_idx,

  // Received metadata
  input  meta_mac_t       rx_meta_mac,
  input  meta_ip_t        rx_meta_ip,
  input  meta_icmp_t      rx_meta_icmp,
  input  meta_icmp_pres_t rx_meta_icmp_pres,
  input  meta_tcp_t       rx_meta_tcp,
  input  meta_tcp_pres_t  rx_meta_tcp_pres,
  input  meta_udp_t       rx_meta_udp,
  input  meta_dns_t       rx_meta_dns,
  // Receive control
  input  proto_t          rx_proto,
  input  logic            rcv,
  // Metadata for transmission
  output meta_mac_t       tx_meta_mac,
  output meta_ip_t        tx_meta_ip,
  output meta_icmp_t      tx_meta_icmp,
  output meta_icmp_pres_t tx_meta_icmp_pres,
  output meta_tcp_t       tx_meta_tcp,
  output meta_tcp_pres_t  tx_meta_tcp_pres,
  output meta_udp_t       tx_meta_udp,
  output meta_dns_t       tx_meta_dns,
  // Transmit control
  output proto_t          tx_proto,
  output logic            send,
  input  logic            tx_done,
  input  logic            tx_busy,
  // ICMP echo related 
  input  logic            icmp_pld_req_tx,
  output logic            icmp_pld_val_tx,
  output logic [7:0]      icmp_pld_dat_tx,
  input  logic            icmp_pld_val_rx,
  input  logic [7:0]      icmp_pld_dat_rx,
  // Transmitted TCP payload from buffer
  input  logic            tcp_pld_req_tx,
  output logic            tcp_pld_val_tx,
  output logic [7:0]      tcp_pld_dat_tx,
  // Received TCP payload to buffer
  input logic             tcp_pld_sof_rx,
  input logic             tcp_pld_val_rx,
  input logic [7:0]       tcp_pld_dat_rx,
  // TCP payload (user input/output stream)
  input  logic [7:0]      tcp_dat_in,
  input  logic            tcp_val_in,
  output logic            tcp_cts_in,
  input  logic            tcp_frc_in,
  output logic [7:0]      tcp_dat_out,
  output logic            tcp_val_out,
  // TCP controls
  input  hostname_t       tcp_hostname,
  input  logic            tcp_connect_name,
  input  logic            tcp_connect_addr,
  input  logic            tcp_listen,
  input  logic            tcp_disconnect,
  input  ip_t             tcp_rem_ip,
  input  logic [15:0]     tcp_rem_port,
  input  logic [15:0]     tcp_loc_port,
  output logic [15:0]     tcp_con_port,
  output ip_t             tcp_con_ip,
  output tcp_stat_t       tcp_status
);

  meta_mac_t tx_meta_mac_tcp;
  meta_mac_t mac_tx_meta_icmp;
  meta_mac_t mac_tx_meta_dns;

  meta_ip_t tx_meta_ip_tcp;
  meta_ip_t ip_tx_meta_icmp;
  meta_ip_t ip_tx_meta_dns;

  logic tx_acpt_icmp;
  logic tx_acpt_tcp;
  logic tx_acpt_dns;

  logic icmp_ns_req;
  logic icmp_ns_err;
  logic icmp_ns_acc;
  ip_t  icmp_ip_req;
  mac_t icmp_mac_rsp;
  logic icmp_rsp_ok;

  logic tx_done_icmp;
  logic tx_done_tcp;
  logic tx_done_dns;

  logic val;
  logic done;

  logic  dns_host_req;
  logic  dns_host_acc;
  ip_t   dns_host_addr;
  logic  dns_err;
  logic dns_host_val;
  logic dns_host_err;
  logic tx_pend_icmp, tx_pend_tcp, tx_pend_dns;
  
  logic dns_avl;

  // Info from RA 
  logic               pfx_avl;
  ip_t                dns_ip;
  logic               dns_pres;
  logic               dns_val;
  ip_t                rtr_ip;
  logic               rtr_det;

  logic [15:0]        mtu;
  logic rcv_icmp;
  logic rcv_tcp;
  logic rcv_dns;
  
  logic dns_rs_send;

  qnigma_icmp #(
    .MAC_ADDR (MAC_ADDR)
  ) icmp_inst (
    .clk              (clk              ),   
    .rst              (rst              ),
    .tick_ms          (tick_ms          ),
    .tick_s           (tick_s           ),
    // Address
    .iid              (iid              ),
    .pfx              (pfx              ),
    .pfx_avl          (pfx_avl          ),
    // DNS control
    .dns_ip           (dns_ip           ),
    .dns_pres         (dns_pres         ),
    .dns_avl          (dns_avl          ),
    .dns_rs_send      (dns_rs_send      ),
    // Router information
    .rtr_ip           (rtr_ip           ),
    .rtr_mac          (rtr_mac          ),
    .rtr_det          (rtr_det          ),
    .mtu              (mtu              ),
    // Information provided by ICMP
    // Metadata receive
    .rx_meta_mac      (rx_meta_mac      ),
    .rx_meta_ip       (rx_meta_ip       ),
    .rx_meta_icmp     (rx_meta_icmp     ),
    .rx_meta_icmp_pres(rx_meta_icmp_pres),
    .rcv              (rcv_icmp         ),
    // ICMP optional data receive
    .pld_dat_rx       (icmp_pld_dat_rx  ),
    .pld_val_rx       (icmp_pld_val_rx  ),
    // Metadata transmit
    .tx_meta_mac      (mac_tx_meta_icmp ),
    .tx_meta_ip       (ip_tx_meta_icmp  ),
    .tx_meta_icmp     (tx_meta_icmp     ),
    .tx_meta_icmp_pres(tx_meta_icmp_pres),
    .tx_pend          (tx_pend_icmp     ),
    .tx_done          (tx_done_icmp     ),
    .tx_acpt          (tx_acpt_icmp     ),
    // ICMO optional data transmit
    .pld_dat_tx       (icmp_pld_dat_tx  ),
    .pld_val_tx       (icmp_pld_val_tx  ),
    .echo_req_tx      (icmp_pld_req_tx  ),
    .ns_req           (icmp_ns_req      ),
    .ns_err           (icmp_ns_err      ),
    .ns_acc           (icmp_ns_acc      ),
    .ip_req           (icmp_ip_req      ),
    .mac_rsp          (icmp_mac_rsp     ),
    .rsp_ok           (icmp_rsp_ok      )
  );

  qnigma_tcp tcp_inst (
    .clk             (clk               ),
    .rst             (rst               ),
    .tick_ms         (tick_ms           ),
    .tick_s          (tick_s            ),
    .rtr_det         (rtr_det           ),
    .pfx_avl         (pfx_avl           ),
    .dns_avl         (dns_avl           ),
    // MTU from RA option
    .mtu             (mtu               ),
    // Metadata receive
    .rx_meta_mac     (rx_meta_mac       ),
    .rx_meta_ip      (rx_meta_ip        ),
    .rx_meta_tcp     (rx_meta_tcp       ),
    .rx_meta_tcp_pres(rx_meta_tcp_pres  ),
    .rcv             (rcv_tcp           ),
    // Metadata transmit
    .tx_meta_mac     (tx_meta_mac_tcp   ),
    .tx_meta_ip      (tx_meta_ip_tcp    ),
    .tx_meta_tcp     (tx_meta_tcp       ),
    .tx_meta_tcp_pres(tx_meta_tcp_pres  ),
    .tx_pend         (tx_pend_tcp       ),
    .tx_acpt         (tx_acpt_tcp       ),
    .tx_done         (tx_done_tcp       ),
    .pld_req_tx      (tcp_pld_req_tx    ),
    .pld_val_tx      (tcp_pld_val_tx    ),
    .pld_dat_tx      (tcp_pld_dat_tx    ),
    .pld_sof_rx      (tcp_pld_sof_rx    ),
    .pld_val_rx      (tcp_pld_val_rx    ),
    .pld_dat_rx      (tcp_pld_dat_rx    ),
    // NS request to discover MAC
    .icmp_ns_req     (icmp_ns_req       ),
    .icmp_ns_err     (icmp_ns_err       ),
    .icmp_ns_acc     (icmp_ns_acc       ),
    .icmp_ip_req     (icmp_ip_req       ),
    .icmp_mac_rsp    (icmp_mac_rsp      ),
    .icmp_rsp_ok     (icmp_rsp_ok       ),

    .dat_in          (tcp_dat_in        ),
    .val_in          (tcp_val_in        ),
    .cts_in          (tcp_cts_in        ),
    .frc_in          (tcp_frc_in        ),

    .dat_out         (tcp_dat_out       ),
    .val_out         (tcp_val_out       ),

    .connect_addr    (tcp_connect_addr  ),
    .connect_name    (tcp_connect_name  ),
    .listen          (tcp_listen        ),
    .disconnect      (tcp_disconnect    ),
    .rem_ip          (tcp_rem_ip        ),
    .rem_port        (tcp_rem_port      ),
    .loc_port        (tcp_loc_port      ),
    .con_port        (tcp_con_port      ),
    .con_ip          (tcp_con_ip        ),
    .dns_host_req    (dns_host_req      ),
    .dns_host_acc    (dns_host_acc      ),
    .dns_host_addr   (dns_host_addr     ),
    .dns_val         (dns_host_val      ),
    .dns_err         (dns_host_err      ),
    .status          (tcp_status        )
  );

  qnigma_dns dns_inst (
    .clk              (clk              ),
    .rst              (rst              ),
    .tick_ms          (tick_ms          ),
    .tick_s           (tick_s           ),
    
    .dns_avl          (dns_avl          ),   
    .dns_pres         (dns_pres         ),  
    .dns_ip           (dns_ip           ), 
    .dns_idx          (dns_idx          ),

    .hostname         (tcp_hostname     ),
    .req              (dns_host_req     ),
    .acc              (dns_host_acc     ),
    .val              (dns_host_val     ),
    .err              (dns_host_err     ),
    .addr             (dns_host_addr    ),
    // Metadata receive
    .rx_meta_mac      (rx_meta_mac      ),
    .rx_meta_ip       (rx_meta_ip       ),
    .rx_meta_udp      (rx_meta_udp      ),
    .rx_meta_dns      (rx_meta_dns      ),
    .rcv              (rcv_dns          ),
    // Metadata transmit
    .tx_meta_mac      (mac_tx_meta_dns  ),
    .tx_meta_ip       (ip_tx_meta_dns   ),
    .tx_meta_udp      (tx_meta_udp      ),
    .tx_meta_dns      (tx_meta_dns      ),
    .tx_pend          (tx_pend_dns      ),
    .tx_acpt          (tx_acpt_dns      ),
    .tx_done          (tx_done_dns      ),
    // Request Router infoemation update
    .rs_send          (dns_rs_send      )
  );


  assign rcv_icmp = rcv && rx_proto == icmp;
  assign rcv_tcp  = rcv && rx_proto == tcp;
  assign rcv_dns  = rcv && rx_proto == dns;

  always_ff @ (posedge clk) begin
    if (!tx_busy) begin
      if (tx_pend_icmp) begin
        send         <= 1;
        tx_proto     <= icmp;
        tx_acpt_icmp <= 1;
      end
      else if (tx_pend_tcp) begin
        send         <= 1;
        tx_proto     <= tcp;
        tx_acpt_tcp  <= 1;
      end
      else if (tx_pend_dns) begin
        send         <= 1;
        tx_proto     <= dns;
        tx_acpt_dns  <= 1;
      end
    end
    else begin
      send         <= 0;
      tx_acpt_icmp <= 0;
      tx_acpt_tcp  <= 0;
      tx_acpt_dns  <= 0;
    end
  end

  always_comb begin
    case (tx_proto)
      icmp : begin
        tx_meta_mac  = mac_tx_meta_icmp;
        tx_meta_ip   = ip_tx_meta_icmp;
        tx_done_icmp = tx_done;
        tx_done_tcp  = 0;
        tx_done_dns  = 0;
      end
      tcp : begin
        tx_meta_mac  = tx_meta_mac_tcp;
        tx_meta_ip   = tx_meta_ip_tcp;
        tx_done_icmp = 0;
        tx_done_tcp  = tx_done;
        tx_done_dns  = 0;
      end
      dns : begin
        tx_meta_mac  = mac_tx_meta_dns;
        tx_meta_ip   = ip_tx_meta_dns;
        tx_done_icmp = 0;
        tx_done_tcp  = 0;
        tx_done_dns  = tx_done;
      end
      default : begin
        tx_meta_mac  = mac_tx_meta_icmp;
        tx_meta_ip   = ip_tx_meta_icmp;
        tx_done_icmp = 0;
        tx_done_tcp  = 0;
        tx_done_dns  = 0;
      end
    endcase
  end

endmodule : qnigma_core
