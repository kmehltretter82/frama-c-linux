#!/bin/sh

# Sample script showing usage of `bm.gnuplot` script

# Path to gnuplot script
BM_GNUPLOT="../../tools/bm.gnuplot"

# Build a line plot using lineplot.dat data file
gnuplot \
    -e "BaseFile='dat/lineplot'" \
    -e "Style='lines'" \
    -e "WithOverheads=1" \
    -e "PlotTitle='Sample line plot title'" \
    -e "XLabel='Sample line plot label of X axis'" \
    -e "YLabel='Sample line plot label of Y axis'" \
    -e "OutputDir='.'" \
    -e "WithOverheads='1'" \
    $BM_GNUPLOT

# Build a histogram using barplot.dat data file
gnuplot \
    -e "BaseFile='dat/barplot'" \
    -e "Style='histogram'" \
    -e "WithOverheads=1" \
    -e "PlotTitle='Sample histogram title'" \
    -e "XLabel='Sample histogram label of X axis'" \
    -e "YLabel='Sample histogram label of Y axis'" \
    -e "OutputDir='.'" \
    -e "WithOverheads='1'" \
    $BM_GNUPLOT

exit 0
