[kernel] Parsing litterals_static.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  foo_help_msg[0] ∈ {{ "Msg" }}
[eva] computing for function foo <- main.
  Called from litterals_static.c:17.
[eva] computing for function printf_va_1 <- foo <- main.
  Called from litterals_static.c:12.
[eva] using specification for function printf_va_1
[eva] litterals_static.c:12: 
  function printf_va_1: precondition valid_read_string(param0) got status valid.
[eva] litterals_static.c:12: 
  function printf_va_1: precondition valid_read_string(format) got status valid.
[eva] Done for function printf_va_1
[eva] Recording results for foo
[eva] Done for function foo
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function foo:
  p ∈ {{ &foo_help_msg[0] }}
  S___fc_stdout[0..1] ∈ [--..--]
[eva:final-states] Values at end of function main:
  __retres ∈ {0}
  S___fc_stdout[0..1] ∈ [--..--]
