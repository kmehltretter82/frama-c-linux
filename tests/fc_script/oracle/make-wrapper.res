
Command: ../../bin/frama-c -kernel-warn-key annot:missing-spec=abort -kernel-warn-key typing:implicit-function-declaration=abort -cpp-extra-args= make-wrapper.c make-wrapper2.c

[kernel] Parsing make-wrapper.c (with preprocessing)
[kernel] Parsing make-wrapper2.c (with preprocessing)

Command: ../../bin/frama-c -kernel-warn-key annot:missing-spec=abort -kernel-warn-key typing:implicit-function-declaration=abort -eva -eva-no-print -eva-no-show-progress -eva-msg-key=-initial-state -eva-print-callstacks -eva-warn-key alarm=inactive -no-deps-print -no-calldeps-print -eva-warn-key garbled-mix -calldeps -from-verbose 0 -eva-warn-key builtins:missing-spec=abort

[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva] using specification for function specified
[kernel:annot:missing-spec] make-wrapper.c:17: Warning: 
  Neither code nor specification for function external, generating default assigns from the prototype
[kernel] User Error: warning annot:missing-spec treated as fatal error.
[kernel] Frama-C aborted: invalid user input.
[kernel] Warning: attempting to save on non-zero exit code: modifying filename into `PWD/make-for-make-wrapper.eva/framac.sav.error'.

***** make-wrapper recommendations *****

*** recommendation #1 ***

1. Found function with missing spec: external
   Looking for files defining it...
Add the following file to the list of sources to be parsed:
  make-wrapper3.c
