// Copyright qnigma
// Calculate scaled window size of remote node
module qnigma_tcp_wnd
  import
    qnigma_pkg::*;
(
  input  logic         clk,
  input  logic         set_scl, // set scale (at 3whs)
  input tcp_wnd_scl_t  scl, // scale (as in TCP WS option) or 0 if none (1 to 15)
  input  logic         upd, // update 'wnd' with new 'raw'
  input [15:0]         raw,
  output tcp_wnd_scl_t wnd
);
  tcp_scl_t     scl_reg, ctr;
  tcp_wnd_scl_t raw_reg;
  
  logic cal;

  always_ff @ (posedge clk) begin
    if (set_scl) begin // set once from syn or synack
      scl_reg <= scl;
    end
    else if (upd) begin // Update windows
      ctr <= 0;
      cal <= 1;
      raw_reg <= raw; // Assign raw (unscaled) value to raw_reg ans start calculation
    end
    else if (cal) begin         // calculating...
      ctr <= ctr + 1;           // increment counter value
      if (ctr == scl_reg) begin // done scaling
        cal <= 0;               // stop calculating
        wnd <= raw_reg;         // update window with raw shifted value 
      end
      else raw_reg <= raw_reg << 1; // shift raw_reg for 'scale' bits
    end

  end

endmodule : qnigma_tcp_wnd
