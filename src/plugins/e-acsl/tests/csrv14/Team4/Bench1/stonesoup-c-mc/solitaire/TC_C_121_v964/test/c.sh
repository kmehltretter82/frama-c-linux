#!/bin/sh

export TARGET=TC_C_121_v964
cd /media/sf_eclipse
rm "$TARGET/Release/$TARGET"; make linall

#end of file
