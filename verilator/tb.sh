#!/bin/bash

modulename=$1
sourcelist=${*:2:$# - 1}
tb=$modulename"_tb.cpp"

echo "====================="
echo "COMPILING VERILOG"
echo "====================="
verilator -Wall --trace --cc $sourcelist --exe $tb

cd obj_dir
echo "====================="
echo "RUNNING MAKE"
echo "====================="
make -j -f V$modulename.mk V$modulename
echo "====================="
echo "RUNNING TB"
echo "====================="
./V$modulename
cd ..
