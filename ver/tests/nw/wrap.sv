module wrap  
  import
    qnigma_pkg::*;
(
  input  logic               clk                     ,
  input  logic               rst                     ,
  input  logic               phy_rx_clk              ,
  input  logic               phy_rx_err              ,
  input  logic               phy_rx_val              ,
  input  logic       [7:0]   phy_rx_dat              ,  
  output logic               phy_tx_clk              ,
  output logic               phy_tx_err              ,
  output logic               phy_tx_val              ,
  output logic       [7:0]   phy_tx_dat              ,

  input  logic       [7:0]   tcp_dat_in              ,
  input  logic               tcp_val_in              ,
  output logic               tcp_cts_in              ,
  input  logic               tcp_frc_in              ,
  output logic       [7:0]   tcp_dat_out             ,
  output logic               tcp_val_out             ,
  input  logic       [127:0] tcp_rem_ip              ,
  input  logic       [15:0]  tcp_rem_port            ,
  input  logic       [15:0]  tcp_loc_port            ,
  
  input  logic       [255:0] tcp_hostname_str        ,
  input  logic       [7:0]   tcp_hostname_len        ,
  input  logic               tcp_connect_name        ,
  input  logic               tcp_connect_addr        ,
  input  logic               tcp_listen              ,
  input  logic               tcp_disconnect          ,
  output logic       [127:0] tcp_con_ip              ,
  output logic       [15:0]  tcp_con_port            ,
  
  output logic               tcp_status_idle         ,
  output logic               tcp_status_wait_dns     ,
  output logic               tcp_status_listening    ,
  output logic               tcp_status_connecting   ,
  output logic               tcp_status_connected    ,
  output logic               tcp_status_disconnecting,
  input  logic  [15:0]       udp_len                 ,
  input  logic  [7:0]        udp_din                 ,
  input  logic               udp_vin                 ,
  output logic               udp_cts                 ,
  output logic  [7:0]        udp_dout                ,
  output logic               udp_vout                ,
  input  logic  [15:0]       udp_loc_port            ,
  output logic  [127:0]      udp_ip_rx               ,
  output logic  [15:0]       udp_rem_port_rx         ,
  input  logic  [127:0]      udp_ip_tx               ,
  input  logic  [15:0]       udp_rem_port
);

  //////////////////////////
  // Synthsis localparams //
  //////////////////////////
  localparam int                        PARAM_MTU_MAX                   = MTU_DEFAULT;
  localparam int                        PARAM_IFG                       = IFG;
  localparam int                        PARAM_HOST_LEN                  = HOST_LEN;
  // TCP   
  localparam int                        PARAM_TCP_RETRANSMIT_TICKS      = TCP_RETRANSMIT_TICKS;
  localparam int                        PARAM_TCP_RETRANSMIT_TRIES      = TCP_RETRANSMIT_TRIES;
  localparam int                        PARAM_TCP_SACK_RETRANSMIT_TICKS = TCP_SACK_RETRANSMIT_TICKS;
  localparam int                        PARAM_TCP_FAST_RETRANSMIT_TICKS = TCP_FAST_RETRANSMIT_TICKS;
  localparam int                        PARAM_TCP_RX_RAM_DEPTH          = TCP_RX_RAM_DEPTH;
  localparam int                        PARAM_TCP_DEFAULT_WINDOW_SIZE   = TCP_DEFAULT_WINDOW_SIZE;
    
  localparam int                        PARAM_TCP_TX_RAM_DEPTH          = TCP_TX_RAM_DEPTH;
  localparam int                        PARAM_TCP_PACKET_DEPTH          = TCP_PACKET_DEPTH;
  localparam int                        PARAM_TCP_WAIT_TICKS            = TCP_WAIT_TICKS;
  localparam int                        PARAM_TCP_CONNECTION_TIMEOUT_MS = TCP_CONNECTION_TIMEOUT_MS;
  localparam int                        PARAM_TCP_DUP_ACKS              = TCP_DUP_ACKS;
  localparam int                        PARAM_TCP_FORCE_ACK_PACKETS     = TCP_FORCE_ACK_PACKETS;
  localparam int                        PARAM_TCP_KEEPALIVE_PERIOD_S    = TCP_KEEPALIVE_PERIOD_S;
  localparam int                        PARAM_TCP_KEEPALIVE_TRIES       = TCP_KEEPALIVE_TRIES;
  localparam bit                        PARAM_TCP_ENABLE_KEEPALIVE      = TCP_ENABLE_KEEPALIVE;
  
  localparam int                        PARAM_TCP_ACK_TIMEOUT_MS        = TCP_ACK_TIMEOUT_MS;
  localparam int                        PARAM_TCP_TX_PACKET_DEPTH       = TCP_TX_PACKET_DEPTH;

  localparam int                        PARAM_DNS_TIMEOUT_MS            = DNS_TIMEOUT_MS;
  localparam int                        PARAM_DNS_TRIES                 = DNS_TRIES;
  localparam int                        PARAM_UDP_HEADER_LEN            = UDP_HEADER_LEN;
  localparam int                        PARAM_DNS_HEADER_LEN            = DNS_HEADER_LEN;
  localparam int                        PARAM_DNS_QUERY_INFO_LEN        = DNS_QUERY_INFO_LEN;
  localparam int                        PARAM_DNS_ANSWER_INFO_LEN       = DNS_ANSWER_INFO_LEN;
  localparam [15:0]                     PARAM_DNS_DEFAULT_LOCAL_PORT    = DNS_DEFAULT_LOCAL_PORT;
  localparam [15:0]                     PARAM_DNS_QUERY_PORT            = DNS_QUERY_PORT;

  localparam int                        PARAM_MAC_RX_CDC_FIFO_DEPTH     = MAC_RX_CDC_FIFO_DEPTH;
  localparam int                        PARAM_MAC_RX_CDC_DELAY          = MAC_RX_CDC_DELAY;
  localparam int                        PARAM_TCP_SACK_BLOCKS           = TCP_SACK_BLOCKS;
  // ICMP

  localparam int                        PARAM_DAD_TRIES                 = DAD_TRIES;
  localparam int                        PARAM_MLD_TRIES                 = MLD_TRIES;
  localparam int                        PARAM_NDP_TRIES                 = NDP_TRIES;
  localparam int                        PARAM_RTR_TRIES                 = RTR_TRIES;
  localparam int                        PARAM_DAD_TIMEOUT_MS            = DAD_TIMEOUT_MS;
  localparam int                        PARAM_NDP_TIMEOUT_MS            = NDP_TIMEOUT_MS;
  localparam int                        PARAM_RTR_TIMEOUT_MS            = RTR_TIMEOUT_MS;

  localparam int                        PARAM_ICMP_ECHO_FIFO_DEPTH      = ICMP_ECHO_FIFO_DEPTH;

  localparam int                        TICKS_PER_MS                    = int'($ceil(REFCLK_HZ/1000));
  
  localparam [6:0]                      PARAM_PREFIX_LENGTH             = PREFIX_LENGTH;
  parameter mac_t                       PARAM_MAC_ADDR                  = {8'h18, 8'hcc, 8'h18, 8'h00, 8'hfa, 8'hce};
  
  hostname_t tcp_hostname;
  
  assign tcp_hostname.str = tcp_hostname_str; 
  assign tcp_hostname.lng = tcp_hostname_len; 

  qnigma #(
    .MAC_ADDR (PARAM_MAC_ADDR)
  )
  dut (
    .clk                      (clk                      ),
    .rst                      (rst                      ),
    .phy_rx_clk               (phy_rx_clk               ),
    .phy_rx_err               (phy_rx_err               ),
    .phy_rx_val               (phy_rx_val               ),
    .phy_rx_dat               (phy_rx_dat               ),  
    .phy_tx_clk               (phy_tx_clk               ),
    .phy_tx_err               (phy_tx_err               ),
    .phy_tx_val               (phy_tx_val               ),
    .phy_tx_dat               (phy_tx_dat               ),
    .tcp_dat_in               (tcp_dat_in               ),
    .tcp_val_in               (tcp_val_in               ),
    .tcp_cts_in               (tcp_cts_in               ),
    .tcp_frc_in               (tcp_frc_in               ),
    .tcp_dat_out              (tcp_dat_out              ),
    .tcp_val_out              (tcp_val_out              ),
    .tcp_rem_ip               (tcp_rem_ip               ),
    .tcp_rem_port             (tcp_rem_port             ),
    .tcp_loc_port             (tcp_loc_port             ),
    .tcp_hostname             (tcp_hostname             ),
    .tcp_connect_name         (tcp_connect_name         ),
    .tcp_connect_addr         (tcp_connect_addr         ),
    .tcp_disconnect           (tcp_disconnect           ),  
    .tcp_listen               (tcp_listen               ),
    .tcp_con_ip               (tcp_con_ip               ),
    .tcp_con_port             (tcp_con_port             ),
    .tcp_status_idle          (tcp_status_idle          ),
    .tcp_status_wait_dns      (tcp_status_wait_dns      ),
    .tcp_status_listening     (tcp_status_listening     ),
    .tcp_status_connecting    (tcp_status_connecting    ),
    .tcp_status_connected     (tcp_status_connected     ),
    .tcp_status_disconnecting (tcp_status_disconnecting ),
    .udp_len                  (udp_len                  ),
    .udp_din                  (udp_din                  ),
    .udp_vin                  (udp_vin                  ),
    .udp_cts                  (udp_cts                  ),
    .udp_dout                 (udp_dout                 ),
    .udp_vout                 (udp_vout                 ),
    .udp_loc_port             (udp_loc_port             ),
    .udp_ip_rx                (udp_ip_rx                ),
    .udp_rem_port_rx          (udp_rem_port_rx          ),
    .udp_ip_tx                (udp_ip_tx                ),
    .udp_rem_port             (udp_rem_port             )
  );

endmodule : wrap
