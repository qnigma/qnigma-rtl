module qnigma_mdio_phy_emu_ctrl  
  import
    color_pkg::*,
    qnigma_mdio_pkg::*;
#(
  parameter [4:0] ADDR_PHY = 1
)
(
  input logic         clk,
  input logic         rst,

 // wr op only
  input logic  [15:0] din, // data to write
  input logic  [ 4:0] ain, // address to write to/read from
  input logic         vin, // write data
  // read op
  output logic [15:0] dout // data add 'aout'
);
  localparam [15:0] PHYID1 = 16'b0000000000011100;
  localparam [15:0] PHYID2 = 16'b1100100100010110;

  reg_bmcr_t   din_bmcr;
  reg_bmsr_t   din_bmsr;
  reg_phyid1_t din_phyid1;
  reg_phyid2_t din_phyid2;
  reg_anar_t   din_anar;
  reg_anlpar_t din_anlpar;
  reg_aner_t   din_aner;
  reg_annptr_t din_annptr;
  reg_annprr_t din_annprr;
  reg_gbcr_t   din_gbcr;
  reg_gbsr_t   din_gbsr;
  reg_macr_t   din_macr;
  reg_maadr_t  din_maadr;
  reg_gbesr_t  din_gbesr;


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
  reg_macr_t   reg_macr;
  reg_maadr_t  reg_maadr;
  reg_gbesr_t  reg_gbesr;

  always_comb begin
    din_bmcr   = din;
    din_bmsr   = din;
    din_phyid1 = din;
    din_phyid2 = din;
    din_anar   = din;
    din_anlpar = din;
    din_aner   = din;
    din_annptr = din;
    din_annprr = din;
    din_gbcr   = din;
    din_gbsr   = din;
    din_macr   = din;
    din_maadr  = din;
    din_gbesr  = din;
  end

  always_comb begin
    case (ain)
      (ADDR_BMCR)   : dout = reg_bmcr;          
      (ADDR_BMSR)   : dout = reg_bmsr;          
      (ADDR_PHYID1) : dout = PHYID1;          
      (ADDR_PHYID2) : dout = PHYID2;          
      (ADDR_ANAR)   : dout = reg_anar;          
      (ADDR_ANLPAR) : dout = reg_anlpar;          
      (ADDR_ANER)   : dout = reg_aner;          
      (ADDR_ANNPTR) : dout = reg_annptr;          
      (ADDR_ANNPRR) : dout = reg_annprr;          
      (ADDR_GBCR)   : dout = reg_gbcr;          
      (ADDR_GBSR)   : dout = reg_gbsr;          
      (ADDR_MACR)   : dout = reg_macr;          
      (ADDR_MAADR)  : dout = reg_maadr;          
      (ADDR_GBESR)  : dout = reg_gbesr;          
      default       : dout = reg_bmsr;
    endcase
  end

  always_ff @ (posedge clk) begin
    if (vin) begin
      case (ain)
        ADDR_BMCR   : begin
          reg_bmcr <= din;
          $display("[PHY EMU]: write request to BMCR");
          $display("[PHY EMU]: reset       %d        ", din_bmcr.reset);
          $display("[PHY EMU]: loop        %d        ", din_bmcr.loop);
          $display("[PHY EMU]: speed       %d        ", {din_bmcr.speed1, din_bmcr.speed0});
          $display("[PHY EMU]: ane         %d        ", din_bmcr.ane);
          $display("[PHY EMU]: pwd         %d        ", din_bmcr.pwd);
          $display("[PHY EMU]: isolate     %d        ", din_bmcr.isolate);
          $display("[PHY EMU]: restart_an  %d        ", din_bmcr.restart_an);
          $display("[PHY EMU]: duplex      %d        ", din_bmcr.duplex);
          $display("[PHY EMU]: col_test    %d        ", din_bmcr.col_test);
          $display("[PHY EMU]: reserved    %d        ", din_bmcr.resv);

        end
        ADDR_BMSR   : begin
          color_red();
          $display("[EMU] DUT attempted to write to BMSR");
          color_reset();
        end
        ADDR_PHYID1 : begin
          color_red();
          $display("[EMU] DUT attempted to write to PHYID1");
          color_reset();

        end
        ADDR_PHYID2 : begin
          color_red();
          $display("[EMU] DUT attempted to write to PHYID2");
          color_reset();
        end
        ADDR_ANAR   : begin
          reg_anar    <= din;

        end
        ADDR_ANLPAR : begin
          reg_anlpar  <= din;

        end
        ADDR_ANER   : begin
          reg_aner    <= din;

        end
        ADDR_ANNPTR : begin
          reg_annptr  <= din;

        end
        ADDR_ANNPRR : begin
          reg_annprr  <= din;

        end
        ADDR_GBCR   : begin
          reg_gbcr    <= din;

        end
        ADDR_GBSR   : begin
          color_red();
          $display("[EMU] DUT attempted to write to GBSR");
          color_reset();
        end
        ADDR_MACR   : begin
          reg_macr <= din;

        end
        ADDR_MAADR  : begin
          reg_maadr <= din;

        end
        ADDR_GBESR  : begin
          color_red();
          $display("[EMU] DUT attempted to write to GBESR");
          color_reset();
        end
        default :;
      endcase
    end
  end

  
  

endmodule