module qnigma
  import
    qnigma_pkg::*;
#(
  parameter mac_t MAC_ADDR = 0
)
(
  input logic         clk, // Internal 125 MHz
  input logic         rst, // Reset synchronous to clk
  // Phy interface
  input  logic        phy_rx_clk,
  input  logic        phy_rx_err,
  input  logic        phy_rx_val,
  input  logic [7:0]  phy_rx_dat,

  output logic        phy_tx_clk,
  output logic        phy_tx_err,
  output logic        phy_tx_val,
  output logic [7:0]  phy_tx_dat,
  // Raw UDP
  input  logic [15:0] udp_len, // data input
  input  logic [7:0]  udp_din, // data input
  input  logic        udp_vin, // data valid input
  output logic        udp_cts, // transmission clear to send. user has 1 tick to deassert vin before data is lost

  output logic [7:0]  udp_dout, // data output
  output logic        udp_vout, // data output valid
  // UDP control
  input  logic [15:0] udp_loc_port,
  output ip_t         udp_ip_rx,    
  output logic [15:0] udp_rem_port_rx,
  input  ip_t         udp_ip_tx,    
  input  logic [15:0] udp_rem_port,
  // Raw TCP
  input  logic [7:0]  tcp_dat_in, // data input
  input  logic        tcp_val_in, // data valid input
  output logic        tcp_cts_in, // transmission clear to send. user has 1 tick to deassert vin before data is lost
  input  logic        tcp_frc_in, // force transmission

  output logic [7:0]  tcp_dat_out, // data output
  output logic        tcp_val_out, // data output valid
  // TCP control
  input  ip_t         tcp_rem_ip,       // remote ip to connect to (valid with 'connect')
  input  hostname_t   tcp_hostname,     // remote ip to connect to (valid with 'connect')
  input  logic [15:0] tcp_rem_port,     // remote port to connect to (valid with 'connect')
  input  logic        tcp_connect_addr, // connect to rem_ip:rem_port by IPv6
  input  logic        tcp_connect_name, // connect to rem_ip:rem_port by hostname with DNS
  input  logic        tcp_disconnect,   // terminate connection
     
  input  logic [15:0] tcp_loc_port, // local port 
  input  logic        tcp_listen, // listen for incoming connection with any IP and port (valid with 'connect' and 'listen')
  output ip_t         tcp_con_ip, // remote ip that is currently connected
  output logic [15:0] tcp_con_port, // remote port that is currently connected
  output logic        tcp_status_idle,
  output logic        tcp_status_wait_dns,
  output logic        tcp_status_listening,
  output logic        tcp_status_connecting,
  output logic        tcp_status_connected,
  output logic        tcp_status_disconnecting
);
  parameter int REFCLK_HZ_PARAM = REFCLK_HZ;

  logic tick_ms, tick_s;
  assign tcp_status_idle          = tcp_status == tcp_closed;
  assign tcp_status_wait_dns      = tcp_status == tcp_wait_dns;
  assign tcp_status_listening     = tcp_status == tcp_listening;
  assign tcp_status_connecting    = tcp_status == tcp_connecting;
  assign tcp_status_connected     = tcp_status == tcp_connected;
  assign tcp_status_disconnecting = tcp_status == tcp_disconnecting;
  
  qnigma_cdc cdc_inst (
    // phy_rx_clk domain
    .clk_in     (phy_rx_clk),      // in
    .rst_in     (phy_rx_rst),      // in
    .data_in    (phy_rx_dat),      // in
    .valid_in   (phy_rx_val),      // in
    .error_in   (phy_rx_err),      // in
    // local clock domain
    .clk_out    (clk),             // in 
    .rst_out    (rst),             // in 
    .data_out   (phy_rx_sync_dat), // out
    .valid_out  (phy_rx_sync_val), // out
    .error_out  (phy_rx_sync_err)  // out
  );
  
  tcp_stat_t tcp_status;
  
  logic [7:0] icmp_pld_dat_rx;
  logic       icmp_pld_val_rx;
  
  logic [7:0] tcp_pld_dat_rx;
  logic       tcp_pld_val_rx;
  logic       tcp_pld_sof_rx;
  
  logic [7:0] tcp_pld_dat_tx;
  logic       tcp_pld_val_tx;
  
  logic [7:0] phy_rx_sync_dat;
  logic [7:0] phy_rx_sync_val;
  logic [7:0] phy_rx_sync_err;
  logic       phy_rx_rst;
  
  meta_mac_t       tx_meta_mac, rx_meta_mac;
  meta_ip_t        tx_meta_ip, rx_meta_ip;
  meta_icmp_t      tx_meta_icmp, rx_meta_icmp;
  meta_icmp_pres_t tx_meta_icmp_pres, rx_meta_icmp_pres;
  meta_tcp_t       tx_meta_tcp, rx_meta_tcp;
  meta_udp_t       tx_meta_udp, rx_meta_udp;
  meta_dns_t       tx_meta_dns, rx_meta_dns;
  meta_tcp_pres_t  tx_meta_tcp_pres, rx_meta_tcp_pres;
  
  logic icmp_pld_val_tx;
  logic [7:0] icmp_pld_dat_tx;
  logic icmp_pld_req_tx;
  logic tcp_pld_req_tx;
  logic tx_busy;

  proto_t rx_proto, tx_proto;
  logic tx_done;
  
  iid_t iid;
  pfx_t pfx;
  mac_t rtr_mac;
  
  logic send, rcv;
  
  logic ra_pend;
  logic ra_sent;
  
  logic [7:0] dns_idx;

  qnigma_rx #(
    .MAC_ADDR   (MAC_ADDR)
  ) rx_inst (
    .clk            (clk              ),
    .rst            (rst              ),
    .iid            (iid              ),
    .pfx            (pfx              ),
    .dns_idx        (dns_idx          ),
    .tcp_loc_port   (tcp_loc_port     ),
    .phy_dat        (phy_rx_sync_dat  ), // Synchronized phy rx
    .phy_val        (phy_rx_sync_val  ), // Synchronized phy rx
    .meta_mac       (rx_meta_mac      ),
    .meta_ip        (rx_meta_ip       ),
    .meta_icmp      (rx_meta_icmp     ),
    .meta_icmp_pres (rx_meta_icmp_pres),
    .meta_tcp       (rx_meta_tcp      ),
    .meta_tcp_pres  (rx_meta_tcp_pres ),
    .meta_udp       (rx_meta_udp      ),
    .meta_dns       (rx_meta_dns      ),
    .rcv            (rcv              ),
    .proto          (rx_proto         ),
    .icmp_pld_dat   (icmp_pld_dat_rx  ),
    .icmp_pld_val   (icmp_pld_val_rx  ),
    .tcp_pld_dat    (tcp_pld_dat_rx   ),
    .tcp_pld_val    (tcp_pld_val_rx   ),
    .tcp_pld_sof    (tcp_pld_sof_rx   )
  );

  qnigma_tx #(
    .MAC_ADDR      (MAC_ADDR)
  ) tx_inst (
    .clk            (clk              ),  
    .rst            (rst              ),  
    .iid            (iid              ),
    .pfx            (pfx              ),
    .rtr_mac        (rtr_mac          ),
    // to phy chip
    .phy_dat        (phy_tx_dat       ),
    .phy_val        (phy_tx_val       ),
    // packet metadata
    .meta_mac       (tx_meta_mac      ),
    .meta_ip        (tx_meta_ip       ),
    .meta_icmp      (tx_meta_icmp     ),
    .meta_icmp_pres (tx_meta_icmp_pres),
    .meta_tcp       (tx_meta_tcp      ),
    .meta_tcp_pres  (tx_meta_tcp_pres ),
    .meta_udp       (tx_meta_udp      ),
    .meta_dns       (tx_meta_dns      ),
    // controls
    .busy           (tx_busy          ),
    .send           (send             ),
    .proto          (tx_proto         ),
    .done           (tx_done          ),
    // payload
    .icmp_pld_dat   (icmp_pld_dat_tx  ),
    .icmp_pld_val   (icmp_pld_val_tx  ),
    .icmp_pld_req   (icmp_pld_req_tx  ),
    .tcp_pld_dat    (tcp_pld_dat_tx   ),
    .tcp_pld_val    (tcp_pld_val_tx   ),
    .tcp_pld_req    (tcp_pld_req_tx   )
  );
  
  qnigma_core #(
    .MAC_ADDR   (MAC_ADDR)
  ) core_inst (
    .clk               (clk               ),
    .rst               (rst               ),
    .tick_ms           (tick_ms           ),
    .tick_s            (tick_s            ),

    .iid               (iid               ),
    .pfx               (pfx               ),
    .rtr_mac           (rtr_mac           ),
    .rx_meta_mac       (rx_meta_mac       ),
    .rx_meta_ip        (rx_meta_ip        ),
    .rx_meta_icmp      (rx_meta_icmp      ),
    .rx_meta_icmp_pres (rx_meta_icmp_pres ),
    .rx_meta_tcp       (rx_meta_tcp       ),
    .rx_meta_udp       (rx_meta_udp       ),
    .rx_meta_dns       (rx_meta_dns       ),
    .rx_meta_tcp_pres  (rx_meta_tcp_pres  ),
    
    .rx_proto          (rx_proto          ),
    .rcv               (rcv               ),
    
    .tx_meta_mac       (tx_meta_mac       ),
    .tx_meta_ip        (tx_meta_ip        ),
    .tx_meta_icmp      (tx_meta_icmp      ),
    .tx_meta_icmp_pres (tx_meta_icmp_pres ),
    .tx_meta_tcp       (tx_meta_tcp       ),
    .tx_meta_udp       (tx_meta_udp       ),
    .tx_meta_dns       (tx_meta_dns       ),
    .tx_meta_tcp_pres  (tx_meta_tcp_pres  ),

    .tx_proto          (tx_proto          ),      
    .send              (send              ),
    .tx_busy           (tx_busy           ),
    .tx_done           (tx_done           ),

    .icmp_pld_req_tx   (icmp_pld_req_tx   ),
    .icmp_pld_val_tx   (icmp_pld_val_tx   ),
    .icmp_pld_dat_tx   (icmp_pld_dat_tx   ),
    .icmp_pld_val_rx   (icmp_pld_val_rx   ),
    .icmp_pld_dat_rx   (icmp_pld_dat_rx   ),
    // tcp received payload
    .tcp_pld_val_rx    (tcp_pld_val_rx    ),
    .tcp_pld_sof_rx    (tcp_pld_sof_rx    ),
    .tcp_pld_dat_rx    (tcp_pld_dat_rx    ),
    // tcp payload for transmission
    .tcp_pld_req_tx    (tcp_pld_req_tx    ),
    .tcp_pld_val_tx    (tcp_pld_val_tx    ),
    .tcp_pld_dat_tx    (tcp_pld_dat_tx    ),
    // tcp user ports 
    .tcp_dat_in        (tcp_dat_in        ),
    .tcp_val_in        (tcp_val_in        ),
    .tcp_cts_in        (tcp_cts_in        ),
    .tcp_frc_in        (tcp_frc_in        ),
    
    .tcp_dat_out       (tcp_dat_out       ),
    .tcp_val_out       (tcp_val_out       ),
    
    .tcp_connect_addr  (tcp_connect_addr  ),
    .tcp_connect_name  (tcp_connect_name  ),
    .tcp_disconnect    (tcp_disconnect    ),
    .tcp_hostname      (tcp_hostname      ),
    .tcp_listen        (tcp_listen        ),
    .tcp_rem_ip        (tcp_rem_ip        ),
    .tcp_rem_port      (tcp_rem_port      ),
    .tcp_loc_port      (tcp_loc_port      ),
    .tcp_con_port      (tcp_con_port      ),
    .tcp_con_ip        (tcp_con_ip        ),
    .tcp_status        (tcp_status        ),
    .dns_idx           (dns_idx           )
  );
  
  qnigma_tmr #( /* 1ms tick */
    .TICKS (REFCLK_HZ/1000),
    .AUTORESET (1)
  ) tmr_ms_inst (  
    .clk     (clk),
    .rst     (rst),
    .en      (1'b1),
    .tmr_rst (1'b0),
    .tmr     (tick_ms)
  );
  
  qnigma_tmr #( /* 1s tick */
    .TICKS (1000),
    .AUTORESET (1)
  ) tmr_s_inst (
    .clk     (clk),
    .rst     (rst),
    .en      (tick_ms),
    .tmr_rst (1'b0),
    .tmr     (tick_s)
  );

endmodule : qnigma
