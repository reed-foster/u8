#!/bin/bash

modulename=asyncfifo
sourcedir=../rtl/memio/fifo
sourcelist=$sourcedir/asyncfifo.v $sourcedir/ffsync.v $sourcedir/ptrstatus.v
tb=asynchfifo_tb.cpp

echo "====================="
echo "COMPILING VERILOG"
echo "====================="
verilator -Wall --cc $sourcelist --exe $tb

cd obj_dir
echo "====================="
echo "RUNNING MAKE"
echo "====================="
make -j -f V$modulename".mk" V$modulename
echo "====================="
echo "RUNNING TB"
echo "====================="
./V$modulename
cd ..
