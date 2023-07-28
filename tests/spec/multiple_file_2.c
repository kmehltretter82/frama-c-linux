/* run.config
   DONTRUN: linked with multiple_file_1.c which is the real test.
*/
/*@ requires y <= 0; */
int g(int y);

extern int t1[sizeof(long)];
extern int t2[sizeof(long)];
extern int t3[sizeof(long)];
