[kernel] Parsing malloc_no_modif.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- main.
  Called from malloc_no_modif.c:26.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- foo <- main.
  Called from malloc_no_modif.c:16.
[eva] malloc_no_modif.c:10: Call to builtin malloc
[eva] malloc_no_modif.c:10: allocating variable __malloc_alloc_l10
[eva] malloc_no_modif.c:11: Call to builtin free
[eva] malloc_no_modif.c:11: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] malloc_no_modif.c:11: strong free on bases: {__malloc_alloc_l10}
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for foo
[eva] Done for function foo
[eva:memexec-malloc] 
  --- Reused allocated bases {__malloc_alloc_l10} for KF foo at callstack 
  foo :: malloc_no_modif.c:27 <- main
[eva] malloc_no_modif.c:27: Reusing old results for call to foo
[eva:memexec] No previous call found for bar
[eva] computing for function bar <- main.
  Called from malloc_no_modif.c:28.
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- bar <- main.
  Called from malloc_no_modif.c:21.
[eva] malloc_no_modif.c:10: Call to builtin malloc
[eva] malloc_no_modif.c:10: allocating variable __malloc_alloc_l10_0
[eva] malloc_no_modif.c:11: Call to builtin free
[eva:malloc] malloc_no_modif.c:11: strong free on bases: {__malloc_alloc_l10_0}
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for bar
[eva] Done for function bar
[eva:memexec-malloc] 
  --- Reused allocated bases {__malloc_alloc_l10_0} for KF bar at callstack 
  bar :: malloc_no_modif.c:29 <- main
[eva] malloc_no_modif.c:29: Reusing old results for call to bar
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function alloc:
  __fc_heap_status ∈ [--..--]
  p ∈ ESCAPINGADDR
[eva:final-states] Values at end of function bar:
  __fc_heap_status ∈ [--..--]
[eva:final-states] Values at end of function foo:
  __fc_heap_status ∈ [--..--]
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  __retres ∈ {0}
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: foo
All allocated bases: {__malloc_alloc_l10}
Allocation sites: {
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main }
Call sites: { alloc(); }

Kernel function: alloc
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main;
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main }
Call sites: { int *p = malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main;
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main;
                    alloc :: malloc_no_modif.c:16 <-
                    foo :: malloc_no_modif.c:26 <-
                    main;
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main }
Call sites: { foo();; bar(); }

Kernel function: bar
All allocated bases: {__malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_no_modif.c:10 <-
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main;
                    alloc :: malloc_no_modif.c:21 <-
                    bar :: malloc_no_modif.c:28 <-
                    main }
Call sites: { alloc(); }

Dynamic allocated bases: {[ __malloc_alloc_l10 -> alloc :: malloc_no_modif.c:16 <-
                                                  foo :: malloc_no_modif.c:26 <-
                                                  main
                            __malloc_alloc_l10_0 -> alloc :: malloc_no_modif.c:21 <-
                                                    bar :: malloc_no_modif.c:28 <-
                                                    main ]}
Malloced by stack: malloc :: malloc_no_modif.c:10 <-
                   alloc :: malloc_no_modif.c:16 <-
                   foo :: malloc_no_modif.c:26 <-
                   main -> __malloc_alloc_l10
Malloced by stack: malloc :: malloc_no_modif.c:10 <-
                   alloc :: malloc_no_modif.c:21 <-
                   bar :: malloc_no_modif.c:28 <-
                   main -> __malloc_alloc_l10_0
