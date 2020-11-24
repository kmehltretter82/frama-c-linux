/* run.config*
   FILTER: sed "s:/[^ ]*/cpp-command\.[^ ]*\.i:TMPDIR/FILE.i:g; s:$PWD/::; s: -m32::"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo [\$(basename '%1') \$(basename '%1') \$(basename '%i') \$(basename '%input')] ['%2' '%2' '%o' '%output'] ['%args']"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %%1 = \$(basename '%1') %%2 = '%2' %%args = '%args'"
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "printf \"%s\n\" \"using \\% has no effect : \$(basename \"\%input\")\""
   OPT: -no-autoload-plugins -cpp-frama-c-compliant -cpp-command "echo %var is not an interpreted placeholder"
   OPT: -no-autoload-plugins -print-cpp-commands
   */
