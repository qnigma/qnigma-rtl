module qnigma_mdio # (
  parameter int MDC_DIV = 0,      
  parameter int RST_DELAY_MS = 0, 
  parameter int POLL_MS = 0,      
  parameter bit FORCE_1000 = 0,   
  parameter bit FORCE_100 = 0,    
  parameter bit FORCE_10 = 0   
)
(
  input  logic clk,
  input  logic rst,

  output logic mdo,
  input  logic mdi,
  output logic mdt,
  output logic mdc,

  output logic spd,
  output logic phy_rstn,

  output logic [15:0] bmsr,
  output logic [15:0] phyid_1,
  output logic [15:0] phyid_2
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
  qnigma_mdio_serial #(
    .MDC_DIV (MDC_DIV)
  ) mdio_serial_inst (
    .clk      (clk      ),
    .rst      (rst      ),

    .r_nw     (r_nw     ),
    .send     (send     ),
    .ready    (ready    ),
    .done     (done     ),
    .phyad    (phyad    ),
    .regad    (regad    ),
    .dat_in   (dat_write),

    .val_out  (val_read ),
    .dat_out  (dat_read ),
    .adr_out  (adr_read ),

    .mdo      (mdo      ),
    .mdi      (mdi      ),
    .mdt      (mdt      ),
    .mdc      (mdc      )
  );

  // Packet control
  qnigma_mdio_ctrl mdio_ctrl_inst (
    .clk      (clk      ),
    .rst      (rst      ),

    .r_nw     (r_nw     ),
    .send     (send     ),
    .ready    (ready    ),
    .done     (done     ),
    .phyad    (phyad    ),
    .regad    (regad    ),
    .dat_out  (dat_write),

    .val_in   (val_read ),
    .dat_in   (dat_read ),
    .adr_in   (adr_read ),

    .spd      (spd      ),
    .phy_rstn (phy_rstn ),

    .bmsr     (bmsr),
    .phyid_1  (phyid_1),
    .phyid_2  (phyid_2)
  );

endmodule