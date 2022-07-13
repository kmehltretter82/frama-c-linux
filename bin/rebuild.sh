#!/bin/sh
autoconf -f && ./configure && make -k clean && make -k
