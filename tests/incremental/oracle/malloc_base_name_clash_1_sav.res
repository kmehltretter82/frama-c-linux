[kernel] Parsing malloc_base_name_clash_1.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- main.
  Called from malloc_base_name_clash_1.c:26.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- foo <- main.
  Called from malloc_base_name_clash_1.c:16.
[eva] malloc_base_name_clash_1.c:10: Call to builtin malloc
[eva] malloc_base_name_clash_1.c:10: allocating variable __malloc_alloc_l10
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for foo
[eva] Done for function foo
[eva:memexec] No previous call found for bar
[eva] computing for function bar <- main.
  Called from malloc_base_name_clash_1.c:27.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- bar <- main.
  Called from malloc_base_name_clash_1.c:21.
[eva] malloc_base_name_clash_1.c:10: Call to builtin malloc
[eva] malloc_base_name_clash_1.c:10: allocating variable __malloc_alloc_l10_0
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for bar
[eva] Done for function bar
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function alloc:
  __fc_heap_status ∈ [--..--]
  p ∈ {{ &__malloc_alloc_l10 ; &__malloc_alloc_l10_0[0] }}
  __malloc_alloc_l10 ∈ {0}
  __malloc_alloc_l10_0[0] ∈ {0}
                      [1] ∈ UNINITIALIZED
[eva:final-states] Values at end of function bar:
  __fc_heap_status ∈ [--..--]
  __malloc_alloc_l10_0[0] ∈ {0}
                      [1] ∈ UNINITIALIZED
[eva:final-states] Values at end of function foo:
  __fc_heap_status ∈ [--..--]
  __malloc_alloc_l10 ∈ {0}
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  __retres ∈ {0}
  __malloc_alloc_l10 ∈ {0}
  __malloc_alloc_l10_0[0] ∈ {0}
                      [1] ∈ UNINITIALIZED
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: alloc
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main }
Call sites: { int *p = malloc(sizeof(int) * (unsigned long)size); }

Kernel function: malloc
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_alloc_l10, __malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main }
Call sites: { foo();; bar(); }

Kernel function: bar
All allocated bases: {__malloc_alloc_l10_0}
Allocation sites: {
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:21 <-
                    bar :: malloc_base_name_clash_1.c:27 <-
                    main }
Call sites: { alloc(2); }

Kernel function: foo
All allocated bases: {__malloc_alloc_l10}
Allocation sites: {
                    malloc :: malloc_base_name_clash_1.c:10 <-
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main;
                    alloc :: malloc_base_name_clash_1.c:16 <-
                    foo :: malloc_base_name_clash_1.c:26 <-
                    main }
Call sites: { alloc(1); }

Dynamic allocated bases: {[ __malloc_alloc_l10 -> alloc :: malloc_base_name_clash_1.c:16 <-
                                                  foo :: malloc_base_name_clash_1.c:26 <-
                                                  main
                            __malloc_alloc_l10_0 -> alloc :: malloc_base_name_clash_1.c:21 <-
                                                    bar :: malloc_base_name_clash_1.c:27 <-
                                                    main ]}
Malloced by stack: malloc :: malloc_base_name_clash_1.c:10 <-
                   alloc :: malloc_base_name_clash_1.c:21 <-
                   bar :: malloc_base_name_clash_1.c:27 <-
                   main -> __malloc_alloc_l10_0
Malloced by stack: malloc :: malloc_base_name_clash_1.c:10 <-
                   alloc :: malloc_base_name_clash_1.c:16 <-
                   foo :: malloc_base_name_clash_1.c:26 <-
                   main -> __malloc_alloc_l10
