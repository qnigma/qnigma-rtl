// TCP transmission control
// Accepts user data stream
// 1. Creates and manages packet info and payload
// 2. Handles retransmissions
// 3. Able to terminate connection if retransmissions failed
// 4. Assembles packets to be trasmitted and issues requests to qnigma_tx
module qnigma_tcp_tx_ctl 
  import
    qnigma_pkg::*;
(
  input  logic           clk      ,
  input  logic           rst      ,
  input  logic           ini      , // engine's sigal to initialize local seq from tcb
     
  input  logic [7:0]     dat      , // user tcp tx data
  input  logic           val      , // user tcp tx data valid
  output logic           cts      , // val is allowed to go high
  input  logic           frc      , // force forming a packet

  input  logic           flush    , // engine request to flush buffer (reset all info RAM to 0)
  output logic           flushed  , // tx_ctl response that RAM flush is complete
  input  tcb_t           tcb      , // engine's current transmission control block
  output logic           pld_val  , // TCP payload data valid
  output logic [7:0]     pld_dat  , // TCP payload data
  input  logic           pld_req  , // engine requests tcp payload at 

  input  logic [31:0]    dup_ack  , // duplicate ack number received
  input  logic           dup_det  , // dup_ack is valid, dup acks were received
  input  logic           soft_rst , // engine's request to reset transmission control
  output tcp_pld_info_t  pld_info , // current payload info to form a tcp packet. goes to tx_arb
  output logic           send     , // tx_ctl indicates a packet is ready for transmission
  input  logic           sent     , // engine reports that packet was sent
  output logic           force_dcn  // tx_ctl requests connection abort if retransmissions failed to increase remote seq
);

  logic                           info_full;      // info RAM is full (all entries are present and queued for transmission)
  logic                           data_full;      // data RAM is full. cannot accpet more payload in the queue
  logic                           upd;            // update entry in tcp_tx_info with 'upd_pkt_w' at 'upd_ptr'
  logic                           add_pend;       // packet is pending to be added to tcp_tx_info at new_pkt
  logic                           free;           // remove the fist entry (least seq num) from info RAM. always free packets in order             
  logic                           tx_idle;        // payload tranmission is idling
  logic                           add;            // request to add packet to tcp_tx_info
  logic                           tx_pend;        // tcp_tx_scan has a packet pending for transmission
  tcp_pkt_t                       new_pkt;        // new packet info 
  tcp_pkt_t                       upd_pkt_w;      // packet info for update
  tcp_pkt_t                       upd_pkt_r;      // read back from packt info from queue's RAM
  logic [TCP_TX_PACKET_DEPTH-1:0] upd_ptr;        // pointer write upd_pkt_w to
  logic [TCP_TX_RAM_DEPTH   -1:0] buf_addr;       // buffer address to read out user data
  logic                           buf_rst;        // reset data RAM module 

  // generate cts signal to user
  assign cts = (tcb.status == tcp_connected) && !info_full && !data_full;

  // add packet to queue
  // calculate checksum and packet info entry
  qnigma_tcp_tx_add tcp_tx_add_inst (
    .clk       (clk            ), //
    .rst       (soft_rst       ), //
    .mss       (tcb.mss        ), // MSS is used to 
    .seq       (tcb.loc_seq    ), // 
    .pkt       (new_pkt        ), // new packet to be added
    .add       (add            ), //
    .pend      (add_pend       ), //
    .full      (data_full      ), //
    .flush     (flush          ), //
    .val       (val            ), //
    .dat       (dat            ), //
    .frc       (frc            )  //
  );

  // packet information RAM
  // holds queued packets info 
  qnigma_tcp_tx_info #(
    .D (TCP_TX_PACKET_DEPTH)
  ) tcp_tx_info_inst (
    .clk       (clk            ),
    .rst       (soft_rst || ini),
    // new packets (tx_add)
    .new_pkt   (new_pkt        ), // New packet data
    .add       (add            ), // Add new_pkt to queue
    // update packets (tx_scan)
    .free      (free           ), // 
    .ptr       (upd_ptr        ),
    .pkt_w     (upd_pkt_w      ),
    .pkt_r     (upd_pkt_r      ),
    .upd       (upd            ),
    .full      (info_full      )
  );

  // scan and maintain info RAM entries 
  // issue retrasmissions
  // request to disconnect due to failed retransmission
  // update packet counters
  // keep track of number of retransmissions
  // calculate if packet is SACKed 
  qnigma_tcp_tx_scan tcp_tx_scan_inst (  
    .clk       (clk            ),
    .rst       (soft_rst || ini),
    .tcb       (tcb            ),
    .add_pend  (add_pend       ),
    // tx info RAM interface
    .upd       (upd            ),
    .del       (free           ),
    .ptr       (upd_ptr        ),
    .pkt_r     (upd_pkt_r      ),
    .pkt_w     (upd_pkt_w      ),
    .pld_info  (pld_info       ), 
    .pend      (tx_pend        ),
    .force_dcn (force_dcn      ),
    .flush     (flush          ),    
    .flushed   (flushed        ),  
    .dup_det   (dup_det        ),  
    .dup_ack   (dup_ack        ),
    .tx_idle   (tx_idle        )
  );

  // transmission stream from RAM 
  // handles only payload extraction
  // forms payload stream to be sent
  // when requested by qnigma_tx
  qnigma_tcp_tx_strm  #(
    .D (TCP_TX_RAM_DEPTH)
  ) tcp_tx_strm_inst (
    .clk       (clk            ),
    .rst       (soft_rst || ini),
    .pend      (tx_pend        ),
    .send      (send           ),
    .sent      (sent           ),
    .req       (pld_req        ), // payload request
    .addr      (buf_addr       ), // buffer address to read
    .idle      (tx_idle        ), // TCP is not transmitting payload
    .val       (pld_val        ), // payload valid to qnigma_tx. see pld_dat
    .seq       (pld_info.start ), // current payload packet start sequence
    .len       (pld_info.lng   )  // current payload packet stop sequence
  );

  // reset RAM module when initializing connection  
  always_ff @ (posedge clk) buf_rst <= ini;

  // transmission buffer RAM
  // Holds raw user data with address 
  // corresponding to each byte's seq num
  qnigma_tcp_tx_buf #(
    .D (TCP_TX_RAM_DEPTH),
    .W (8)
  ) tcp_tx_buf_inst (
    .clk       (clk            ),
    .rst       (buf_rst        ), // reset the RAM counters (but not the content)
    .data_in   (dat            ), // TCP raw data. todo: check is current pcaket overwrites data
    .write     (val            ), // TCP raw data valid
    .seq       (tcb.loc_seq    ), // local sequence number
    .ack       (tcb.rem_ack    ), // highest recorded remote ack number 
    .addr      (buf_addr       ), // address to read from
    .data_out  (pld_dat        ), // data at 'addr' (1 tick delay). Direct output to qnigma_tx. see pld_val
    .full      (data_full      ), // buffer cannot hold 1 more full pkt
    .empty     (               )  // completely empty. not used 
  );

endmodule : qnigma_tcp_tx_ctl
