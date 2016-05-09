#!/usr/bin/env gnuplot

##########################################################################
#                                                                        #
#  This file is part of the Frama-C's E-ACSL plug-in.                    #
#                                                                        #
#  Copyright (C) 2012-2016                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file license/LGPLv2.1).             #
#                                                                        #
##########################################################################

print "========================================================================"
print " Gnuplot script for building line graphs using a data file of the form:"
print " X     Y1   Y2 ... YN"
print " 100   2    3      4"
print " ...."
print ""
print " where X, Y1 ... YN are labels and"
print "   values of column X are used for x-axis"
print "   values of columns Y1 ... YN are used for y-axis"
print ""
print " The script should be invoked as follows:"
print "  gnuplot  \\"
print "    -e \"BaseFile='<Compulsory: Base name of a .dat file>'\" \\"
print "    -e \"PlotTitle='<Optional: Plot title: [BaseFile] >'\" \\"
print "    -e \"XLabel='<Optional: X-axis label: [\"\"]>'\" \\"
print "    -e \"YLabel='<Optional: Y-axis label: [\"1st column title\"]>'\" \\"
print "    -e \"WithOverheads='<ANY>'\" \\"
print "   data.plot"
print "========================================================================"

# Check if a given file exists
file_exists(file) = system("test -f '".file."' && echo '1' || echo '0'") + 0

# Check if the base name of the datafile (name - extension .dat)
# is given via commandline
if (!exists("BaseFile")) {
  print "ERROR: Variable 'BaseFile' should be set via commandline"
  exit
}

# Set datafile name
DataFile = BaseFile.'.dat'

# Check if it exists
if (!file_exists(DataFile)) {
  print "ERROR: ".DataFile." not found."
  exit
}

# Unless specified the plot title is named after the base name of the file
if (!exists("PlotTitle"))
  PlotTitle = BaseFile
# Unless specified the Y axis label is the leftmost column header
if (!exists("YLabel"))
  YLabel = word(system(sprintf("head -n 1 %s", DataFile)),1)
# Unless specified Y label is empty
if (!exists("XLabel"))
  XLabel = ""

# Fonts and background
Background      = '#F7F7F7'
BaseFont        = 'Arial,14'
TicsFont        = "Arial,10"
LegendFont      = "Arial,12"
SideLabelFont   = "Arial-Bold,16"

# Line colours
set linetype 6 linecolor rgb "#666633" # Dark yellow
set linetype 5 linecolor rgb "#006633" # Green
set linetype 4 linecolor rgb "#000000" # Black
set linetype 3 linecolor rgb "#990099" # Magenta
set linetype 2 linecolor rgb "#000066" # Dark blue
set linetype 1 linecolor rgb "#990000" # Maroon

# Use the postscript terminal, as a PDF one is not fully featured
set terminal postscript landscape size 10,7 enhanced color font BaseFont linewidth 3

# Set background colour for the plot area
set object 1 rectangle from graph 0, graph 0 to graph 1, graph 1 behind fc rgbcolor Background fs noborder

# Set font for ticks and make them appear outside
# nomirror removes x2ticks and y2ticks (top and right)
set ytics font TicsFont out nomirror
set xtics font TicsFont out nomirror

set autoscale

# Legend font
set key on horizontal font LegendFont

# PlotTitle variable should come from environment via -e
set title PlotTitle

# Enable fonts for side labels
set xlabel XLabel font SideLabelFont
set ylabel YLabel font SideLabelFont

# Enable macros
set macros

OutFile = BaseFile.'.ps'
PdfFile = BaseFile.'.pdf'
Columns=`tail -n 1 @DataFile | wc -w`

# Set output file command
set output OutFile

# Overhead plotting function
#   nat - time of an original executable
#   mod -= time of the modified executable
# If WithOverheads var is defined then compute overheads, otherwise plot as is
ovh(nat, mod) = exists("WithOverheads") ? mod/nat : mod

# Plotting command
plot for [COL = 2:Columns] DataFile \
  using 1:(ovh(column(2), column(COL))) title columnheader(COL) with lines

# At this point postscript is generated, create PDF
!ps2pdf @OutFile @PdfFile
!rm @OutFile
