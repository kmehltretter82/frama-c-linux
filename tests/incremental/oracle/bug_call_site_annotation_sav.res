[kernel] Parsing bug_call_site_annotation.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:alarm] bug_call_site_annotation.c:16: Warning: 
  out of bounds read. assert \valid_read(argv + 0);
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- main.
  Called from bug_call_site_annotation.c:16.
[eva] bug_call_site_annotation.c:10: Call to builtin malloc
[eva] bug_call_site_annotation.c:10: allocating variable __malloc_foo_l10
[eva] bug_call_site_annotation.c:11: Call to builtin free
[eva] bug_call_site_annotation.c:11: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] bug_call_site_annotation.c:11: 
  strong free on bases: {__malloc_foo_l10}
[eva] Recording results for foo
[eva] Done for function foo
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function foo:
  __fc_heap_status ∈ [--..--]
  p ∈ ESCAPINGADDR
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  __retres ∈ {0}
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: foo
All allocated bases: {__malloc_foo_l10}
Allocation sites: {
                    malloc :: bug_call_site_annotation.c:10 <-
                    foo :: bug_call_site_annotation.c:16 <-
                    main; foo :: bug_call_site_annotation.c:16 <- main }
Call sites: { int *p = malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_foo_l10}
Allocation sites: {
                    malloc :: bug_call_site_annotation.c:10 <-
                    foo :: bug_call_site_annotation.c:16 <-
                    main; foo :: bug_call_site_annotation.c:16 <- main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_foo_l10}
Allocation sites: {
                    malloc :: bug_call_site_annotation.c:10 <-
                    foo :: bug_call_site_annotation.c:16 <-
                    main; foo :: bug_call_site_annotation.c:16 <- main }
Call sites: {
              /*@ assert Eva: mem_access: \valid_read(argv + 0); */
              foo(*(argv + 0)); }

Dynamic allocated bases: {[ __malloc_foo_l10 -> foo :: bug_call_site_annotation.c:16 <-
                                                main ]}
Malloced by stack: malloc :: bug_call_site_annotation.c:10 <-
                   foo :: bug_call_site_annotation.c:16 <-
                   main -> __malloc_foo_l10
