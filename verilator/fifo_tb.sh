#!/bin/bash

modulename=fifo
sourcedir=../rtl/memio/fifo
sourcelist="$sourcedir/fifo.v"
./tb.sh $modulename $sourcelist
