[kernel] Parsing bug_dep_through_function_pointer_1.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for test
[eva] computing for function test <- main.
  Called from bug_dep_through_function_pointer_1.c:37.
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- test <- main.
  Called from bug_dep_through_function_pointer_1.c:29.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- foo <- test <- main.
  Called from bug_dep_through_function_pointer_1.c:17.
[eva] bug_dep_through_function_pointer_1.c:11: Call to builtin malloc
[eva] bug_dep_through_function_pointer_1.c:11: 
  allocating variable __malloc_alloc_l11
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] bug_dep_through_function_pointer_1.c:18: Call to builtin free
[eva] bug_dep_through_function_pointer_1.c:18: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] bug_dep_through_function_pointer_1.c:18: 
  strong free on bases: {__malloc_alloc_l11}
[eva] Recording results for foo
[eva] Done for function foo
[eva] Recording results for test
[eva] Done for function test
[eva:memexec] No previous call found for test
[eva] computing for function test <- main.
  Called from bug_dep_through_function_pointer_1.c:38.
[eva:memexec] No previous call found for bar
[eva] computing for function bar <- test <- main.
  Called from bug_dep_through_function_pointer_1.c:29.
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- bar <- test <- main.
  Called from bug_dep_through_function_pointer_1.c:23.
[eva] bug_dep_through_function_pointer_1.c:11: Call to builtin malloc
[eva] bug_dep_through_function_pointer_1.c:11: 
  allocating variable __malloc_alloc_l11_0
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] bug_dep_through_function_pointer_1.c:24: Call to builtin free
[eva] bug_dep_through_function_pointer_1.c:24: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] bug_dep_through_function_pointer_1.c:24: 
  strong free on bases: {__malloc_alloc_l11_0}
[eva] Recording results for bar
[eva] Done for function bar
[eva] Recording results for test
[eva] Done for function test
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function alloc:
  __fc_heap_status ∈ [--..--]
  buf ∈ {{ (void *)&__malloc_alloc_l11 ; (void *)&__malloc_alloc_l11_0 }}
[eva:final-states] Values at end of function bar:
  __fc_heap_status ∈ [--..--]
  q ∈ ESCAPINGADDR
[eva:final-states] Values at end of function foo:
  __fc_heap_status ∈ [--..--]
  p ∈ ESCAPINGADDR
[eva:final-states] Values at end of function test:
  __fc_heap_status ∈ [--..--]
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  f ∈ {{ &foo }}
  g ∈ {{ &bar }}
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: foo
All allocated bases: {__malloc_alloc_l11}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main }
Call sites: { int *p = alloc(); }

Kernel function: alloc
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main }
Call sites: { void *buf = malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main }
Call sites: { test(f);; test(g); }

Kernel function: test
All allocated bases: {__malloc_alloc_l11, __malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:17 <-
                    foo :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:37 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main }
Call sites: { (*f)(); }

Kernel function: bar
All allocated bases: {__malloc_alloc_l11_0}
Allocation sites: {
                    malloc :: bug_dep_through_function_pointer_1.c:11 <-
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main;
                    alloc :: bug_dep_through_function_pointer_1.c:23 <-
                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                    test :: bug_dep_through_function_pointer_1.c:38 <-
                    main }
Call sites: { int *q = alloc(); }

Dynamic allocated bases: {[ __malloc_alloc_l11 -> alloc :: bug_dep_through_function_pointer_1.c:17 <-
                                                  foo :: bug_dep_through_function_pointer_1.c:29 <-
                                                  test :: bug_dep_through_function_pointer_1.c:37 <-
                                                  main
                            __malloc_alloc_l11_0 -> alloc :: bug_dep_through_function_pointer_1.c:23 <-
                                                    bar :: bug_dep_through_function_pointer_1.c:29 <-
                                                    test :: bug_dep_through_function_pointer_1.c:38 <-
                                                    main ]}
Malloced by stack: malloc :: bug_dep_through_function_pointer_1.c:11 <-
                   alloc :: bug_dep_through_function_pointer_1.c:23 <-
                   bar :: bug_dep_through_function_pointer_1.c:29 <-
                   test :: bug_dep_through_function_pointer_1.c:38 <-
                   main -> __malloc_alloc_l11_0
Malloced by stack: malloc :: bug_dep_through_function_pointer_1.c:11 <-
                   alloc :: bug_dep_through_function_pointer_1.c:17 <-
                   foo :: bug_dep_through_function_pointer_1.c:29 <-
                   test :: bug_dep_through_function_pointer_1.c:37 <-
                   main -> __malloc_alloc_l11
