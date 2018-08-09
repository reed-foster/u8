#!/bin/bash
echo "compiling verilog"
verilator -Wall --cc ../rtl/memio/fifo/fifo.v --exe fifo_tb.cpp
cd obj_dir
echo "running make"
make -f Vfifo.mk Vfifo | sed 's/^/\t/'
echo "running TB"
./Vfifo | sed 's/^/\t/'
cd ..
