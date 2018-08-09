#!/bin/bash

modulename=asyncfifo
sourcedir=../rtl/memio/fifo
sourcelist="$sourcedir/asyncfifo.v $sourcedir/ffsync.v $sourcedir/ptrstatus.v"
./tb.sh $modulename $sourcelist
