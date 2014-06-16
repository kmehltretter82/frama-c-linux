#!/bin/sh

echo ""

# _v922-fileName-a
../Release/TC_C_121_v922 keya_good < stdin_hello_quit.txt
echo ""

# _v922-fileName-b
../Release/TC_C_121_v922 keyb_good < stdin_hello_quit.txt
echo ""

# _v922-fileName-c
../Release/TC_C_121_v922 keyc_good < stdin_hello_goodbye_quit.txt
echo ""

# _v922-fileName-bad-f
../Release/TC_C_121_v922 keyf_bad < stdin_hello_quit.txt
echo ""

# _fileName_L1_Bad
../Release/TC_C_121_v922 key1_bad_linux < stdin_hello_quit.txt
echo ""

