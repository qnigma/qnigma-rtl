ifneq ($(words $(CURDIR)),1)
 $(error Unsupported: GNU Make cannot build in directories containing spaces, build elsewhere: '$(CURDIR)')
endif

# Docker setup
DOCKER_IMAGE = verilator_docker_image
DOCKER_TAG = latest
DOCKER_RUN = docker run --rm -v $(CURDIR):/workspace -w /workspace $(DOCKER_IMAGE):$(DOCKER_TAG)

# Packages
PKG_SRC := $(shell find src -name '*_pkg.sv')

# Other modules
NON_PKG_SRC := $(filter-out $(PKG_SRC), $(shell find src -name '*.sv'))

# Concatenate both lists; packages come before other .sv files
SRC = $(PKG_SRC) $(NON_PKG_SRC)

# Define file containing REFCLK_HZ parameter value 
REFCLK_DEF_FILE = sim/network/refclk_hz.sv

# 125MHz system clock
REFCLK_HZ = 125000000 

# Configure simulation speedup
SIM_SPEED = 10000 # All timer tick this much faster

# Calculate simulation REFCLK_HZ parameter
REFCLK_HZ_SIM = $(shell expr $(REFCLK_HZ) / $(SIM_SPEED))

# Convert numbers to strings
REFCLK_HZ_HW_STRING = $(shell echo $(REFCLK_HZ))
REFCLK_HZ_SIM_STRING = $(shell echo $(REFCLK_HZ_SIM))

# Testbench source
SRC_CPP = $(wildcard ver/src/*.cpp)

# GTKwave executable
GTKWAVE = gtkwave

# Verilator executable
VERILATOR = /verilator/bin/verilator

# Verilator arguments
VERILATOR_ARGS += --trace
VERILATOR_ARGS += --exe
VERILATOR_ARGS += --j 8
VERILATOR_ARGS += --exe
VERILATOR_ARGS += -build
VERILATOR_ARGS += -cc
VERILATOR_ARGS += -Wno-WIDTH -Wno-SYMRSVDWORD
VERILATOR_ARGS += -top top

# Build Docker Image to run the simulations
build-docker :
		@echo "-- Building Docker Image --"
		docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

#################
## Testbenches ##
#################

# Aritmetic unit core
tb-alu-core :
		@echo "-- Building testbench [ALU] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/alu_core/top.sv ver/tests/alu_core/top.cpp ver/tests/alu_core/config.vlt
		@echo "-- Running testbench [ALU] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# Aritmetic unit
tb-alu :
		@echo "-- Building testbench [ALU] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/alu/top.sv ver/tests/alu/wrap.sv ver/tests/alu/top.cpp ver/tests/alu/config.vlt
		@echo "-- Running testbench [ALU] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# ChaCha20 Block function only
tb-chacha20 :
		@echo "-- Building testbench [ChaCha20] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/chacha20/top.sv ver/tests/chacha20/wrap.sv ver/tests/chacha20/top.cpp ver/tests/chacha20/config.vlt
		@echo "-- Running testbench [ChaCha20] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# ChaCha20 Keystream generation and encryption
tb-chacha20-kst :
		@echo "-- Building testbench [ChaCha20] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/chacha20_kst/top.sv ver/tests/chacha20_kst/wrap.sv ver/tests/chacha20_kst/top.cpp ver/tests/chacha20_kst/config.vlt
		@echo "-- Running testbench [ChaCha20] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# ECDH (curve25519)
tb-kex :
		@echo "-- Building testbench [Elliptic Curve Multiplier] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/kex/top.sv ver/tests/kex/wrap.sv ver/tests/kex/top.cpp ver/tests/kex/config.vlt
		@echo "-- Running testbench [Elliptic Curve Multiplier] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# Network core
tb-nw :
		@echo "-- Building testbench [Network] --"
		$(RM) src/network/refclk.sv
		@printf "localparam REFCLK_HZ = %d;" $(REFCLK_HZ_SIM) > src/network/refclk.sv
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/nw/top.sv ver/tests/nw/wrap.sv ver/tests/nw/top.cpp $(SRC_CPP) ver/tests/nw/config.vlt
		@echo "-- Running testbench [Network] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# Poly1305
tb-poly1305 :
		@echo "-- Building testbench [Poly1305] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/poly1305/top.sv ver/tests/poly1305/wrap.sv ver/tests/poly1305/top.cpp ver/tests/poly1305/config.vlt
		@echo "-- Running testbench [Poly1305] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

# MDIO
tb-mdio :
		@echo "-- Building testbench [MDIO] --"
		$(DOCKER_RUN) $(VERILATOR) $(VERILATOR_ARGS) $(SRC) ver/tests/mdio/top.sv ver/tests/mdio/wrap.sv ver/tests/mdio/qnigma_mdio_phy_emu.sv ver/tests/mdio/qnigma_mdio_phy_emu_serial.sv ver/tests/mdio/qnigma_mdio_phy_emu_ctrl.sv ver/tests/mdio/top.cpp ver/tests/mdio/config.vlt
		@echo "-- Running testbench [MDIO] --"
		$(DOCKER_RUN) chmod +x obj_dir/Vtop 
		$(DOCKER_RUN) ./obj_dir/Vtop
		@echo "-- Complete --"

all : tb-alu tb-chacha20 tb-chacha20-kst tb-kex tb-poly1305 tb-nw

clean:
	$(RM) -rf *.log *.pcap *.txt *.vcd obj_dir
