module qnigma_mdio_ctrl 
  import
    qnigma_mdio_pkg::*;
# (
  parameter int RST_DELAY_MS = 0, 
  parameter int POLL_MS = 0,      
  parameter bit FORCE_1000 = 0,   
  parameter bit FORCE_100 = 0,    
  parameter bit FORCE_10 = 0,
  parameter int PHY_RESET_TICKS = 250 // 100ms 
)
(
    input  logic        clk,
    input  logic        rst,
    // transaction control
    output logic        r_nw,
    output logic        send,
    input  logic        ready,
    input  logic        done,
    output logic [ 4:0] phyad,
    output logic [ 4:0] regad,
    output logic [15:0] dat_out,

    // serial interface read reply
    input  logic        val_in,
    input  logic [15:0] dat_in,
    input  logic [ 4:0] adr_in,

    output logic        spd,
    output logic        phy_rstn,

    output logic [15:0] bmsr,
    output logic [15:0] phyid_1,
    output logic [15:0] phyid_2
);

  logic [18:0][15:0] reg_loc;
  logic [18:0][15:0] reg_rem;

  localparam [4:0] ADDRESS_PHY = 1; 

  logic       set_reset; 
  logic       set_loop;
  logic [1:0] set_speed;
  logic       set_ane;
  logic       set_pwd;
  logic       set_isolate;
  logic       set_restart_an;
  logic       set_duplex;

  logic [18:0][15:0] loc_reg;
  logic [18:0][15:0] rem_reg;

  logic [$clog2(PHY_RESET_TICKS+1)-1:0] rst_phy_ctr;
  logic [4:0]                           cur_pos;
  reg_t                                 cur_addr;


  enum logic [7:0] {
    RESET_PHY,
    SEL_OPER,
    UPD_READ,
    UPD_WRITE,
    NEXT_REG,
    IDLE
  } state;

  assign cur_pos = get_pos(cur_addr);
  
  logic [4:0] wr_pos;
  
  assign wr_pos = get_pos(adr_in);

  always_ff @ (posedge clk) begin
    if (val_in) begin
      if (adr_in == ADDR_BMSR) begin
        bmsr <= dat_in;
        $display("Got BMSR: %x", dat_in);
      end
      if (adr_in == ADDR_PHYID1) begin
        $display("Got PHYID1: %b", dat_in);
        phyid_1 <= dat_in;
      end
      if (adr_in == ADDR_PHYID2) begin
        $display("Got PHYID2: %b", dat_in);
        phyid_2 <= dat_in;
      end
      // rem_reg[wr_pos] <= dat_in;
    end
  end


  //////////////////
  // Register map //
  //////////////////
  reg_bmcr_t   reg_bmcr;
  reg_bmsr_t   reg_bmsr;
  reg_phyid1_t reg_phyid1;
  reg_phyid2_t reg_phyid2;
  reg_anar_t   reg_anar;
  reg_anlpar_t reg_anlpar;
  reg_aner_t   reg_aner;
  reg_annptr_t reg_annptr;
  reg_annprr_t reg_annprr;
  reg_gbcr_t   reg_gbcr;
  reg_gbsr_t   reg_gbsr;
  reg_gbesr_t  reg_macr;
  reg_gbesr_t  reg_maadr;
  reg_gbesr_t  reg_gbesr;
  // reg_phycr_t  reg_phycr;
  // reg_physr_t  reg_physr;
  // reg_iner_t   reg_iner;
  // reg_insr_t   reg_insr;
  // reg_ephycr_t reg_ephycr;
  // reg_rxerc_t  reg_rxerc;
  // reg_ledcr_t  reg_ledcr;

  // BMCR
  always_comb begin
    reg_bmcr.reset      = 1;
    reg_bmcr.loop       = 0;
    reg_bmcr.speed0     = 1;
    reg_bmcr.ane        = 1;
    reg_bmcr.pwd        = 0;
    reg_bmcr.isolate    = 0;
    reg_bmcr.restart_an = 0;
    reg_bmcr.duplex     = 1;
    reg_bmcr.col_test   = 0;
    reg_bmcr.speed1     = 1;
    reg_bmcr.resv       = 0;
  end

  always_comb begin
    reg_loc[0]  = reg_bmcr;
    reg_loc[1]  = reg_bmsr;
    reg_loc[2]  = reg_phyid1;
    reg_loc[3]  = reg_phyid2;
    reg_loc[4]  = reg_anar;
    reg_loc[5]  = reg_anlpar;
    reg_loc[6]  = reg_aner;
    reg_loc[7]  = reg_annptr;
    reg_loc[8]  = reg_annprr;
    reg_loc[9]  = reg_gbcr;
    reg_loc[10] = reg_gbsr;
    reg_loc[11] = reg_macr;
    reg_loc[12] = reg_maadr;
    reg_loc[13] = reg_gbesr;
  end

  right_t cur_rights;

  assign cur_rights = get_rights(cur_addr);
  
  parameter int TOTAL_REGS = 13; // Only first 13 regs
  logic [$clog2(TOTAL_REGS+1)-1:0] regs_left;

  always_ff @ (posedge clk) begin
    if (rst) begin
      phy_rstn <= 0;
      state <= RESET_PHY;
      phy_rstn <= 0;
      rst_phy_ctr <= 0;
    end
    else begin
      // Regardless of FSM state
      phyad <= ADDRESS_PHY;
      regad <= cur_addr;
      // FSM
      case (state) 
        RESET_PHY : begin
          regs_left <= TOTAL_REGS;
          rst_phy_ctr <= rst_phy_ctr + 1;
          if (rst_phy_ctr == PHY_RESET_TICKS) begin
            state <= SEL_OPER;
            phy_rstn <= 1;
          end
        end
        SEL_OPER : begin
          case (cur_rights)
            rw      : state <= UPD_READ;
            ro      : state <= UPD_READ;
            wo      : state <= UPD_WRITE;
            default : state <= UPD_READ;
          endcase
        end 
        UPD_READ : begin
          dat_out <= 0;
          r_nw    <= 1;
          send    <= ready && !send;
          if (done) begin
            state <= (cur_rights == rw) ? UPD_WRITE : NEXT_REG;
          end
        end
        UPD_WRITE : begin
          dat_out <= reg_loc[cur_pos];
          r_nw    <= 0;
          send    <= ready && !send;
          if (done) begin
            state <= NEXT_REG;
          end
        end
        NEXT_REG  : begin
          regs_left <= regs_left - 1;
          $display(">>>> SELECTING NEXT REG");
          cur_addr <= get_next_addr(cur_addr);
          state    <= (regs_left == 0) ? IDLE : SEL_OPER;
        end
        IDLE : begin
          regs_left <= TOTAL_REGS; // Scan through all registers except Reserved
        end
        default :;
      endcase
    end
  end

  // logic [15:0] control_reg;
  // logic [15:0] autoneg_adv_reg;
  // logic [15:0] phy_rem_control_reg;
  // logic [15:0] phy_rem_status_reg;
  // logic [15:0] phy_rem_phyid0_reg;
  // logic [15:0] phy_rem_phyid1_reg;
  // logic [15:0] phy_rem_autoneg_adv_reg;
  // logic [15:0] phy_rem_autoneg_lnk_reg;
  // logic [15:0] phy_rem_autoneg_exp_reg;

endmodule