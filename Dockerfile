FROM ubuntu:latest

WORKDIR /verilator

ENV tz=Asia/Koltaka \
    DEBIAN_FRONTEND=noninteractive

#############################
## Verilator prerequisites ##
#############################
RUN apt-get update
RUN apt-get install git help2man perl python3 make autoconf g++ flex bison ccache -y
RUN apt-get install libgoogle-perftools-dev numactl perl-doc -y
RUN apt-get install libfl2  -y
RUN apt-get install libfl-dev -y
RUN apt-get install zlib1g -y
RUN apt-get install zlib1g-dev -y
RUN apt-get install tzdata
RUN apt-get install libbz2-dev -y
RUN apt-get install liblzma-dev -y
RUN apt-get install libgconf2-dev -y
RUN apt-get install libgtk2.0-dev -y
RUN apt-get install tcl-dev -y
RUN apt-get install tk-dev -y
RUN apt-get install gperf -y
RUN apt-get install gtk2-engines-pixbuf -y
RUN apt-get install libgtk-3-dev -y
RUN apt-get install cmake -y
RUN apt-get install xserver-xorg-core -y
RUN apt-get install xserver-xorg-input-mtrack -y
RUN apt-get install xserver-xorg-input-multitouch -y

###############################
## Verilator clone and build ##
###############################

RUN git clone https://github.com/verilator/verilator /verilator

# Get lastest tag
RUN latest_tag=$(git describe --tags --abbrev=0) && \
    echo "Latest Git tag: $latest_tag"

RUN git checkout $latest_tag

RUN unset VERILATOR_ROOT  

RUN echo "configuring verilator..."
RUN autoconf         # Create ./configure script
RUN ./configure      # Configure and create Makefile
RUN echo "making verilator..."
RUN make -j `nproc`  # Build Verilator itself (if error, try just 'make')

ENV VERILATOR_ROOT /verilator
RUN ./configure

RUN apt-get install gcc -y
