[kernel] Parsing bug_dep_through_function_pointer_1.c (with preprocessing)
[eva] Loading previous session from save file bug_dep_through_function_pointer_1.sav
[eva] Computing AST differences between saved file and current session
[eva] Copying Eva analysis cache from save file bug_dep_through_function_pointer_1.sav
[eva] In save file bug_dep_through_function_pointer_1.sav, 7 saved calls for 5 functions
[eva] In save file bug_dep_through_function_pointer_1.sav, 0 saved widenings for 0 functions
[eva:memexec] Importing summaries for function foo
[eva:memexec] Importing summaries for function alloc
[eva:memexec] Importing summaries for function main
[eva:memexec] Importing summaries for function test
[eva:memexec] Importing summaries for function bar
[eva] In current session, 7 saved calls for 5 functions
[eva] In current session, 0 saved widenings for 0 functions
[kernel] Warning: clearing dangling project pointers in project "default"
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  S_0___fc_env[0..1] ∈ [--..--]
  S_1___fc_env[0..1] ∈ [--..--]
[eva:memexec-malloc] 
  --- Reused allocated bases {__malloc_alloc_l11, __malloc_alloc_l11_0} for KF main at callstack 
  <A5r5> main
[eva] :0: Reusing old results for call to main
[eva] ====== VALUES COMPUTED ======
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

Dynamic allocated bases: {[ __malloc_alloc_l11 -> <C2bm> alloc :: bug_dep_through_function_pointer_1.c:17 <-
                                                         foo :: bug_dep_through_function_pointer_1.c:29 <-
                                                         test :: bug_dep_through_function_pointer_1.c:37 <-
                                                         main
                            __malloc_alloc_l11_0 -> <ZMzB> alloc :: bug_dep_through_function_pointer_1.c:23 <-
                                                           bar :: bug_dep_through_function_pointer_1.c:29 <-
                                                           test :: bug_dep_through_function_pointer_1.c:38 <-
                                                           main ]}
Malloced by stack: <Wxdr> malloc :: bug_dep_through_function_pointer_1.c:11 <-
                          alloc :: bug_dep_through_function_pointer_1.c:23 <-
                          bar :: bug_dep_through_function_pointer_1.c:29 <-
                          test :: bug_dep_through_function_pointer_1.c:38 <-
                          main -> __malloc_alloc_l11_0
Malloced by stack: <5ZHW> malloc :: bug_dep_through_function_pointer_1.c:11 <-
                          alloc :: bug_dep_through_function_pointer_1.c:17 <-
                          foo :: bug_dep_through_function_pointer_1.c:29 <-
                          test :: bug_dep_through_function_pointer_1.c:37 <-
                          main -> __malloc_alloc_l11
