#!/bin/sh
gcc -C -E -I. -o $2 $1
dos2unix -q $2
