First we 'touch' the files to update their timestamp, so that the 'make'
command will re-run the analysis
  $ touch make-wrapper2.c make-wrapper3.c

In case of errors, consider removing the '-s' and 'SILENT=yes' options below
to get a more verbose output for Make.
  $ PTESTS_TESTING=1 frama-c-script make-wrapper --make-dir . -f make-for-make-wrapper.mk -s SILENT=yes
  [kernel] Parsing make-wrapper.c (with preprocessing)
  [kernel] Parsing make-wrapper2.c (with preprocessing)
  [eva] Analyzing a complete application starting at main
  [eva:recursion] make-wrapper.c:17: 
    detected recursive call
    of function large_name_to_force_line_break_in_stack_msg.
  [eva:assigns:missing] make-wrapper.c:17: User Error: 
    Recursive call to large_name_to_force_line_break_in_stack_msg without assigns clause.
    Generating probably incomplete assigns to interpret the call.
    Try to increase the -eva-unroll-recursive-calls parameter or write a correct specification for function large_name_to_force_line_break_in_stack_msg.
     stack: large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:17 <-
            large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:21 <-
            rec :: make-wrapper.c:26 <-
            main
  [eva] using specification for function large_name_to_force_line_break_in_stack_msg
  [eva] using specification for function specified
  [kernel:annot:missing-spec] make-wrapper.c:29: Failure: 
    Neither code nor specification for function external,
     generating default assigns. See -generated-spec-* options for more info
  [kernel] User Error: warning annot:missing-spec treated as fatal error.
  [kernel] Frama-C aborted: invalid user input.
  
  ***** make-wrapper recommendations *****
  
  *** recommendation #1 ***
  
  1. Found recursive call at:
     stack: large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:17 <-
            large_name_to_force_line_break_in_stack_msg :: make-wrapper.c:21 <-
            rec :: make-wrapper.c:26 <-
            main
  
  Consider patching, stubbing or adding an ACSL specification to the recursive call, then re-run the analysis.
  
  *** recommendation #2 ***
  2. Found function with missing specification: external
     Looking for files defining it...
  Add the following file to the list of sources to be parsed:
    make-wrapper3.c
