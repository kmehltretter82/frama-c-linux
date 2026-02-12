/* run.config
   STDOPT: +"-sparecode-analysis -lib-entry -main f"
*/
int x, y;

int g(int x);

/*@ taints y; */
void f(void)
{
	y = g(x);
}
