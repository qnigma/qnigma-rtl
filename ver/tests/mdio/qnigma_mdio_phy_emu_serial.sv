module qnigma_mdio_phy_emu_serial 
  import
    qnigma_mdio_pkg::*;
# (  
  parameter [4:0] ADDR_PHY = 1
)
(

  input  logic mdc,
  input  logic mdo,
  input  logic mdt,
  output logic mdi,
 // wr op only
  output logic [15:0] dout, // data to write
  output logic [ 4:0] aout, // address to write to/read from
  output logic        vout, // write data
  // read op
  input  logic [15:0] din // data add 'aout'
);

  parameter REG_LEN = 64;
  logic [31:0][15:0] regmap;

  logic mdc_inv;

  assign mdc_inv = ~mdc;

  logic running;

  logic [REG_LEN-1:0] mdo_sr;
  logic [REG_LEN-1:0] mdt_sr;

  logic start   ;
  logic start_ok;
  logic read    ;
  logic reading ;
  logic mdo_neg ;
  logic mdo_pos ;

  always_ff @ (posedge mdc) begin
    if      (!mdo_prev && mdo) running <= 1;
    else if (done)             running <= 0;
  end

  logic done;
  logic [15:0] dat_rx;

  always_ff @ (posedge mdc) vout <= !r_nw && done && (phyad == ADDR_PHY);
  always_ff @ (posedge mdc) aout <= regad;
  always_ff @ (posedge mdc) dout <= dat_rx;

  assign dat_rx = {mdo_sr[14:0], mdo_reg};

  assign done = ctr == 63;
  
  logic [7:0]  ctr;

  logic ta_read;
  logic ta_write;

  always_ff @ (posedge mdc) begin
    if (done || !running) ctr <= 0;
    else ctr <= ctr + 1;
  end


  // "01" and "10" events
  assign mdo_neg =  mdo_prev && !mdo_reg;
  assign mdo_pos = !mdo_prev &&  mdo_reg;
  
  logic r_nw;
  
  logic [4:0] regad;
  logic [4:0] phyad;
  logic turnaround;

  always_ff @ (posedge mdc) begin
    // read/write operation

    // if (ctr ==  )
    if (ctr == 32) begin
      if (mdo_neg) begin
        $display("====================");
        $display("[EMU] start detected");
      end
      else     $display("[EMU] start NOT detected");
    end
    if (ctr == 35) begin
      if      (mdo_neg) begin r_nw <= 1; $display("[EMU] reading"); end 
      else if (mdo_pos) begin r_nw <= 0; $display("[EMU] writing"); end
      else begin
        $display("[EMU] R/W bit error!");
        $display("[EMU]    |prev| cur");
        $display("[EMU] mdo|%b  | %b ", mdo_prev, mdo_reg);
        $display("[EMU] mdt|%b  | %b ", mdt_prev, mdt_reg);
      end
    end
    // PHY Address
    if (ctr == 40) begin phyad <= {mdo_sr[3:0], mdo_reg}; $display("[EMU] phyad %b", {mdo_sr[3:0], mdo_reg}); end
    // Register Address
    if (ctr == 45) begin regad <= {mdo_sr[3:0], mdo_reg}; $display("[EMU] regad %b", {mdo_sr[3:0], mdo_reg}); end
    if (turnaround) begin
      if (mdt_prev && mdt_reg) begin // hi-z, read turenaround
        ta_read  <= r_nw;
        if (r_nw) begin // if actually writing
          $display("[EMU] Got read TA while writing");
          $display("[EMU]    |prev| cur");
          $display("[EMU] mdo|%b  | %b ", mdo_prev, mdo_reg);
          $display("[EMU] mdt|%b  | %b ", mdt_prev, mdt_reg);
        end
      end
      else if (!mdt_prev && !mdt && mdo_sr[0] && !mdo) begin
        ta_write <= 1;
        if (!r_nw) // if actually reading
          $display("[EMU] Got write TA while reading");
      end
    end
    else begin
      ta_read  <= 0;
      ta_write <= 0;
    end
    // Data
    if (ctr == 55) begin
      // mdt_sr

    end
  end
  
  logic load_data;
  
  assign load_data = ctr == 47;
  
  logic [15:0] data_tx;

  always_ff @ (negedge mdc) begin
    if (load_data) data_tx <= din;
    else data_tx <= data_tx << 1; 
  end
  
  assign mdi = data_tx[15];

  logic mdo_prev;
  logic mdt_prev;

  logic mdo_reg;
  logic mdt_reg;

  always_ff @ (posedge mdc) begin
    mdo_prev <= mdo_reg;
    mdt_prev <= mdt_reg;
  end
  
  always_ff @ (posedge mdc) begin
    mdo_reg <= mdo;
    mdt_reg <= mdt;
  end

  // shift incoming mdo data from RTL
  always_ff @ (posedge mdc) begin
    mdo_sr <= {mdo_sr[REG_LEN-2:0], mdo_reg};
    mdt_sr <= {mdt_sr[REG_LEN-2:0], mdt_reg};
  end
  
  // assign oper_r_nw = mdo_sr[0] && !mdo;
  
  assign turnaround = ctr == 47;

  // always_ff @ (posedge mdc) begin
  //   if (phyad_done) begin
  //   if (start_ok  ) 
  //   if (oper_ok   )
  //   if (oper_ok   )
  //   end 
  //   if (turnaround) begin // 2 clock cycles
  //     if (mdt == 0) reading <= 1; 
  //   end
  //   else if (running) begin

  //   end
  // end


endmodule