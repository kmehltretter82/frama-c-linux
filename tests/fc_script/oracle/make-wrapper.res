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
