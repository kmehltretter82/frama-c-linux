#!/usr/bin/env python3

""" Filter for the cpp-command test. Expects $FRAMAC_SHARE as its first argument. """

import re
import sys

FRAMAC_SHARE = sys.argv[1]

for line in sys.stdin:
    # Apply several filters:
    # - Remove preprocessed filename (randomly generated)
    line = re.sub(r"/[^ ]*cpp-command.c......\.i", "<TMPDIR/PP>.i", line)
    # - Remove hardcoded path to temporary __fc_machdepXXXXXX.dir
    line = re.sub(r"-I.*__fc_machdep......\.dir", "-I<TMP_MACHDEP>", line)
    # - Replace occurrence of FRAMAC_SHARE; re.escape is needed if the path
    #   contains e.g. a '+' character
    line = re.sub(re.escape(f"-I{FRAMAC_SHARE}"), "-I<FRAMAC_SHARE>", line)
    # Remove spurious '-m32' and '-m64', which are architecture-dependent
    line = re.sub("-m32", "", line)
    line = re.sub("-m64", "", line)
    print(line.strip())
