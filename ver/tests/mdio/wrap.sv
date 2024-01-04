module wrap
(
  input  logic clk,
  input  logic rst,
  output logic don
);

  logic phy_mdc;
  logic phy_mdo;
  logic phy_mdi;
  logic phy_mdt;
  
  qnigma_mdio #(
    .MDC_DIV       (20),
    .RST_DELAY_MS  (1000),
    .POLL_MS       (10),
    .FORCE_1000    (0),
    .FORCE_100     (0),
    .FORCE_10      (0)
  ) dut (
    .clk      (clk),
    .rst      (rst),
    .mdc      (phy_mdc),
    .mdo      (phy_mdo),
    .mdi      (phy_mdi),
    .mdt      (phy_mdt),
    .spd      (   ),
    .phy_rstn (   ),
    .bmsr     (   ),
    .phyid_1  (   ),
    .phyid_2  (   )
  );

  qnigma_mdio_phy_emu # (
    .ADDR_PHY (1)
  ) qnigma_mdio_phy_emu_inst (
    .clk  (),
    .rst  (),

    .mdc  (phy_mdc),
    .mdo  (phy_mdo),
    .mdt  (phy_mdt),
    .mdi  (phy_mdi)
    
    // .autoneg_set ()
  );

endmodule
