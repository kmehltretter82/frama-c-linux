/* run.config
   OPT: -print %{dep:./multiple_file_2.c}
*/

/* see bug #43 */

/*@ requires x >= 0; */
extern int f(int x);

/*@ requires x >= 0; */
extern int g(int x);

extern int t1[sizeof(long)];
extern int t2[sizeof(int)];
extern int t3[sizeof(long long)];

int main () { g(0); t1[0] = 0; t2[0] = 0; t3[0] = 0; return f(0); }
