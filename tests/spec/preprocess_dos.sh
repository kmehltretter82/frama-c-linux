#!/bin/sh
gcc -C -E -I. -o $3 $2
$1 -q $3
