/* run.config
   EXIT: 1
   STDOPT:
*/
char *b(char* c){ return c; }

int main(void) {
    char a[] = b("");
    char m[] = 1;
    char p[1] = 0;
    extern char j[] = {0,1};
    char f[];
    static char n[];
    return 0;
}
