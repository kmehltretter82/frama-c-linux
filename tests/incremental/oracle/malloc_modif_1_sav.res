[kernel] Parsing malloc_modif_1.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- main.
  Called from malloc_modif_1.c:27.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- foo <- main.
  Called from malloc_modif_1.c:17.
[eva] malloc_modif_1.c:11: Call to builtin malloc
[eva] malloc_modif_1.c:11: allocating variable __malloc_alloc_l11
[eva] malloc_modif_1.c:12: Call to builtin free
[eva] malloc_modif_1.c:12: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] malloc_modif_1.c:12: strong free on bases: {__malloc_alloc_l11}
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for foo
[eva] Done for function foo
[eva:memexec] No previous call found for bar
[eva] computing for function bar <- main.
  Called from malloc_modif_1.c:28.
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- bar <- main.
  Called from malloc_modif_1.c:22.
[eva] malloc_modif_1.c:11: Call to builtin malloc
[eva] malloc_modif_1.c:11: allocating variable __malloc_alloc_l11_0
[eva] malloc_modif_1.c:12: Call to builtin free
[eva:malloc] malloc_modif_1.c:12: strong free on bases: {__malloc_alloc_l11_0}
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for bar
[eva] Done for function bar
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
All allocated bases: {__malloc_alloc_l11}
Allocation sites: {
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main }
Call sites: { alloc(); }

Kernel function: alloc
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main;
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main }
Call sites: { int *p = malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main;
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main;
                    alloc :: malloc_modif_1.c:17 <-
                    foo :: malloc_modif_1.c:27 <-
                    main;
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main }
Call sites: { foo();; bar(); }

Kernel function: bar
All allocated bases: {__malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: malloc_modif_1.c:11 <-
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main;
                    alloc :: malloc_modif_1.c:22 <-
                    bar :: malloc_modif_1.c:28 <-
                    main }
Call sites: { alloc(); }

Dynamic allocated bases: {[ __malloc_alloc_l11 -> alloc :: malloc_modif_1.c:17 <-
                                                  foo :: malloc_modif_1.c:27 <-
                                                  main
                            __malloc_alloc_l11_0 -> alloc :: malloc_modif_1.c:22 <-
                                                    bar :: malloc_modif_1.c:28 <-
                                                    main ]}
Malloced by stack: malloc :: malloc_modif_1.c:11 <-
                   alloc :: malloc_modif_1.c:17 <-
                   foo :: malloc_modif_1.c:27 <-
                   main -> __malloc_alloc_l11
Malloced by stack: malloc :: malloc_modif_1.c:11 <-
                   alloc :: malloc_modif_1.c:22 <-
                   bar :: malloc_modif_1.c:28 <-
                   main -> __malloc_alloc_l11_0
