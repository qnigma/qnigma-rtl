#include "pcap.h"

void pcap::write_global_hdr()
{
  f.write(reinterpret_cast<char *>(&MAGIC_NUMBER), sizeof(MAGIC_NUMBER));
  f.write(reinterpret_cast<char *>(&VERSION_MAJOR), sizeof(VERSION_MAJOR));
  f.write(reinterpret_cast<char *>(&VERSION_MINOR), sizeof(VERSION_MINOR));
  f.write(reinterpret_cast<char *>(&THISZONE), sizeof(THISZONE));
  f.write(reinterpret_cast<char *>(&SIGFIGS), sizeof(SIGFIGS));
  f.write(reinterpret_cast<char *>(&SNAPLEN), sizeof(SNAPLEN));
  f.write(reinterpret_cast<char *>(&NETWORK), sizeof(NETWORK));
}

bool pcap::open_file(std::string name)
{
  cout << "pcap: Opening file: " << name << "\n";
  f.open(name, ios::out | ios::binary);
  if (f.fail())
  {
    cout << "pcap: Failed to open file: " << name << "\n";
    return false;
  }
  else
    return true;
}

void pcap::close_file()
{
  f.close();
  cout << "pcap: Closing file\n";
}

pcap::pcap(std::string name, int ns_per_tick)
{
  bool ok = open_file(name);
  if (!ok)
    cout << "pcap: Failed to open file\n";
  write_global_hdr();
  tick_len = ns_per_tick;
}

pcap::~pcap()
{
  close_file();
}

void pcap::write_pkt_hdr(
    int ticks,
    size_t len)
{
  if (!f.is_open())
    return;
  uint8_t cur;
  uint32_t trunc_len = len - 8;
  uint32_t t_nsecs = (ticks * tick_len) % 1000000000;
  uint32_t t_secs = (ticks * tick_len - t_nsecs) / 1000000000;

  for (int j = 0; j < 4; j++)
  {
    cur = (t_secs >> ((8 * j) & 0xff));
    f.write(reinterpret_cast<char *>(&cur), 1);
  }

  for (int j = 0; j < 4; j++)
  {
    cur = (t_nsecs >> ((8 * j) & 0xff));
    f.write(reinterpret_cast<char *>(&cur), 1);
  }

  for (int i = 0; i < 2; i++)
  {
    for (int j = 0; j < 4; j++)
    {
      cur = (trunc_len >> ((8 * j) & 0xff));
      f.write(reinterpret_cast<char *>(&cur), 1);
    }
  }
}

void pcap::write_pkt(
    int ticks,
    vector<uint8_t> raw)
{
  if (f.is_open())
  {
    write_pkt_hdr(
        ticks,
        raw.size());
  }
  for (size_t i = 8; i < raw.size(); i++)
    f.write(reinterpret_cast<char *>(&raw[i]), 1);
}
