#! /bin/sh
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2019                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  All rights reserved.                                                  #
#  Contact CEA LIST for licensing.                                       #
#                                                                        #
##########################################################################


for f in `svn list -R`; do
  # 'svn list' lists also files and directories removed from the SVN
  if test -e $f; then
    if test -z "`svn propget maindev $f `"; then
      echo MAINTENER: $f
    fi
    R=`svn propget codev $f | wc -l`
    if test $R -ne 1 -a $R -ne 2; then
      echo CODEV: $f
    fi
  fi
done
