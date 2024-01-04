# qnigma-rtl
Main RTL code and verification. For technical documentation, see [wiki](https://github.com/qnigma/qnigma-rtl/wiki)
# Introduction
qnigma is a project with a goal of creating a full-hardware encryption and authentication device. It aims to provide a restricted functionality of SSHv2: `curve25519-sha256` key exhange and `chacha20-poly1305` AEAD schemes. PQC schemes are under discussion and should be added according to the PQC algorithms that get into the standard. The implementation is based on RFC documents, but does not follow them completely due to limitations imposed by the target being a low-cost FPGA. 

The project consists of 3 parts:
1. Networking: IPv6, ICMPv6, TCP, DNS
2. "Classic" cryptography: Curve25519 and ChaCha20-Poly1305 AEAD
3. Post-quantum cryptography: TBD

# Features

- IPv6 stack with ICMPv6 <a href="https://datatracker.ietf.org/doc/html/rfc4443">RFC4443</a>
  - Stateless Address Autoconfiguration
    - Router Discovery
    - Duplicate Address Detection <a href="https://datatracker.ietf.org/doc/html/rfc4861">RFC4861</a>
    - Prefix processing from Router Advertisements (RA)
    - Global address generation
  - DNS servers address processing from RA
  - Multicast Listener Discovery Version 2 <a href="https://datatracker.ietf.org/doc/html/rfc3810">RFC3810</a>  
- ICMP Echo
  - Echo payload supported 
- DNS client <a href="https://datatracker.ietf.org/doc/html/rfc3596">RFC3596</a>  
  - Acquire IPv6 with DNS server from RA
  - Handle validity timers
  - Handle timeouts and retransmissions
- TCP/IP stack
  - Connection management:
    - Connection by IP or hostname
    - Connection by hostname uses DNS
    - Keep-Alive (rx/tx) 
    - Automatic disconnect/reconnect
  - Transmission management:
    - Transmission packet queue with individual timers
    - Remote window tracking
    - SACK-capable (rx/tx) <a href="https://datatracker.ietf.org/doc/html/rfc2018">RFC2018</a>  
    - Duplicate Ack detection
    - SACK retransmissions 
    - Fast retransmissions
  - Receive management:
    - Receive queue reordering
    - SACK option generation
Below are the features tested in simulation
- ECDHE
  - Curve25519 implementation (simulaton only)
  - Elliptic curve multiplication using Montgomery ladder (simulaton only)
  - Pipelined schoolbook multiplier (simulaton only)
- ChaCha20-Poly1305 AEAD scheme
  - ChaCha20 (simulaton only)
  - Poly1305 (simulaton only)

With all the above features, qnigma networking core allows the FPGA to communcate with devices on the Internet with the convenience of DNS. It can operate in client (active) or server (passive) modes. TCP/IP operation over the Internet is stable at least at low speeds.

# Design choices
2. IPv6 was selected due to ease of implementation and increasing adoption. It is the protocol to use in the upcoming future. IPv4 is not supported at the benefit of less resource utilization 
1. TCP/IP is the transport layer for SSH and TLS. It is robust against packet loss. Properly configured RTL and advanced features such as SACK and fast retransmissions provide a reliable connection
3. Only necessary IPv6/ICMPv6 features are currently implmenented
4. DHCPv6 is not implemented since address resolution and DNS server discovery is handled by ICMPv6. Need for DHCPv6 Address Delegation feature is TBD
5. DNS is implemented due to ease of connecting to remote server
6. Curve25519 was selected due to being very efficient in both being a Montgomery curve and the underlying modular arithmetic
7. ChaCha20-Poly1305 AEAD was selected for being fast and straigthforward do implement while having a low footprint. Another advantage is that Poly1305 arithmetic is similar to Curve25519 (both primes are almost Meresenne). This allows the arithmetic unit to be reused
8. PQC schemes are TBD, but will most likely include lattice-based.

# Simulation

The project is validated with Verilator. Verification code is in `/src`. 

## Running the simulation
### Prerequisites:
1. make
2. docker
### Build Docker image
Run `make build-docker` to create the image in which we'll be running the simulation. This may take a while. 
### Run the simulation
Run `make tb-nw` to compile and execute qnigma networking core simulation. Notice the output products: pcap and vcd files. 

See Makefile for all available testbenches.


### Arithemtic Logic Unit

1. 