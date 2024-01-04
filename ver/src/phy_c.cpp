#include "phy_c.h"

phy_c::phy_c()
{
  pcap_log = new pcap(
      "log.pcap",
      8);
  fsm_tx = IDLE;
  ifg_ctr = 0;
  tim = 0;
}

phy_c::~phy_c()
{
  pcap_log->~pcap();
}

/* Add packet to transmission buffer
 * And forget about the packet
 *
 */
void phy_c::send_pkt(
    const pkt_c::pkt_t &pkt)
{
  tx_buf.push_back(pkt);
}

bool phy_c::recv_pkt(
    pkt_c::pkt_t &pkt)
{
  pkt = pkt_rx;
  return val_rx;
}

bool phy_c::sending()
{
  return (fsm_tx != IDLE);
}

void phy_c::process_rx(
    const uint8_t &phy_dat,
    const bool &phy_val,
    pkt_c::parse_err_t &err)
{
  val_rx = false;
  if (!phy_val && raw_rx.size()) // end of packet
  {
    val_rx = true;
    pcap_log->write_pkt(tim, raw_rx);  // log it to pcap
    pkt_c::pkt_t pkt;                  // create a struct to hold packet info and payload
    pkt_c::parse(raw_rx, pkt_rx, err); // parse raw byte stream into packet
    raw_rx.clear();                    // 'delete' raw_rx after extracting data
  }
  if (phy_val) // receiving packet byte by byte...
    raw_rx.push_back(phy_dat);
  return;
}

// Advance transmission FSM
// Whenever tx queue is not empty, read one packed
// and transmit it to phy interface, then wait IFG
void phy_c::process_tx(
    uint8_t &phy_dat,
    bool &phy_val)
{
  switch (fsm_tx)
  {
  case (IDLE):
  {
    ifg_ctr = 0;
    tx_ptr = 0;
    phy_val = 0;
    phy_dat = 0;
    if (tx_buf.size() != tx_idx) // If new meta is added to vect...
    {
      fsm_tx = tx_s;
      pkt_c::pkt_t pkt = tx_buf[tx_idx];
      pkt_c::generate(raw_tx, pkt);
      pcap_log->write_pkt(tim, raw_tx);
    }
    break;
  }
  case (tx_s):
  {
    phy_val = 1;
    phy_dat = raw_tx[tx_ptr++];
    if (tx_ptr == raw_tx.size())
    {
      fsm_tx = ifg_s;
      raw_tx.clear();
      tx_idx++;
    }
    break;
  }
  case (ifg_s):
  {
    phy_val = 0;
    ifg_ctr++;
    if (ifg_ctr == IFG_TICKS)
    {
      fsm_tx = IDLE;
    }
    break;
  }
  }
  return;
}

/* Process PHY interface and parse/generate incomung/outgoing packets

*/
void phy_c::process_phy(
    const uint8_t &phy_dat_rx,
    const bool &phy_val_rx,
    uint8_t &phy_dat_tx,
    bool &phy_val_tx,
    pkt_c::parse_err_t &err)
{
  tim++;
  // Interface to phy
  phy_c::process_rx(
      phy_dat_rx,
      phy_val_rx,
      err);

  phy_c::process_tx(
      phy_dat_tx,
      phy_val_tx);
}

/*
  // Basic receive errors
  if (pkt_rx_val)
  {
    switch (err_rx)
    {
    case (ERR_FCS):
    {
      std::cout << "\x1b[31m[tb]<- Error: Incorrect FCS \x1b[0m \n";
      break;
    }
    case (ERR_ETH_TOO_SMALL):
    {
      std::cout << "\x1b[31m[tb]<- Error: Packet than 64 bytes \x1b[0m \n";
      break;
    }
    case (ERR_ETH_TOO_BIG):
    {
      std::cout << "\x1b[31m[tb]<- Error: Length exceeds MTU \x1b[0m \n";
      break;
    }
    case (ERR_ETH_NOT_IP):
    {
      std::cout << "\x1b[31m[tb]<- Error: Packet is not IPv6 \x1b[0m \n";
      break;
    }
    case (ERR_IP_PROTO):
    {
      std::cout << "\x1b[31m[tb]<- Error: Unknown IP protocol \x1b[0m \n";
      break;
    }
    case (ERR_IP_VER):
    {
      std::cout << "\x1b[31m[tb]<- Error: received IP packet with incorrect version \x1b[0m \n";
      break;
    }
    case (ERR_IP_ZERO_LEN):
    {
      std::cout << "\x1b[31m[tb]<- Error: IP packet with zero length \x1b[0m \n";
      break;
    }
    case (ERR_IP_HOPS_EXHAUSTED):
    {
      std::cout << "\x1b[31m[tb]<- Error: exhausted IP hop limit (hop field is zero) \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_UNKNOWN_TYPE):
    {
      std::cout << "\x1b[31m[tb]<- Error: Unknown ICMP type \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_CHECKSUM):
    {
      std::cout << "\x1b[31m[tb]<- Error: incorrect ICMP checksum \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_TOO_SMALL):
    {
      std::cout << "\x1b[31m[tb]<- Error: incorrect ICMP packet too small \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_TOO_BIG):
    {
      std::cout << "\x1b[31m[tb]<- Error: incorrect ICMP packet too big \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_UNKNOWN_OPTION):
    {
      std::cout << "\x1b[31m[tb]<- Error: Unknown ICMP option \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_OPTION_LEN):
    {
      std::cout << "\x1b[31m[tb]<- Error: option length \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_BAD_CODE):
    {
      std::cout << "\x1b[31m[tb]<- Error: incorrect ICMP checksum \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_BAD_RES):
    {
      std::cout << "\x1b[31m[tb]<- Error: ICMP reserved field non zero \x1b[0m \n";
      break;
    }
    case (ERR_ICMP_TOO_SHORT):
    {
      std::cout << "\x1b[31m[tb]<- Error: ICMP packed ended unexpextedly \x1b[0m \n";
      break;
    }
    }
    */
