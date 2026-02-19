/* run.config
   STDOPT: +"-sparecode-analysis -lib-entry -main f1"
   STDOPT: +"-sparecode-analysis -lib-entry -main f2"
*/
int x, y, unused;

int g(int x);

/*@ taints y; */
void f1(void)
{
	y = g(x);
}

/*@ taints y, unused; */
void f2(void)
{
	y = g(x);
}
