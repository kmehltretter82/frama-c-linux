[kernel] Parsing clean_abort.i (no preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  nondet ∈ [--..--]
  t[0..9] ∈ {0}
  g ∈ {0}
[eva] computing for function init <- main.
  Called from clean_abort.i:52.
[eva:alarm] clean_abort.i:28: Warning: 
  division by zero. assert (unsigned int)x ≢ 0;
[eva:alarm] clean_abort.i:30: Warning: 
  accessing out of bounds index. assert x < 10;
[eva:alarm] clean_abort.i:31: Warning: 
  accessing out of bounds index. assert i < 10;
[eva] clean_abort.i:32: assertion 'valid' got status valid.
[eva] Recording results for init
[eva] Done for function init
[eva] computing for function partial <- main.
  Called from clean_abort.i:53.
[eva] clean_abort.i:37: assertion 'valid' got status valid.
[eva:alarm] clean_abort.i:38: Warning: division by zero. assert x ≢ 0;
[eva] User Error: Stopping at nth alarm
[eva] Clean up and save partial results.
[kernel] Plug-in eva aborted: invalid user input.
[kernel] Warning: attempting to save on non-zero exit code: modifying filename into `clean_abort.sav.error'.
