#!/bin/bash

PARAMS="-eva-no-cache-function -eva-msg-key=-initial-state,-final-states -eva-mlevel 2 -eva-no-alloc-returns-null -eva-slevel 8 -eva-show-slevel 1"

frama-c -save frama.0.sav *.c -eva $PARAMS -eva-statistics-file stat.0.csv -then -report-csv alarms.0.csv > eva.0.log

# This run with the simplify-callstack arg is more precise, show why !
frama-c -save frama.1.sav *.c -eva $PARAMS -eva-simplify-callstack=widenings -eva-statistics-file stat.1.csv -then -report-csv alarms.1.csv > eva.1.log