#!/bin/sh
case "$1" in
    Makefile.distrib | *.json | src/dome/doc/* | */.eslintrc.js )
        echo "$1: .ignore"
        ;;
    *Make* | src/*/*.js* | src/*/*.ts* )
        echo "$1: CEA_LGPL"
        ;;
    *)
        echo "$1: .ignore"
        ;;
esac
