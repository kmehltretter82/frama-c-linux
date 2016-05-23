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

# Usage information of a script
#
# Gnuplot script for building line graphs and histograps
#
# The script should be invoked as follows:
#  gnuplot \
#    -e "BaseFile='<Base name of .dat file>' \
#    -e "Style='<lines|histogram>' \
#    -e "PlotTitle='<Optional: Plot title: [BaseFile]>'"
#    -e "XLabel='<Optional: X-axis label: [""]>'"
#    -e "YLabel='<Optional: Y-axis label: ["1st column title"]>'"
#    -e "OutputDir='<Optional: directory where to place output files>'"
#    -e "WithOverheads='<ANY>'"
#   data.plot
#
# Arguments:
# - BaseName - base name of a data file with data to plot. This script expects
#     BaseName.dat to exist and contain data. E.g., if the provided value is
#     'foo/bar', then foo/bar.dat file should exist
# - Style - a compulsory argument indicating the type of a plot to be constructed.
# Allowed values are 'histogram' or 'lines'. If 'lines' value is given then
# this script builds a line plot expecting the data file be of the form:
#  YLabel XLabel1 XLabel2 ...
#  YValue XValue1 XValue2 ...
#  ...
# If 'histogram' argument is specified a data file is expected to be of the form:
#  GroupLabel   Label2 Label3 Label4
#  Group1       Value1 Value2 Value3 ...
#  Group2       Value1 Value2 Value3 ...
#  ...
# - XLabel - optional string used a X-axis label
# - YLabel - optional string used a Y-axis label
# - PlotTitle - optional string used a plot title
# - OutputDir - optional directory for placement of resulting pdf files
# - WithOverheads - if any value is given to this argument then the script
#    computes overheads relative to the values in the second column

# Check if a given file exists
file_exists(file) = system("test -f '".file."' && echo '1' || echo '0'") + 0

if (exists("Style") && (Style eq "histogram" && Style eq "lines")) {
  print "ERROR: Unknown histogram style [histogram|lines]"
  print "See inline comments for details"
  exit 1
}

# Check if the base name of the datafile (name - extension .dat)
# is given via commandline
if (!exists("BaseFile")) {
  print "ERROR: Variable 'BaseFile' should be set via commandline"
  print "See inline comments for details"
  exit
}

# Set datafile name
DataFile = BaseFile.'.dat'

# Check if it exists
if (!file_exists(DataFile)) {
  print "ERROR: ".DataFile." not found."
  print "See inline comments for details"
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
set linetype 6 linewidth 2 linecolor rgb "#666633" pointtype 6  pointsize 0.7 # Dark yellow
set linetype 5 linewidth 2 linecolor rgb "#006633" pointtype 5  pointsize 0.7 # Green
set linetype 4 linewidth 2 linecolor rgb "#000000" pointtype 4  pointsize 0.7 # Black
set linetype 3 linewidth 2 linecolor rgb "#990099" pointtype 3  pointsize 0.7 # Magenta
set linetype 2 linewidth 2 linecolor rgb "#000066" pointtype 8  pointsize 0.7 # Dark blue
set linetype 1 linewidth 2 linecolor rgb "#990000" pointtype 7  pointsize 0.7 # Maroon

# Use the postscript terminal, as a PDF one is not fully featured
set terminal postscript landscape size 10,7 enhanced color font BaseFont

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

PsFile = BaseFile.'.ps'
PdfFile = BaseFile.'.pdf'

if (exists("OutputDir")) {
  PsFile = OutputDir."/".system("basename ".DataFile)
  PdfFile = OutputDir."/".system("basename ".PdfFile)
}

Columns=`tail -n 1 @DataFile | wc -w`

# Set output file command
set output PsFile

# Overhead plotting function
#   nat - time of an original executable
#   mod -= time of the modified executable
# If WithOverheads var is defined then compute overheads, otherwise plot as is
ovh(nat, mod) = exists("WithOverheads") ? mod/nat : mod

###################
# Plotting
###################
# Build a line plot
if (Style eq "lines") {
  plot for [COL = 2:Columns] DataFile \
    using 1:(ovh(column(2), column(COL))) title columnheader(COL) with linespoints
}

# Build a histogram
if (Style eq "histogram") {
  set yrange [0:]
  set style data histogram
  set style fill solid border -1
  plot for [COL=2:Columns] DataFile using (ovh(column(2), column(COL))):xticlabels(1) title columnheader
}

# At this point postscript is generated, create PDF
!ps2pdf @PsFile @PdfFile
!rm @PsFile


