#!/bin/sh

echo ""

# _FileContentsGooda
../Release/TC_C_121_v968 keya_good < stdin_hello_quit.txt
echo ""

# _FileContentsGoodb
../Release/TC_C_121_v968 keyb_good < stdin_hello_quit.txt
echo ""

# _FileContentsGoodc
../Release/TC_C_121_v968 keyc_good < stdin_hello_quit.txt
echo ""

# _FileContentsGoodd
../Release/TC_C_121_v968 keyd_good < stdin_hello_quit.txt
echo ""

# _FileContentsGoode
../Release/TC_C_121_v968 keye_good < stdin_hello_quit.txt
echo ""

# _FileContentsBadf
../Release/TC_C_121_v968 keyf_bad < stdin_hello_quit.txt
echo ""

