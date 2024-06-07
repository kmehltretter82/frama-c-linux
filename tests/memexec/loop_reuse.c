/* run.config*
   OPT: -eva @EVA_CONFIG@ -eva-msg-key=memexec,widening -eva-reuse-widenings -eva-save-widenings
*/

int a;

void loop()
{
    for (int i = 0; i < 10; i++)
    {
        a++;
    }
}

int main()
{
    a = 0;
    loop();
    a = 1;
    loop(); // Different input state, no summary reuse, only widening reuse
}