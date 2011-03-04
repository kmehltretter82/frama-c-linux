/* run.config
   COMMENT: sizeof */

void main() {
  int x = 0;
  /*@ assert sizeof(int) == sizeof(x); */ ;
  /*@ assert sizeof("totototototo") == sizeof(char *); */ ;
}
