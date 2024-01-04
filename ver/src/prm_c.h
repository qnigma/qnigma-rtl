#ifndef PARAMS_C_H
#define PARAMS_C_H
#include "pkt_c.h"
#include "model_ifc_c.h"
// Test configuration class
class prm_c
{
public:
    uint16_t TB_PORT;                            // Testbench TCP port
    uint16_t DUT_PORT;                           // DUT TCP port
    uint32_t DNS_DEFAULT_TTL;                    // Default TTL in DNS query
    unsigned DAD_FAIL_SIM_TIMES;                 // DAD collisions during test
    unsigned DAD_TIMEOUT_TICKS;                  // Amount of ticks for TB to consider DUT's next NS packet timed out
    unsigned DAD_DUT_PACKETS;                    // Amount of ticks for TB to consider DUT's next NS packet timed out
    unsigned MLD_DUT_PACKETS;                    // Amount of ticks for TB to consider DUT's next NS packet timed out
    unsigned MLD_TIMEOUT_TICKS;                  // Amount of ticks for TB to consider DUT's next MLD packet timed out
    unsigned NEIGHBOR_DISCOVERY_TRIES;           // Total Echoes
    unsigned NEIGHBOR_DISCOVERY_TIMEOUT_TICKS;   // Amount of ticks for TB to consider DUT's Echo reply timed out
    unsigned ECHO_INTERVAL_MIN_MS;               // Minimum interval (in ms) between Echo requests
    unsigned ECHO_INTERVAL_MAX_MS;               // Maximum interval (in ms) between Echo requests
    unsigned ECHO_TRIES;                         // Total Echoes
    unsigned ECHO_TIMEOUT_TICKS;                 // Amount of ticks for TB to consider DUT's Echo reply timed out
    unsigned ECHO_MIN_DATA_LEN;                  // Minimum Echo payload length
    unsigned ECHO_MAX_DATA_LEN;                  // Maximum Echo payload length
    unsigned PREFIX_PREFFERED_LIFETIME;          // Prefix preffered lifetime (ICMP RA Prefix option)
    uint32_t PREFIX_VALID_LIFETIME;              // Prefix valid lifetime (ICMP RA Prefix option)
    unsigned RDNSS_LIFETIME;                     // RDNSS lifetime (ICMP RDNSS option)
    unsigned ROUTER_LIFETIME;                    // Router lifetime in RAs
    unsigned ROUTER_REACH_TIME;                  // Router reach time in RAs
    unsigned ROUTER_RETRANS_TIME;                // Router retrans time in RAs
    unsigned ROUTER_SOLICITATION_SETTLE_TIMEOUT; // Ticks for DUT to receive RA packet
    uint32_t TCP_PLD_BYTES;                      // TCP test payload length
    unsigned TCP_WND_MSS_SCALE;                  // TCP TB MSS scale option value
    unsigned TCP_INIT_WND;                       // Initial TB TCP windows size
    float TIMEOUT_MAX_SCALE;                     // DAD timeout scale factor
    uint32_t RA_MTU;                             // Link MTU
    uint16_t TCP_MSS;                            // MSS advertised by Router
    uint16_t TCP_WND_SCALE;                      // Window Scale pption
    pkt_c::ip_t PREFIX_IP;                       // Prefix advertised by Router
    uint8_t PREFIX_LENGTH;                       // Prefix advertised by Router
    vector<pkt_c::ip_t> DNS_LIST;                // List of DNS server IPs
    pkt_c::mac_t TB_MAC;                         // MAC address of testbench
    pkt_c::mac_t DUT_MAC;                        // MAC address of DUT
    pkt_c::ip_t TB_LA;                           // Link-local address of testbench
    pkt_c::ip_t TB_GA;                           // Global address of testbench
    std::string DNS_HOSTNAME;                    // DNS hostname
    pkt_c::ip_t DNS_ANS_IP;                      // DNS answer IP

    prm_c(Vtop *tb)
    {
        // Addresses
        TB_GA = {0x20, 0x01, 0x48, 0x60,
                 0x48, 0x60, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x12, 0x34};

        TB_LA = {0xfe, 0x80, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00,
                 0x00, 0x00, 0x00, 0x00,
                 0x12, 0x34, 0x56, 0x78};
        // Ports
        TB_PORT = 1337;
        DUT_PORT = 1234;
        // DAD settings
        DAD_FAIL_SIM_TIMES = 5;
        DAD_TIMEOUT_TICKS = 1000000;
        MLD_TIMEOUT_TICKS = 1000000;
        DAD_DUT_PACKETS = tb->top->wrap->PARAM_DAD_TRIES;
        MLD_DUT_PACKETS = tb->top->wrap->PARAM_MLD_TRIES;
        // ICMP ND settings
        NEIGHBOR_DISCOVERY_TRIES = 20;
        NEIGHBOR_DISCOVERY_TIMEOUT_TICKS = 10000;
        // ICMP Echo settings
        ECHO_INTERVAL_MIN_MS = 1;
        ECHO_INTERVAL_MAX_MS = 10;
        ECHO_TRIES = 20;
        ECHO_TIMEOUT_TICKS = 10000;
        ECHO_MIN_DATA_LEN = 0;
        ECHO_MAX_DATA_LEN = 2 ^ tb->top->wrap->PARAM_ICMP_ECHO_FIFO_DEPTH;
        // Router settings
        ROUTER_LIFETIME = 1800;
        ROUTER_REACH_TIME = 0;
        ROUTER_RETRANS_TIME = 0;
        ROUTER_SOLICITATION_SETTLE_TIMEOUT = 10000;
        TCP_PLD_BYTES = 10000;
        TCP_WND_MSS_SCALE = 14;
        TCP_INIT_WND = 8192;
        TIMEOUT_MAX_SCALE = 2;
        RA_MTU = 1500;
        TCP_MSS = 1400;
        TCP_WND_SCALE = 14;
        // Prefix information
        PREFIX_PREFFERED_LIFETIME = 0;
        PREFIX_VALID_LIFETIME = 1800;
        PREFIX_LENGTH = 64;
        PREFIX_IP = {0x24, 0x01, 0x12, 0x34,
                     0x56, 0x78, 0x9a, 0xbc,
                     0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00};
        // RDNSS information
        DNS_DEFAULT_TTL = 64;
        RDNSS_LIFETIME = 3600;
        DNS_LIST.push_back({0x20, 0x01, 0x48, 0x60,
                            0x48, 0x60, 0x00, 0x00,
                            0x00, 0x00, 0x00, 0x00,
                            0x00, 0x00, 0x88, 0x88});

        DNS_LIST.push_back({0x20, 0x01, 0x48, 0x60,
                            0x48, 0x60, 0x00, 0x00,
                            0x00, 0x00, 0x00, 0x00,
                            0x00, 0x00, 0x88, 0x44});

        DNS_LIST.push_back({0x20, 0x01, 0x48, 0x60,
                            0x48, 0x60, 0x00, 0x00,
                            0x00, 0x00, 0x00, 0x00,
                            0x00, 0x00, 0x12, 0x34});
        TB_MAC = {0x42, 0x55, 0x92, 0x16, 0xde, 0xad};
        DUT_MAC = model_ifc_c::get_mac(tb->top->wrap->PARAM_MAC_ADDR);

        DNS_HOSTNAME = "\03www\07example\03com";
        DNS_ANS_IP = {0x24, 0x01, 0xab, 0xcd,
                      0xef, 0xdd, 0xcc, 0xbb,
                      0xab, 0xcd, 0xef, 0x00,
                      0x12, 0x34, 0x56, 0x78};
    };
};

#endif