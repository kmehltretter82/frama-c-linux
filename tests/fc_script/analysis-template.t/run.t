  $ awk '/^EVAFLAGS/ {print;print "  -eva-stop-at-nth-alarm 0 \\";next};1' $(frama-c -print-lib-path)/analysis-scripts/template.mk > GNUmakefile
  $ make 2>&1 | grep "save partial results"
  [eva] Clean up and save partial results.
  $ if [ -f main.eva/framac.sav.error ]; then
  > echo "OK! Partial save file exists"; fi
  OK! Partial save file exists
