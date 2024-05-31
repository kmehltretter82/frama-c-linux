[kernel] Parsing litterals_global.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  s1 ∈ {{ "Hello" }}
  s2 ∈ {{ "World" }}
[eva] computing for function printf_va_1 <- main.
  Called from litterals_global.c:14.
[eva] using specification for function printf_va_1
[eva] litterals_global.c:14: 
  function printf_va_1: precondition valid_read_string(param0) got status valid.
[eva] litterals_global.c:14: 
  function printf_va_1: precondition valid_read_string(param1) got status valid.
[eva] litterals_global.c:14: 
  function printf_va_1: precondition valid_read_string(format) got status valid.
[eva] Done for function printf_va_1
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function main:
  __retres ∈ {0}
  S___fc_stdout[0..1] ∈ [--..--]
