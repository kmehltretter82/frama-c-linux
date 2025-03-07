/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-msg-key=memexec,widening -eva-no-cache-function -eva-reuse-widenings -eva-save-widenings
*/

int a;

void loop()
{
    int i = 0;
    while (i < a)
    {
        i++;
    }
}

int foo()
{
    a = 10;
    loop(); // Different callstack, only reuse widenings for the same callstack
    return 0;
}

int bar()
{
    a = 11;
    loop(); // Different callstack, only reuse widenings for the same callstack
    return 0;
}

int main()
{
    foo();
    foo();
    bar();
}