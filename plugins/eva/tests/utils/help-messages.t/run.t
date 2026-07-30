Only load used plugins.
  $ alias frama-c="frama-c -no-autoload-plugins -load-module eva,eva.apron"

Main help message about Eva.
  $ frama-c -eva-help
  [eva] Help of the Eva plugin.
  
  Goal: Proving the absence of run-time errors. Eva emits an alarm at each
    program point where it cannot prove the absence of an undefined behavior.
    It can also prove some user-written annotations.
  Domains: Eva uses abstract interpretation to infer various properties about
    programs via analysis domains. The default domain computes the set of
    possible values for each program variable. Additional domains can infer
    relations between variables or more precise memory invariants.
  Soundness: Eva captures all possible behaviors of the program execution. If
    an analysis emits no alarm, then the analyzed program is free of the class
    of undefined behaviors detected by Eva. However, false alarms may be issued
    on correct code when the analysis is not precise enough to prove it.
  Configuration: While the analysis is automatic, many options are available to
    finely configure its behavior, guide the analysis towards better results
    and reach a suitable balance between precision and efficiency.
  
  Main Eva parameters are:
    -eva           : Run the Eva analysis.
    -main          : Select the entry point of the analysis.
    -lib-entry     : Treat the entry point as a library function and not a
                     complete application.
    -eva-domains   : Enable additional analysis domains.
    -eva-precision : Quick configuration of the analysis precision from 0
                     (fastest but rather imprecise analysis) to 11 (accurate
                     but potentially slow analysis).
    -eva-verbose   : Quick configuration of the analysis verbosity from 0 (no
                     message) to 11 (most messages). Defaults to 5.
    -mthread       : Enable analysis of concurrent programs (experimental).
  
  A typical invocation of Eva looks like: frama-c file.c -eva -eva-precision 2
  Analysis results can be inspected in detail in the Frama-C GUI.
  
  More help is available:
    -eva-help-domains  : list and description of available analysis domains
    -eva-help-options  : list and description of all Eva parameters
    -eva-help-messages : help about analysis verbosity and message categories
    -eva-help-warnings : help about warnings emitted by Eva
    -eva-help-builtins : list of builtins used to interpret some libc functions
  
  The complete user manual is available at https://frama-c.com/download/frama-c-eva-manual.pdf

The rest of the file tests the output of each -eva-help-* parameters,
except -eva-help-options which is tested by tests/misc/help-messages.i.

Help message about Eva abstract domains.
-eva-help-domains and -eva-domains help have the same output
  $ frama-c -eva-help-domains > help-domains.txt
  $ frama-c -eva-domains help > domains-help.txt
  $ diff help-domains.txt domains-help.txt
  $ cat help-domains.txt
  [eva] List of available domains:
    cvalue               Main analysis domain, enabled by default. Should not be
                         disabled.
    equality             Infers equalities between syntactic C expressions. Makes
                         the analysis less dependent on temporary variables and
                         intermediate computations.
    symbolic-locations   Infers values of symbolic locations represented by
                         imprecise lvalues, such as t[i] or *p when the possible
                         values of [i] or [p] are imprecise.
    gauges               Infers linear inequalities between the variables
                         modified within a loop and a special loop counter.
    octagon              Infers integer relations of the form b < ±X ± Y < e,
                         where X, Y are program lvalues and b, e are constants.
    multidim             Experimental. Improve the precision over arrays of
                         structures or multidimensional arrays.
    bitwise              Infers bitwise information to interpret more precisely
                         bitwise operators.
    taint                Experimental. Taint analysis
    numerors             Experimental. Infers ranges for the absolute and
                         relative errors in floating-point computations.
    sign                 Infers the sign of program variables.
    apron-box            Experimental. Binding to the apron-box domain of the
                         Apron library. See
                         https://antoinemine.github.io/Apron/doc/ for more
                         details.
    apron-octagon        Experimental. Binding to the apron-octagon domain of the
                         Apron library. See
                         https://antoinemine.github.io/Apron/doc/ for more
                         details.
    apron-polka-equality Experimental. Binding to the apron-polka-equality domain
                         of the Apron library. See
                         https://antoinemine.github.io/Apron/doc/ for more
                         details.
    apron-polka-loose    Experimental. Binding to the apron-polka-loose domain of
                         the Apron library. See
                         https://antoinemine.github.io/Apron/doc/ for more
                         details.
    apron-polka-strict   Experimental. Binding to the apron-polka-strict domain
                         of the Apron library. See
                         https://antoinemine.github.io/Apron/doc/ for more
                         details.
    mthread              Experimental. Domain for the analysis of concurrent
                         programs. Automatically enabled by the -mthread
                         parameter.
    inout                Experimental. Infers the inputs and outputs of each
                         function.
    printer              Debug domain, only useful for developers. Prints the
                         transfer functions used during the analysis.
    traces               Experimental. Builds an over-approximation of all the
                         traces that lead to a statement.

Help message about Eva builtins.
  $ frama-c -eva-help-builtins
  [eva] List of Eva builtins:
  
  ** Automatic replacements:
     (unless otherwise specified, function <f> is replaced by builtin Frama_C_<f>)
     
     __fc_vla_alloc (replaced by: Frama_C_vla_alloc),
     __fc_vla_free (replaced by: Frama_C_vla_free), acos, acosf, alloca, asin,
     asinf, atan, atan2, atan2f, atanf, calloc, ceil, ceilf, cos, cosf, exp,
     expf, floor, floorf, fmod, fmodf, free, log, log10, log10f, logf, malloc,
     memchr, memcpy, memmove, memset, pow, powf, rawmemchr, realloc,
     reallocarray, round, roundf, sin, sinf, sqrt, sqrtf, strchr, strlen,
     strnlen, trunc, truncf, wcschr, wcslen, wmemchr
  
  ** Full list of builtins (configurable via -eva-builtin):
     
     Frama_C_abstract_cardinal, Frama_C_abstract_max, Frama_C_abstract_min,
     Frama_C_acos, Frama_C_acosf, Frama_C_alloca, Frama_C_asin, Frama_C_asinf,
     Frama_C_assert, Frama_C_atan, Frama_C_atan2, Frama_C_atan2f,
     Frama_C_atanf, Frama_C_builtin_split, Frama_C_builtin_split_all,
     Frama_C_builtin_split_pointer, Frama_C_calloc, Frama_C_ceil,
     Frama_C_ceilf, Frama_C_check_leak, Frama_C_cos, Frama_C_cosf, Frama_C_exp,
     Frama_C_expf, Frama_C_floor, Frama_C_floorf, Frama_C_fmod, Frama_C_fmodf,
     Frama_C_free, Frama_C_interval_split, Frama_C_is_base_aligned,
     Frama_C_log, Frama_C_log10, Frama_C_log10f, Frama_C_logf, Frama_C_malloc,
     Frama_C_memchr, Frama_C_memcpy, Frama_C_memmove, Frama_C_memset,
     Frama_C_mthread_show, Frama_C_mthread_sync, Frama_C_mutex_init,
     Frama_C_mutex_lock, Frama_C_mutex_unlock, Frama_C_offset, Frama_C_pow,
     Frama_C_powf, Frama_C_queue_init, Frama_C_queue_receive,
     Frama_C_queue_send, Frama_C_rawmemchr, Frama_C_realloc,
     Frama_C_reallocarray, Frama_C_round, Frama_C_roundf, Frama_C_sin,
     Frama_C_sinf, Frama_C_sqrt, Frama_C_sqrtf, Frama_C_strchr, Frama_C_strlen,
     Frama_C_strnlen, Frama_C_thread_cancel, Frama_C_thread_create,
     Frama_C_thread_exit, Frama_C_thread_id, Frama_C_thread_priority,
     Frama_C_thread_start, Frama_C_thread_suspend, Frama_C_trunc,
     Frama_C_truncf, Frama_C_ungarble, Frama_C_vla_alloc, Frama_C_vla_free,
     Frama_C_watch_cardinal, Frama_C_watch_value, Frama_C_wcschr,
     Frama_C_wcslen, Frama_C_wmemchr

Help message about message categories.
-eva-help-messages and -eva-msg-key help have the same output.
  $ frama-c -eva-help-messages > help-messages.txt
  $ frama-c -eva-msg-key help > messages-help.txt
  $ diff help-messages.txt messages-help.txt
  $ cat help-messages.txt
  [eva] List of message categories.
  
  # Standard Eva message categories:
    *                     : All categories
    callstack-hash        : additionally print the current callstack hash in
                            some messages
    callstacks            : print the current callstack alongside some messages
    cardinal              : estimate the number of concrete states approximated
                            by the analysis at the end of each function
    final-states          : at the end of the analysis, print final values
                            inferred at the return point of each analyzed
                            function 
    imprecision           : messages related to possible imprecision of
                            builtins interpreting memcpy, memmove and memset
    initial-state         : at the start of the analysis, print the initial
                            value of global variables
    malloc                : messages from builtins interpreting dynamic
                            allocations
    malloc:automatic-free : messages emitted when bases are automatically freed
                            (alloca or VLA)
    malloc:new            : messages emitted at the creation of new bases
    nonlin                : messages about evaluation of subdivisions enabled
                            by -eva-subdivide-non-linear
    partition             : messages about states partitioning
    pointer-comparison    : messages about the evaluation of pointer
                            comparisons
    precision-settings    : messages about the automatic configuration of the
                            analysis by option -eva-precision
    progress              : messages about the analysis progress in the C code
    show                  : show values/states inferred by the analysis on
                            directives such as Frama_C_show_each and
                            Frama_C_dump_each
    split-return          : messages related to option -eva-split-return
    summary               : print a summary of the analysis at the end,
                            including coverage and alarm numbers
    widening              : print a message at each point where the analysis
                            applies a widening
  
  # Message categories about concurrency (with option -mthread):
    data-races                  : list of possible data-races detected by the
                                  analysis
    global-accesses             : print all accesses to global variables during
                                  the analysis
    message-queue               : show each operation on message queues
                                  interpreted by the analysis
    mutex                       : show each operation on mutexes interpreted by
                                  the analysis
    shared-memory               : all messages about shared memory
    shared-memory:iteration     : evolution of shared memory detected at each
                                  analysis iteration
    shared-memory:mutex         : list of mutexes protecting access to each
                                  shared memory location
    shared-memory:mutex-details : more details about mutexes protecting access
                                  to shared memory
    shared-memory:values        : values read and written in shared memory
                                  during the analysis
    shared-memory:zone          : list of shared memory locations detected by
                                  the analysis
    thread                      : show each operation on threads interpreted by
                                  the analysis
    thread-fixpoint             : progress of the analysis fixpoint on threads
  
  # Message categories for printing domain states on user directives:
    d-apron-box            : print states of the apron-box domain
    d-apron-octagon        : print states of the apron-octagon domain
    d-apron-polka-equality : print states of the apron-polka-equality domain
    d-apron-polka-loose    : print states of the apron-polka-loose domain
    d-apron-polka-strict   : print states of the apron-polka-strict domain
    d-bitwise              : print states of the bitwise domain
    d-cvalue               : print states of the cvalue domain
    d-equality             : print states of the equality domain
    d-gauges               : print states of the gauges domain
    d-inout                : print states of the inout domain
    d-mthread              : print states of the mthread domain
    d-multidim             : print states of the multidim domain
    d-numerors             : print states of the numerors domain
    d-octagon              : print states of the octagon domain
    d-printer              : print states of the printer domain
    d-sign                 : print states of the sign domain
    d-symbolic-locations   : print states of the symbolic-locations domain
    d-taint                : print states of the taint domain
    d-traces               : print states of the traces domain
    d-unit                 : print states of the unit domain
  
  # Message categories for debug purposes:
    debug                 : all debug messages
    debug:interferences   : debug messages about interferences from other
                            threads injected in Eva analysis with Mthread
    debug:iterator        : debug messages about the fixpoint engine on the
                            control-flow graph of functions
    debug:malloc          : debug messages from builtins interpreting dynamic
                            allocations
    debug:string-literals : when printing a state, also include globals
                            representing string literals
    debug:taint           : print debug states of the taint domain on user
                            directives
    debug:widen-hints     : debug messages for the interpretation of
                            widen_hints annotations
    domain_product        : inactive category
  
  # Message categories by verbosity:
    Message categories are automatically enabled or disabled according to the
    verbosity level. Default verbosity is 5 and can be changed with
    -eva-verbose from 0 (no message is printed) to 11 (most categories are
    enabled). Option -eva-msg-key can also be used to enable or disable
    specific message categories.
    The verbosity level also enables some warning categories as feedback
    messages by default. Warning categories are controlled by option
    -eva-warn-key.
  
    Message categories enabled by verbosity level:
      1: summary
      2: show
      3: data-races malloc:new precision-settings shared-memory:zone
         thread-fixpoint
      4: malloc:automatic-free partition shared-memory:mutex split-return
         thread
      5: final-states initial-state
      6: imprecision malloc shared-memory:mutex-details
      7: pointer-comparison shared-memory:iteration widening
      8: message-queue mutex nonlin shared-memory:values
      9: callstack-hash callstacks
     10: progress
     11: cardinal debug:string-literals global-accesses
  
    Warning categories enabled as feedback message by verbosity level:
      2: watchpoint
      3: garbled-mix:assigns garbled-mix:summary garbled-mix:write recursion
      4: acsl acsl:unsupported assigns:invalid-location loop-unroll:auto
         loop-unroll:partial

Help message about warning categories.
-eva-help-warnings and -eva-warn-key help have the same output.
  $ frama-c -eva-help-warnings > help-warnings.txt
  $ frama-c -eva-warn-key help > warnings-help.txt
  $ diff help-warnings.txt warnings-help.txt
  $ cat help-warnings.txt
  [eva] Warning categories for eva are
      *                        : warning  : All warning categories
      acsl                     : feedback : messages about evaluation of ACSL terms and predicates
      acsl:unsupported         : feedback : messages about ACSL terms not supported by Eva
      alarm                    : warning  : warnings for each possible undefined behavior detected by the analysis
      assigns                  : warning  : warnings related to the interpretation of assigns clauses in ACSL specification
      assigns:invalid-location : feedback : the memory location targeted by an assigns clause is invalid in at least one analysis state
      assigns:missing          : error    : assigns clauses are missing or incomplete from an ACSL specification on which the analysis soundness relies
      assigns:missing-result   : warning  : an assigns \result clause is missing from an ACSL specification on which the analysis soundness relies
      builtins                 : warning  : warnings related to builtins used to interpret some libc functions
      builtins:missing-spec    : warning  : the ACSL specification on which a builtin soundness relies is missing
      builtins:override        : warning  : a builtin overrides a function definition, which is therefore not analyzed
      ensures-false            : warning  : a post-condition evaluates to false; there might be an error in the specification
      experimental             : warning  : an experimental feature of Eva is enabled
      garbled-mix              : warning  : warnings about very imprecise values inferred for pointers, named garbled mix
      garbled-mix:assigns      : feedback : the interpretation of a specification creates a garbled mix
      garbled-mix:summary      : feedback : list the origins of garbled mix at the end of an analysis
      garbled-mix:write        : feedback : the interpretation of an assignment creates a garbled mix
      libc                     : warning  : warnings related to the interpretation of the standard C library
      libc:unsupported-spec    : warning  : the ACSL specification of a libc function is not supported by Eva
      locals-escaping          : warning  : a pointer p points to an out of scope local variable (any use of p also generates an alarm)
      loop-unroll              : warning  : messages about loop unrolling
      loop-unroll:auto         : feedback : a loop is automatically unrolled by -eva-auto-loop-unroll
      loop-unroll:missing      : inactive : a loop has no unroll annotation
      loop-unroll:missing:for  : inactive : a for loop has no unroll annotation
      loop-unroll:partial      : feedback : a loop has been partially but not completely unrolled
      malloc                   : warning  : warnings related to builtins interpreting dynamic allocation
      malloc:imprecise         : warning  : a single "weak" variable is used to represent all dynamic allocations, which is very imprecise
      malloc:weak              : inactive : a same "weak" variable is used to represent multiple dynamic allocations, which is rather imprecise
      recursion                : feedback : a recursive call is analyzed
      secure-flow              : warning  : warnings related to secure-flow analysis from "-eva-domains taint"
      secure-flow:condition    : warning  : warnings related to interference on conditions when performing secure-flow analysis from "-eva-domains taint"
      secure-flow:direct       : warning  : warnings related to direct interference when performing secure-flow analysis from "-eva-domains taint"
      secure-flow:indirect     : warning  : warnings related to indirect interference when performing secure-flow analysis from "-eva-domains taint"
      signed-overflow          : warning  : two's complement is used to interpret a signed overflow (when signed overflow alarms are disabled)
      taint                    : warning  : warnings related to the taint analysis from "-eva-domains taint"
      unknown-size             : warning  : the analysis cannot compute the size of a variable, which will thus be very imprecise
      volatile                 : warning  : a non-volatile lvalue may point to a volatile memory location
      watchpoint               : feedback : undocumented
