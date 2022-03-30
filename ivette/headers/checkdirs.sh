#!/bin/sh -e

for d in `find src -type d`
do
    headers/checkdir $d
done
