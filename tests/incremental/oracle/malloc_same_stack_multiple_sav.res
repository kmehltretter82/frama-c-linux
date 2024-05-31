[kernel] Parsing malloc_same_stack_multiple.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for foo
[eva] computing for function foo <- main.
  Called from malloc_same_stack_multiple.c:28.
[eva] malloc_same_stack_multiple.c:10: Call to builtin malloc
[eva] malloc_same_stack_multiple.c:10: allocating variable __malloc_foo_l10
[eva] malloc_same_stack_multiple.c:14: Call to builtin malloc
[eva] malloc_same_stack_multiple.c:14: allocating variable __malloc_foo_l14
[eva] malloc_same_stack_multiple.c:14: Call to builtin malloc
[eva] malloc_same_stack_multiple.c:14: allocating variable __malloc_foo_l14_0
[eva] malloc_same_stack_multiple.c:14: Call to builtin malloc
[eva] malloc_same_stack_multiple.c:14: 
  allocating weak variable __malloc_w_foo_l14
[eva] malloc_same_stack_multiple.c:20: Call to builtin free
[eva] malloc_same_stack_multiple.c:20: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] malloc_same_stack_multiple.c:20: 
  strong free on bases: {__malloc_foo_l14}
[eva] malloc_same_stack_multiple.c:20: Call to builtin free
[eva:malloc] malloc_same_stack_multiple.c:20: 
  strong free on bases: {__malloc_foo_l14_0}
[eva] malloc_same_stack_multiple.c:20: Call to builtin free
[eva:malloc] malloc_same_stack_multiple.c:20: 
  weak free on bases: {__malloc_w_foo_l14}
[eva] malloc_same_stack_multiple.c:23: Call to builtin free
[eva] malloc_same_stack_multiple.c:23: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] malloc_same_stack_multiple.c:23: 
  strong free on bases: {__malloc_foo_l10}
[eva] Recording results for foo
[eva] Done for function foo
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function foo:
  __fc_heap_status ∈ [--..--]
  p ∈ ESCAPINGADDR
  __malloc_w_foo_l14[0] ∈ {0} or UNINITIALIZED
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  __retres ∈ {0}
  __malloc_w_foo_l14[0] ∈ {0} or UNINITIALIZED
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: foo
All allocated bases: {__malloc_foo_l10, __malloc_foo_l14, __malloc_foo_l14_0,
                      __malloc_w_foo_l14}
Allocation sites: {
                    malloc :: malloc_same_stack_multiple.c:10 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main;
                    malloc :: malloc_same_stack_multiple.c:14 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main; foo :: malloc_same_stack_multiple.c:28 <- main }
Call sites: { int **p = malloc(sizeof(int *) * (unsigned long)3);;
              *(p + i) = (int *)malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_foo_l10, __malloc_foo_l14, __malloc_foo_l14_0,
                      __malloc_w_foo_l14}
Allocation sites: {
                    malloc :: malloc_same_stack_multiple.c:10 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main;
                    malloc :: malloc_same_stack_multiple.c:14 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main; foo :: malloc_same_stack_multiple.c:28 <- main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_foo_l10, __malloc_foo_l14, __malloc_foo_l14_0,
                      __malloc_w_foo_l14}
Allocation sites: {
                    malloc :: malloc_same_stack_multiple.c:10 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main;
                    malloc :: malloc_same_stack_multiple.c:14 <-
                    foo :: malloc_same_stack_multiple.c:28 <-
                    main; foo :: malloc_same_stack_multiple.c:28 <- main }
Call sites: { foo(); }

Dynamic allocated bases: {[ __malloc_foo_l10 -> foo :: malloc_same_stack_multiple.c:28 <-
                                                main
                            __malloc_foo_l14 -> foo :: malloc_same_stack_multiple.c:28 <-
                                                main
                            __malloc_foo_l14_0 -> foo :: malloc_same_stack_multiple.c:28 <-
                                                  main
                            __malloc_w_foo_l14 -> foo :: malloc_same_stack_multiple.c:28 <-
                                                  main ]}
Malloced by stack: malloc :: malloc_same_stack_multiple.c:14 <-
                   foo :: malloc_same_stack_multiple.c:28 <-
                   main -> __malloc_foo_l14, __malloc_foo_l14_0, __malloc_w_foo_l14
Malloced by stack: malloc :: malloc_same_stack_multiple.c:10 <-
                   foo :: malloc_same_stack_multiple.c:28 <-
                   main -> __malloc_foo_l10
