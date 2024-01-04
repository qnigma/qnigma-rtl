// Process router information options from Router Adverisements:
// - Router IP
// - Router MAC
// - RDNSS option
// - Prefix
// - MTU
// ============================
// - Only accept prefix of length of valuePREFIX_LENGTH
// - Only update DNS IP if option RDNSS option is present
// - Track lifetime of Router, DNS IPs and Prefix information
// Availability and prefix value 
// DNS IP(s)
// MTU
module qnigma_rtr_inf 
  import 
    qnigma_pkg::*;
(
  input logic            clk,
  input logic            rst,
  input logic            tick_ms,        // 1-millisecond tick
  input logic            tick_s,         // 1-second tick
  input logic            rcv,            // Packet received (meta_& valid)
  // Deserialized packet information
  input meta_mac_t       meta_mac,       // MAC metadata
  input meta_ip_t        meta_ip,        // IP metadata
  input meta_icmp_t      meta_icmp,      // ICMP metadata
  input meta_icmp_pres_t meta_icmp_pres, // ICMP fields present

  output pfx_t            pfx,            // Prefix value
  output logic            pfx_avl,        // Prefix available from router

  output ip_t             dns_ip,         // DNS IP(s)
  output logic            dns_pres,       // Present (bitwise valid 'dns_ip')
  output logic            dns_avl,        // DNS available

  output ip_t             rtr_ip,         // Router IP
  output mac_t            rtr_mac,        // Router MAC
  output logic            rtr_det,        // Router detected, IP and MAC valid
  
  output logic [15:0]     mtu             // Current device-wide MTU

);
  
  logic [15:0] rtr_life_s; // Router life counter. 0 means no router detected
  logic [15:0] dns_life_s; // DNS server lost life counter. 0 means no DNS avaliable
  logic [31:0] pfx_life_s; // Prefix information life counter. 0 means no prefix imformation avaliable

  always_ff @ (posedge clk) begin
    if (rst) begin
      mtu        <= MTU_DEFAULT; // Intiialize as default value
      rtr_life_s <= 0;
      dns_life_s <= 0;
      rtr_det    <= 0;
      dns_avl    <= 0;
      pfx_avl    <= 0;
    end
    else begin
      if (rcv) begin // Received RA packet
        // Updata all fields
        rtr_ip        <= meta_ip.rem; 
        rtr_mac       <= meta_mac.rem;
        rtr_life_s    <= meta_icmp.rtr.lifetime;
        dns_pres      <= meta_icmp_pres.dns_addr;
        if (meta_icmp_pres.opt_rdnss) begin // Update option information if option is present
          dns_ip      <= meta_icmp.opt_rdnss.dns_addr;
          dns_life_s  <= meta_icmp.opt_rdnss.lifetime;
          dns_avl     <= 1;
        end
        else begin // No DNS server information in RA packet
           dns_life_s <= 0;
           dns_avl    <= 0;
           dns_pres   <= 0;
        end
        // Only accept options if PREFIX_LENGTH is equal to expected (usually 64, check your ISP) 
        if (meta_icmp_pres.opt_pfx_inf && meta_icmp.opt_pfx_inf.lng[6:0] == PREFIX_LENGTH) begin
          pfx_life_s  <= meta_icmp.opt_pfx_inf.pfx_life;
          pfx_avl     <= 1;
          pfx         <= meta_icmp.opt_pfx_inf.pfx;
        end
        else begin // No prefix informtation in RA packer
           pfx_life_s <= 0;
           pfx_avl    <= 0;
        end
        if (meta_icmp_pres.opt_mtu) begin
          // If MTU option is invalid, assign to default parameter
          mtu         <= (meta_icmp.opt_mtu[15:0 ] > MTU_DEFAULT[15:0] ||
                         (meta_icmp.opt_mtu[31:16] != 0           )) ? MTU_DEFAULT : meta_icmp.opt_mtu;
        end
      end
      else if (tick_s) begin
        rtr_life_s <= (rtr_life_s == 0) ? 0 : rtr_life_s - 1;
        dns_life_s <= (dns_life_s == 0) ? 0 : dns_life_s - 1;
        pfx_life_s <= (pfx_life_s == 0) ? 0 : pfx_life_s - 1;
        rtr_det    <= (rtr_life_s != 0);
        dns_avl    <= (dns_life_s != 0);
        pfx_avl    <= (pfx_life_s != 0);
      end
    end
  end

endmodule : qnigma_rtr_inf
