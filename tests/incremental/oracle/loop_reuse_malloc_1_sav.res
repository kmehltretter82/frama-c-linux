[kernel] Parsing loop_reuse_malloc_1.c (with preprocessing)
[eva] Analyzing a complete application starting at main
[eva] Computing initial state
[eva] Initial state computed
[eva:initial-state] Values of globals at initialization
  a ∈ {0}
[eva:memexec] No previous call found for main
[eva:memexec] No previous call found for loop
[eva] computing for function loop <- main.
  Called from loop_reuse_malloc_1.c:49.
[eva] loop_reuse_malloc_1.c:38: Call to builtin malloc
[eva] loop_reuse_malloc_1.c:38: allocating variable __malloc_loop_l38
[eva:memexec] No previous call found for init_p
[eva] computing for function init_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:40.
[eva:memexec] No previous call found for alloc
[eva] computing for function alloc <- init_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:22.
[eva] loop_reuse_malloc_1.c:12: Call to builtin malloc
[eva] loop_reuse_malloc_1.c:12: allocating variable __malloc_alloc_l12
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] loop_reuse_malloc_1.c:20: starting to merge loop iterations
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- init_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:22.
[eva] loop_reuse_malloc_1.c:12: Call to builtin malloc
[eva] loop_reuse_malloc_1.c:12: allocating variable __malloc_alloc_l12_0
[eva] Recording results for alloc
[eva] Done for function alloc
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- init_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:22.
[eva] loop_reuse_malloc_1.c:12: Call to builtin malloc
[eva] loop_reuse_malloc_1.c:12: allocating weak variable __malloc_w_alloc_l12
[eva] Recording results for alloc
[eva] Done for function alloc
[eva:widening] loop_reuse_malloc_1.c:20: applying a widening at this point
[eva:memexec] No previous saved state found for alloc
[eva] computing for function alloc <- init_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:22.
[eva] loop_reuse_malloc_1.c:12: Call to builtin malloc
[eva] Recording results for alloc
[eva] Done for function alloc
[eva] Recording results for init_p
[eva] Done for function init_p
[eva:memexec] No previous call found for free_p
[eva] computing for function free_p <- loop <- main.
  Called from loop_reuse_malloc_1.c:41.
[eva:alarm] loop_reuse_malloc_1.c:31: Warning: 
  accessing uninitialized left-value. assert \initialized(arr + i);
[eva] loop_reuse_malloc_1.c:31: Call to builtin free
[eva] loop_reuse_malloc_1.c:31: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] loop_reuse_malloc_1.c:31: 
  weak free on bases: {__malloc_alloc_l12, __malloc_alloc_l12_0,
                       __malloc_w_alloc_l12}
[eva] loop_reuse_malloc_1.c:29: starting to merge loop iterations
[eva:alarm] loop_reuse_malloc_1.c:31: Warning: 
  accessing left-value that contains escaping addresses.
  assert ¬\dangling(arr + i);
[eva] loop_reuse_malloc_1.c:31: Call to builtin free
[eva:malloc] loop_reuse_malloc_1.c:31: 
  weak free on bases: {__malloc_alloc_l12, __malloc_alloc_l12_0,
                       __malloc_w_alloc_l12}
[eva] loop_reuse_malloc_1.c:31: Call to builtin free
[eva:malloc] loop_reuse_malloc_1.c:31: 
  weak free on bases: {__malloc_alloc_l12, __malloc_alloc_l12_0,
                       __malloc_w_alloc_l12}
[eva:widening] loop_reuse_malloc_1.c:29: applying a widening at this point
[eva] Recording results for free_p
[eva] Done for function free_p
[eva] loop_reuse_malloc_1.c:43: Call to builtin free
[eva] loop_reuse_malloc_1.c:43: 
  function free: precondition 'freeable' got status valid.
[eva:malloc] loop_reuse_malloc_1.c:43: strong free on bases: {__malloc_loop_l38}
[eva] Recording results for loop
[eva] Done for function loop
[eva] Recording results for main
[eva] Done for function main
[eva] ====== VALUES COMPUTED ======
[eva:final-states] Values at end of function free_p:
  a ∈ {3}
  __malloc_loop_l38[0] ∈
                   {{ &__malloc_alloc_l12 ; &__malloc_alloc_l12_0 ;
                      &__malloc_w_alloc_l12[0] }} or UNINITIALIZED or ESCAPINGADDR
                   [1] ∈
                   {{ &__malloc_alloc_l12_0 ; &__malloc_w_alloc_l12[0] }} or UNINITIALIZED or ESCAPINGADDR
                   [2] ∈
                   {{ &__malloc_w_alloc_l12[0] }} or UNINITIALIZED or ESCAPINGADDR
[eva:final-states] Values at end of function alloc:
  __fc_heap_status ∈ [--..--]
  p ∈
   {{ &__malloc_alloc_l12 ; &__malloc_alloc_l12_0 ;
      &__malloc_w_alloc_l12[0] }}
  __retres ∈
          {{ (void *)&__malloc_alloc_l12 ; (void *)&__malloc_alloc_l12_0 ;
             (void *)&__malloc_w_alloc_l12 }}
  __malloc_alloc_l12 ∈ {0}
  __malloc_alloc_l12_0 ∈ {0}
  __malloc_w_alloc_l12[0] ∈ {0} or UNINITIALIZED
[eva:final-states] Values at end of function init_p:
  __fc_heap_status ∈ [--..--]
  a ∈ {2}
  __malloc_loop_l38[0] ∈
                   {{ &__malloc_alloc_l12 ; &__malloc_alloc_l12_0 ;
                      &__malloc_w_alloc_l12[0] }} or UNINITIALIZED
                   [1] ∈
                   {{ &__malloc_alloc_l12_0 ; &__malloc_w_alloc_l12[0] }} or UNINITIALIZED
                   [2] ∈ {{ &__malloc_w_alloc_l12[0] }} or UNINITIALIZED
  __malloc_alloc_l12 ∈ {0}
  __malloc_alloc_l12_0 ∈ {0}
  __malloc_w_alloc_l12[0] ∈ {0} or UNINITIALIZED
[eva:final-states] Values at end of function loop:
  __fc_heap_status ∈ [--..--]
  a ∈ {3}
  arr ∈ ESCAPINGADDR
  __malloc_alloc_l12 ∈ {0}
  __malloc_alloc_l12_0 ∈ {0}
  __malloc_w_alloc_l12[0] ∈ {0} or UNINITIALIZED
[eva:final-states] Values at end of function main:
  __fc_heap_status ∈ [--..--]
  a ∈ {3}
  __retres ∈ {0}
  __malloc_alloc_l12 ∈ {0}
  __malloc_alloc_l12_0 ∈ {0}
  __malloc_w_alloc_l12[0] ∈ {0} or UNINITIALIZED
[eva:alloc-summary] ====== DYNAMIC ALLOCATION SUMMARY ======
  Kernel function: alloc
All allocated bases: {__malloc_alloc_l12, __malloc_alloc_l12_0,
                      __malloc_w_alloc_l12}
Allocation sites: {
                    malloc :: loop_reuse_malloc_1.c:12 <-
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main }
Call sites: { int *p = malloc(sizeof(int)); }

Kernel function: malloc
All allocated bases: {__malloc_loop_l38, __malloc_alloc_l12,
                      __malloc_alloc_l12_0, __malloc_w_alloc_l12}
Allocation sites: {
                    malloc :: loop_reuse_malloc_1.c:12 <-
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    malloc :: loop_reuse_malloc_1.c:38 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main; loop :: loop_reuse_malloc_1.c:49 <- main }
Call sites: {  }

Kernel function: main
All allocated bases: {__malloc_loop_l38, __malloc_alloc_l12,
                      __malloc_alloc_l12_0, __malloc_w_alloc_l12}
Allocation sites: {
                    malloc :: loop_reuse_malloc_1.c:12 <-
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    malloc :: loop_reuse_malloc_1.c:38 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main; loop :: loop_reuse_malloc_1.c:49 <- main }
Call sites: { loop(); }

Kernel function: loop
All allocated bases: {__malloc_loop_l38, __malloc_alloc_l12,
                      __malloc_alloc_l12_0, __malloc_w_alloc_l12}
Allocation sites: {
                    malloc :: loop_reuse_malloc_1.c:12 <-
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    malloc :: loop_reuse_malloc_1.c:38 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main; loop :: loop_reuse_malloc_1.c:49 <- main }
Call sites: { int **arr = malloc(sizeof(int *) * (unsigned long)3);;
              init_p(arr); }

Kernel function: init_p
All allocated bases: {__malloc_alloc_l12, __malloc_alloc_l12_0,
                      __malloc_w_alloc_l12}
Allocation sites: {
                    malloc :: loop_reuse_malloc_1.c:12 <-
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main;
                    alloc :: loop_reuse_malloc_1.c:22 <-
                    init_p :: loop_reuse_malloc_1.c:40 <-
                    loop :: loop_reuse_malloc_1.c:49 <-
                    main }
Call sites: { *(arr + i) = (int *)alloc(); }

Dynamic allocated bases: {[ __malloc_loop_l38 -> loop :: loop_reuse_malloc_1.c:49 <-
                                                 main
                            __malloc_alloc_l12 -> alloc :: loop_reuse_malloc_1.c:22 <-
                                                  init_p :: loop_reuse_malloc_1.c:40 <-
                                                  loop :: loop_reuse_malloc_1.c:49 <-
                                                  main
                            __malloc_alloc_l12_0 -> alloc :: loop_reuse_malloc_1.c:22 <-
                                                    init_p :: loop_reuse_malloc_1.c:40 <-
                                                    loop :: loop_reuse_malloc_1.c:49 <-
                                                    main
                            __malloc_w_alloc_l12 -> alloc :: loop_reuse_malloc_1.c:22 <-
                                                    init_p :: loop_reuse_malloc_1.c:40 <-
                                                    loop :: loop_reuse_malloc_1.c:49 <-
                                                    main ]}
Malloced by stack: malloc :: loop_reuse_malloc_1.c:12 <-
                   alloc :: loop_reuse_malloc_1.c:22 <-
                   init_p :: loop_reuse_malloc_1.c:40 <-
                   loop :: loop_reuse_malloc_1.c:49 <-
                   main -> __malloc_alloc_l12, __malloc_alloc_l12_0, __malloc_w_alloc_l12
Malloced by stack: malloc :: loop_reuse_malloc_1.c:38 <-
                   loop :: loop_reuse_malloc_1.c:49 <-
                   main -> __malloc_loop_l38
