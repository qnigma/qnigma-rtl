module rgmii_adapter #(
  parameter [31:0][7:0] VENDOR       = "INTEL",
  parameter [31:0][7:0] FAMILY       = "CYCLONE 10 LP",
  parameter [31:0][7:0] USE_RX_PLL   = "TRUE",
  parameter [31:0][7:0] USE_TX_PLL   = "TRUE"
)
(
  input  logic       arst,
  input  logic       gen_clk,
  output logic       clk,
  // RGMII interface to PHY
  input  logic       rgmii_rx_clk,
  input  logic [3:0] rgmii_rx_dat,
  input  logic       rgmii_rx_ctl,

  output logic       rgmii_gtx_clk,
  output logic [3:0] rgmii_tx_dat,
  output logic       rgmii_tx_ctl,
  // GMII interface to logic
  output logic       gmii_rx_clk,
  output logic [7:0] gmii_rx_dat,
  output logic       gmii_rx_val,
  output logic       gmii_rx_err,
  output logic       gmii_rx_rst,

  input  logic [7:0] gmii_tx_dat,
  input  logic       gmii_tx_val,
  input  logic       gmii_tx_err,
  output logic       gmii_tx_rst
);

logic rx_pll_locked, tx_pll_locked;
logic gmii_rx_ctl_1;
logic gmii_rx_ctl_2;
logic gmii_tx_ctl_1;
logic gmii_tx_ctl_2;

logic rgmii_gtx_clk_int;
logic tx_rst;

genvar gv;

generate
  if (VENDOR == "INTEL") begin
    if (FAMILY == "CYCLONE 10 LP") begin
      if (USE_RX_PLL == "TRUE") begin
        rgmii_rx_pll rgmii_rx_pll_inst (
          .areset (arst),
          .inclk0 (rgmii_rx_clk),
          .c0     (gmii_rx_clk_int),
          .locked (rx_pll_locked)
        );
        assign gmii_rx_rst = !rx_pll_locked;
        assign gmii_rx_clk = gmii_rx_clk_int;
      end
      else begin
        assign gmii_rx_clk     = rgmii_rx_clk;
        assign gmii_rx_clk_int = rgmii_rx_clk;
      end

      if (USE_TX_PLL == "TRUE") begin
        rgmii_tx_pll rgmii_tx_pll_inst (
          .areset (arst),
          .inclk0 (gen_clk),
          .c0     (clk), // 0 deg
          .c1     (rgmii_gtx_clk_int), // x deg
          .locked (tx_pll_locked)
        );
        always_ff @ (posedge clk) tx_rst <= !tx_pll_locked;
        always_ff @ (posedge clk) gmii_tx_rst <= tx_rst;
      end
      else begin
        assign rgmii_gtx_clk_int = gen_clk;
      end

      ////////////////
      // Data input //
      ////////////////

      altddio_in #(
        .intended_device_family   ("Cyclone 10 LP"),
        .implement_input_in_lcell ("ON"),
        .invert_input_clocks      ("ON"),
        .lpm_hint                 ("UNUSED"),
        .lpm_type                 ("altddio_in"),
        .power_up_high            ("OFF"),
        .width                    (4)
      ) altddio_in_dat_inst (
        .aclr      (arst),
        .datain    (rgmii_rx_dat[3:0]),
        .inclock   (gmii_rx_clk_int),
        .dataout_l (gmii_rx_dat[3:0]),
        .dataout_h (gmii_rx_dat[7:4]),
        // .dataout_l (gmii_rx_dat[7:4]),
        // .dataout_h (gmii_rx_dat[3:0]),

        .aset      (1'b0),
        .inclocken (1'b1),
        .sclr      (1'b0),
        .sset      (1'b0)
      );

      altddio_in #(
        .intended_device_family   ("Cyclone 10 LP"),
        .implement_input_in_lcell ("ON"),
        .invert_input_clocks      ("ON"),
        .lpm_hint                 ("UNUSED"),
        .lpm_type                 ("altddio_in"),
        .power_up_high            ("OFF"),
        .width                    (1)
      )  altddio_in_val_inst (
        .aclr      (arst),
        .datain    (rgmii_rx_ctl),
        .inclock   (gmii_rx_clk_int),
        // .dataout_l (gmii_rx_ctl_1),
        // .dataout_h (gmii_rx_ctl_2),
        .dataout_l (gmii_rx_ctl_1),
        .dataout_h (gmii_rx_ctl_2),
        .aset      (1'b0),
        .inclocken (1'b1),
        .sclr      (1'b0),
        .sset      (1'b0)
      );        

      /////////////////
      // Data output //
      /////////////////

      altddio_out	#(
        .extend_oe_disable       ("OFF"),
        .intended_device_family  ("Cyclone 10 LP"),
        .invert_output           ("OFF"),
        .lpm_hint                ("UNUSED"),
        .lpm_type                ("altddio_out"),
        .oe_reg                  ("UNREGISTERED"),
        .power_up_high           ("OFF"),
        .width                   (4)
      ) altddio_out_dat_inst (
        .aclr       (arst),
        .datain_h   (gmii_tx_dat[3:0]),
        .datain_l   (gmii_tx_dat[7:4]),
        .outclock   (clk),
        .dataout    (rgmii_tx_dat[3:0]),
        .aset       (1'b0),
        .oe         (1'b1),
        .oe_out     (),
        .outclocken (1'b1),
        .sclr       (1'b0),
        .sset       (1'b0)
      );
         
      altddio_out	#(
      	.extend_oe_disable       ("OFF"),
        .intended_device_family  ("Cyclone 10 LP"),
        .invert_output           ("OFF"),
        .lpm_hint                ("UNUSED"),
        .lpm_type                ("altddio_out"),
        .oe_reg                  ("UNREGISTERED"),
        .power_up_high           ("OFF"),
        .width                   (1)
      ) altddio_out_val_inst (
      	.aclr       (arst),
      	.datain_l   (gmii_tx_ctl_1),
      	.datain_h   (gmii_tx_ctl_2),
      	.outclock   (clk),
      	.dataout    (rgmii_tx_ctl),
      	.aset       (1'b0),
      	.oe         (1'b1),
      	.oe_out     (),
      	.outclocken (1'b1),
      	.sclr       (1'b0),
      	.sset       (1'b0)
      );

      //////////////////
      // Clock output //
      //////////////////
      
      altddio_out	#(
      	.extend_oe_disable       ("OFF"),
        .intended_device_family  ("Cyclone 10 LP"),
        .invert_output           ("OFF"),
        .lpm_hint                ("UNUSED"),
        .lpm_type                ("altddio_out"),
        .oe_reg                  ("UNREGISTERED"),
        .power_up_high           ("OFF"),
        .width                   (1)
      ) altddio_out_clk_inst (
      	.aclr       (arst),
      	.datain_l   (1),
      	.datain_h   (0),
      	.outclock   (rgmii_gtx_clk_int),
      	.dataout    (rgmii_gtx_clk),
      	.aset       (1'b0),
      	.oe         (1'b1),
      	.oe_out     (),
      	.outclocken (1'b1),
      	.sclr       (1'b0),
      	.sset       (1'b0)
      );


      
      assign gmii_tx_ctl_1 = gmii_tx_val;
      assign gmii_tx_ctl_2 = gmii_tx_val ^ gmii_tx_err;
      assign gmii_rx_val   = gmii_rx_ctl_1;
      assign gmii_rx_err   = gmii_rx_ctl_1 ^ gmii_rx_ctl_2;

    end
  end

  // else if (VENDOR == "EFINIX") begin
    
  // end
  
endgenerate

endmodule : rgmii_adapter
