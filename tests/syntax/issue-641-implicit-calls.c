/* run.config
    EXIT: 1
    STDOPT: #"-cpp-extra-args=-DINCOMP1"
    STDOPT: #"-cpp-extra-args=-DINCOMP2"
    STDOPT: #"-cpp-extra-args=-DINCOMP3"
*/

#ifdef INCOMP1
    void foo(unsigned x) { bar(bar(0, 12), x); }
#endif

#ifdef INCOMP2
    void foo(int x) { bar(bar(0), x); }
#endif

#ifdef INCOMP3
    void foo(int x) { bar(bar); }
#endif
