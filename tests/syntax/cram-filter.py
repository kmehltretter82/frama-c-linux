#!/usr/bin/env python3

"""Filter used in some Cram tests."""

import os
import re
import sys

tmpdir = os.getenv("TMPDIR", "/tmp")

for line in sys.stdin:
    # Apply several filters:

    # - Remove preprocessed filename (randomly generated)
    line = re.sub(r"/[^ ]*cpp-command.c......\.i", "<TMPDIR/PP>.i", line)

    # - Remove hardcoded path to temporary __fc_machdepXXXXXX.dir.
    # Example: -I'/tmp/build_dd860b_dune/__fc_machdep0a85ad.dir' -> -I'<TMP_MACHDEP>'
    line = re.sub(r"-I'[^']+__fc_machdep.{6}\.dir'", "-I'<TMP_MACHDEP>'", line)

    # - In cpp-command.t, the previous regex is not enough, so we apply this one,
    #   which is "more aggressive" but can match too much in some cases
    line = re.sub(r"-I.*__fc_machdep......\.dir", "-I<TMP_MACHDEP>", line)

    # - Remove temporary GCC output file name (randomly generated)
    # Example: -o '/tmp/build_7990c8_dune/force-posix.ca9f082.i' -> -o /tmp/TEMPNAME
    line = re.sub(r"-o '" + tmpdir + r"/[^']+\.c.{6}\.i'", "-o /tmp/TEMPNAME", line)

    # Remove spurious '-m32' and '-m64', which are architecture-dependent
    line = re.sub("-m32", "", line)
    line = re.sub("-m64", "", line)

    print(line.strip())
