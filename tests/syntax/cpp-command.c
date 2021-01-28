/* run.config*
<<<<<<< HEAD
   FILTER: sed -e "s:/\(tmp\|var\|build\)/[^ ]*\.i:/tmp/FILE.i:g; s:$PWD:.:g; s:-I.*share/frama-c/share/libc:-I LIBC:g"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo [\$(basename '%1') \$(basename '%1') \$(basename '%i') \$(basename '%input')] ['%2' '%2' '%o' '%output'] ['%args']"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo %%1 = \$(basename '%1') %%2 = '%2' %%args = '%args'"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "printf \"%s\" \"using \\% has no effect : \$(basename \"\%input\")\""
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo %var is not an interpreted placeholder"
   OPT: -machdep x86_32 -print-cpp-commands
||||||| ac7807782d
   FILTER: sed "s:/\(tmp\|var\|build\)/[^ ]*\.i:/tmp/FILE.i:g; s:$PWD/::"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo [\$(basename '%1') \$(basename '%1') \$(basename '%i') \$(basename '%input')] ['%2' '%2' '%o' '%output'] ['%args']"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %%1 = \$(basename '%1') %%2 = '%2' %%args = '%args'"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "printf \"%s\" \"using \\% has no effect : \$(basename \"\%input\")\""
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %var is not an interpreted placeholder"
   OPT: -no-autoload-plugins -print-cpp-commands
=======
   FILTER: sed "s:/[^ ]*/cpp-command\.[^ ]*\.i:TMPDIR/FILE.i:g; s:$PWD/::; s: -m32::"
   OPT: -machdep x86_32 -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo [\$(basename '%1') \$(basename '%1') \$(basename '%i') \$(basename '%input')] ['%2' '%2' '%o' '%output'] ['%args']"
   OPT: -machdep x86_32 -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %%1 = \$(basename '%1') %%2 = '%2' %%args = '%args'"
   OPT: -machdep x86_32 -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "printf \"%s\n\" \"using \\% has no effect : \$(basename \"\%input\")\""
   OPT: -machdep x86_32 -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %var is not an interpreted placeholder"
   OPT: -machdep x86_32 -no-autoload-plugins -print-cpp-commands
>>>>>>> origin/master
   */
