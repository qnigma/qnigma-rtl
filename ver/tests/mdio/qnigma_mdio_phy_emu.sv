module qnigma_mdio_phy_emu   
  import
    qnigma_mdio_pkg::*;
#(
  parameter [4:0] ADDR_PHY = 1
)
(
  input  logic clk,
  input  logic rst,

  input  logic mdc,
  input  logic mdo,
  input  logic mdt,
  output logic mdi
);

  logic        val_read;
  logic [15:0] dat_read;
  logic  [4:0] adr_read;

  logic  [4:0] phyad;
  logic  [4:0] regad;
  logic [15:0] dat_write;
  
  logic r_nw;
  logic send;
  logic ready;
  logic done;
  
  // Serial interface
  qnigma_mdio_phy_emu_serial mdio_phy_serial_inst (
    // .clk  (clk      ),
    // .rst  (rst      ),

    .din  (dat_write),
    .vout (val_read ),
    .dout (dat_read ),
    .aout (adr_read ),

    .mdo  (mdo      ),
    .mdi  (mdi      ),
    .mdt  (mdt      ),
    .mdc  (mdc      )
  );

  // Packet control
  qnigma_mdio_phy_emu_ctrl #(
    .ADDR_PHY (ADDR_PHY)
  ) mdio_ctrl_inst (
    .clk  (mdc      ),
    .rst  (rst      ),

    .dout (dat_write),

    .vin  (val_read ),
    .din  (dat_read ),
    .ain  (adr_read )

  );

endmodule