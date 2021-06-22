
Command: ../../bin/frama-c -kernel-warn-key annot:missing-spec=abort -kernel-warn-key typing:implicit-function-declaration=abort -cpp-extra-args= make-wrapper.c make-wrapper2.c

[kernel] Parsing make-wrapper.c (with preprocessing)
[kernel] Parsing make-wrapper2.c (with preprocessing)

Command: ../../bin/frama-c -kernel-warn-key annot:missing-spec=abort -kernel-warn-key typing:implicit-function-declaration=abort -eva -eva-no-print -eva-no-show-progress -eva-msg-key=-initial-state -eva-print-callstacks -eva-warn-key alarm=inactive -no-deps-print -no-calldeps-print -eva-warn-key garbled-mix -calldeps -from-verbose 0 -eva-warn-key builtins:missing-spec=abort

[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:recursion] make-wrapper.c:14: 
  detected recursive call
  of function large_name_to_force_line_break_in_stack_msg.
[eva] make-wrapper.c:14: User Error: 
  Recursive call to large_name_to_force_line_break_in_stack_msg
  without a specification.
  Generating probably incomplete assigns to interpret the call. Try to increase
  the -eva-unroll-recursive-calls parameter or write a correct specification
  for function large_name_to_force_line_break_in_stack_msg.
  stack: large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:14 <-
         large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:18 <-
         rec :: make-wrapper.c:23 <-
         main
[kernel:annot:missing-spec] make-wrapper.c:13: Warning: 
  Neither code nor specification for function large_name_to_force_line_break_in_stack_msg, generating default assigns from the prototype
[kernel] User Error: warning annot:missing-spec treated as fatal error.
[kernel] Frama-C aborted: invalid user input.
[kernel] Warning: attempting to save on non-zero exit code: modifying filename into `PWD/make-for-make-wrapper.eva/framac.sav.error'.

***** make-wrapper recommendations *****

*** recommendation #1 ***

1. Found recursive call at:
  stack: large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:14 <-
         large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:18 <-
         rec :: make-wrapper.c:23 <-
         main

Consider patching, stubbing or adding an ACSL specification to the recursive call, then re-run the analysis.

*** recommendation #2 ***
2. Found function with missing spec: large_name_to_force_line_break_in_stack_msg
   Looking for files defining it...
Add the following file to the list of sources to be parsed:
  make-wrapper.c
