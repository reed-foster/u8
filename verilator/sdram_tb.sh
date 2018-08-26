#!/bin/bash

modulename=sdram
sourcedir=../rtl/memio/
sourcelist="$sourcedir/sdram/sdram.v $sourcedir/fifo/asyncfifo.v $sourcedir/fifo/ffsync.v $sourcedir/fifo/ptrstatus.v"
./tb.sh $modulename $sourcelist
