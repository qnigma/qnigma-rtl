package qnigma_mdio_pkg;



  typedef struct packed {
    logic [4 :0] addr;
    logic        wr_perm;
  } reg_t;

  localparam [4:0] ADDR_BMCR   = 5'd0;  // | RW | Basic Mode Control Register.
  localparam [4:0] ADDR_BMSR   = 5'd1;  // | RO | Basic Mode Status Register.
  localparam [4:0] ADDR_PHYID1 = 5'd2;  // | RO | PHY Identifier Register 1.
  localparam [4:0] ADDR_PHYID2 = 5'd3;  // | RO | PHY Identifier Register 2.
  localparam [4:0] ADDR_ANAR   = 5'd4;  // | RW | Auto-Negotiation Advertising Register.
  localparam [4:0] ADDR_ANLPAR = 5'd5;  // | RW | Auto-Negotiation Link Partner Ability Register.
  localparam [4:0] ADDR_ANER   = 5'd6;  // | RW | Auto-Negotiation Expansion Register.
  localparam [4:0] ADDR_ANNPTR = 5'd7;  // | RW | Auto-Negotiation Next Page Transmit Register.
  localparam [4:0] ADDR_ANNPRR = 5'd8;  // | RW | Auto-Negotiation Next Page Receive Register.
  localparam [4:0] ADDR_GBCR   = 5'd9;  // | RW | 1000Base-T Control Register.
  localparam [4:0] ADDR_GBSR   = 5'd10; // | RO | 1000Base-T Status Register.
  localparam [4:0] ADDR_MACR   = 5'd13; // | WO | MMD Access Control Register.
  localparam [4:0] ADDR_MAADR  = 5'd14; // | RW | MMD Access Address Data Register. 
  localparam [4:0] ADDR_GBESR  = 5'd15; // | RO | 1000Base-T Extended Status Register.
  localparam [4:0] ADDR_PHYCR  = 5'd16; // | RW | PHY Specific Control Register.
  localparam [4:0] ADDR_PHYSR  = 5'd17; // | RO | PHY Specific Status Register.
  localparam [4:0] ADDR_INER   = 5'd18; // | RW | Interrupt Enable Register.
  localparam [4:0] ADDR_INSR   = 5'd19; // | RO | Interrupt Status Register.
  localparam [4:0] ADDR_EPHYCR = 5'd20; // | RW | Extended PHY specific Control Register.
  localparam [4:0] ADDR_RXERC  = 5'd21; // | RO | Receive Error Counter.
  localparam [4:0] ADDR_LEDCR  = 5'd24; // | RW | LED Control Register.

  function automatic [4:0] get_next_addr ();
    input logic [4:0] adr;

    logic [4:0] next_addr;
    
    if      (adr == ADDR_BMCR  ) next_addr = ADDR_BMSR  ;
    else if (adr == ADDR_BMSR  ) next_addr = ADDR_PHYID1;
    else if (adr == ADDR_PHYID1) next_addr = ADDR_PHYID2;
    else if (adr == ADDR_PHYID2) next_addr = ADDR_ANAR  ;
    else if (adr == ADDR_ANAR  ) next_addr = ADDR_ANLPAR;
    else if (adr == ADDR_ANLPAR) next_addr = ADDR_ANER  ;
    else if (adr == ADDR_ANER  ) next_addr = ADDR_ANNPTR;
    else if (adr == ADDR_ANNPTR) next_addr = ADDR_ANNPRR;
    else if (adr == ADDR_ANNPRR) next_addr = ADDR_GBCR  ;
    else if (adr == ADDR_GBCR  ) next_addr = ADDR_GBSR  ;
    else if (adr == ADDR_GBSR  ) next_addr = ADDR_MACR  ;
    else if (adr == ADDR_MACR  ) next_addr = ADDR_MAADR ;
    else if (adr == ADDR_MAADR ) next_addr = ADDR_GBESR ;
    else if (adr == ADDR_GBESR ) next_addr = ADDR_BMCR  ;
    get_next_addr = next_addr;
  
  endfunction


  function automatic [4:0] get_pos ();
    input logic [4:0] adr;
    
    logic [4:0] pos;
    if      (adr == ADDR_BMCR  ) pos = 0;
    else if (adr == ADDR_BMSR  ) pos = 1;
    else if (adr == ADDR_PHYID1) pos = 2;
    else if (adr == ADDR_PHYID2) pos = 3;
    else if (adr == ADDR_ANAR  ) pos = 4;
    else if (adr == ADDR_ANLPAR) pos = 5;
    else if (adr == ADDR_ANER  ) pos = 6;
    else if (adr == ADDR_ANNPTR) pos = 7;
    else if (adr == ADDR_ANNPRR) pos = 8;
    else if (adr == ADDR_GBCR  ) pos = 9;
    else if (adr == ADDR_GBSR  ) pos = 10;
    else if (adr == ADDR_MACR  ) pos = 11;
    else if (adr == ADDR_MAADR ) pos = 12;
    else if (adr == ADDR_GBESR ) pos = 13;
    else if (adr == ADDR_PHYCR ) pos = 14;
    else if (adr == ADDR_PHYSR ) pos = 15;
    else if (adr == ADDR_INER  ) pos = 16;
    else if (adr == ADDR_INSR  ) pos = 17;
    else if (adr == ADDR_EPHYCR) pos = 18;
    else if (adr == ADDR_RXERC ) pos = 19;
    else if (adr == ADDR_LEDCR ) pos = 20;

    get_pos = pos;
  
  endfunction
  
  typedef enum logic [1:0] {
    rw = 2'b11,
    ro = 2'b10,
    wo = 2'b01
  } right_t;

  function automatic right_t get_rights ();
    input [4:0] adr; 
    right_t right;
    if      (adr == ADDR_BMCR  ) right = rw;
    else if (adr == ADDR_BMSR  ) right = ro;
    else if (adr == ADDR_PHYID1) right = ro;
    else if (adr == ADDR_PHYID2) right = ro;
    else if (adr == ADDR_ANAR  ) right = rw;
    else if (adr == ADDR_ANLPAR) right = rw;
    else if (adr == ADDR_ANER  ) right = rw;
    else if (adr == ADDR_ANNPTR) right = rw;
    else if (adr == ADDR_ANNPRR) right = rw;
    else if (adr == ADDR_GBCR  ) right = rw;
    else if (adr == ADDR_GBSR  ) right = ro;
    else if (adr == ADDR_MACR  ) right = wo;
    else if (adr == ADDR_MAADR ) right = rw;
    else if (adr == ADDR_GBESR ) right = ro;
    else if (adr == ADDR_PHYCR ) right = rw;
    else if (adr == ADDR_PHYSR ) right = ro;
    else if (adr == ADDR_INER  ) right = rw;
    else if (adr == ADDR_INSR  ) right = ro;
    else if (adr == ADDR_EPHYCR) right = rw;
    else if (adr == ADDR_RXERC ) right = ro;
    else if (adr == ADDR_LEDCR ) right = rw;
    get_rights = right;
  endfunction

  typedef struct packed {
    logic       reset;
    logic       loop;
    logic       speed0;
    logic       ane; // Auto-Negotiation Enable
    logic       pwd; // Power Down
    logic       isolate;
    logic       restart_an;
    logic       duplex;
    logic       col_test;
    logic       speed1;
    logic [5:0] resv;
  } reg_bmcr_t;
  
  typedef struct packed {
    logic base100_t4;
    logic base100_tx_full;
    logic base100_tx_half;
    logic base10_t_full;
    logic base10_t_half;
    logic base100_t2_full;
    logic base100_t2_half;
    logic base1000_ext;
    logic resv;
    logic preamble_supress;
    logic autoneg_complete;
    logic remote_fault;
    logic autoneg_capable;
    logic link_status;
    logic jabber_detect;
    logic expand_capable;
  } reg_bmsr_t;
  
  typedef struct packed {
    logic [15:0] oui_msb;
  } reg_phyid1_t;
  
  typedef struct packed {
    logic [15:10] oui_lsb;
    logic [9:  4] model_num;
    logic [3:  0] rev_number;
  } reg_phyid2_t;
  
  typedef struct packed {
    logic       next_page;        // 15
    logic       reserved1;        // 14
    logic       remote_fault;     // 13
    logic       reserved2;        // 12
    logic       assymetric_pause; // 11
    logic       pause;            // 10
    logic       base_100;         //  9
    logic       base_100_tx_full; //  8
    logic       base_100_tx_half; //  7
    logic       base10_tx_full;   //  6
    logic       base10_tx_half;   //  5
    logic [4:0] selector;         //  4:0
  } reg_anar_t;
            
  typedef struct packed {
    logic       next_page;
    logic       ack;
    logic       remote_fault;
    logic [7:0] tech_ability_field;
    logic [4:0] selector_field;
  } reg_anlpar_t;
  
  typedef struct packed {
    logic [10:0] resv;
    logic        parallel_det_fault;
    logic        link_next_pageable;
    logic        local_next_pageable;
    logic        page_received;
    logic        autoneg_complete;
  } reg_aner_t;
  
  typedef struct packed {
    logic        next_page;
    logic        resv;
    logic        message_page;
    logic        acknowledge2;
    logic        toggle;
    logic [10:0] message;
  
  } reg_annptr_t;
  
  typedef struct packed {
    logic        next_page;
    logic        ack;
    logic        message_page;
    logic        ack2;
    logic        toggle;
    logic [10:0] message;
  } reg_annprr_t;
  
  typedef struct packed {
    logic [2:0] test_mode;
    logic       manual;
    logic       value;
    logic       port_type;
    logic       t1000_full;
    logic [8:0] resv;
  } reg_gbcr_t;
  
  typedef struct packed {
    logic       cfg_fault;
    logic       cfg_resolve;
    logic       loc_rec_stat;
    logic       rem_rec_stat;
    logic       t1000_full;
    logic       t1000_half;
    logic [1:0] resv;
    logic [7:0] errors;
  } reg_gbsr_t;
  
  typedef struct packed {
    logic [1:0] func;
    logic [1:0] resv;
  } reg_macr_t;
  
  typedef struct packed {
    logic [15:0] addr;
  } reg_maadr_t;
    
  typedef struct packed {
    logic        x1000_fd;
    logic        x1000_hd;
    logic        t1000_fd;
    logic        t1000_hd;
    logic [11:0] resv;
  } reg_gbesr_t;

  // typedef struct packed {
    
  // } reg_phycr_t;

  // typedef struct packed {
  
  
  // } reg_physr_t;
  // typedef struct packed {


  // } addr_iner_t;
  // typedef struct packed {


  // } addr_insr_t;

  // typedef struct packed {


  // } reg_ephycr_t;

  typedef struct packed {
    logic [15:0] count;
  } reg_rxerc_t;

  typedef struct packed {
    logic       disable_led;
    logic [2:0] stretch;
    logic       reserved1;
    logic [2:0] blink_rate;
    logic [3:0] reserved2;
    logic       ledlink_ctrl;
    logic       leddup_ctrl;
    logic       ledrx_ctrl;
    logic       ledtx_ctrl;
  } reg_ledcr_t;

endpackage : qnigma_mdio_pkg