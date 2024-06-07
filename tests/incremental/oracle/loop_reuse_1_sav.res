[kernel] Parsing loop_reuse_1.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  a ∈ {0}
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for loop
[eva] computing for function loop <- main.
  Called from loop_reuse_1.c:18.
[eva] loop_reuse_1.c:10: starting to merge loop iterations
[eva:widening] loop_reuse_1.c:10: applying a widening at this point
[eva:alarm] loop_reuse_1.c:12: Warning: 
  signed overflow. assert a + 1 ≤ 2147483647;
[eva] Recording results for loop
[eva] Done for function loop
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function loop:
  a ∈ [0..2147483647]
  i ∈ {10}
[eva:final-states] Values at end of function main:
  a ∈ [0..2147483647]
  __retres ∈ {0}
