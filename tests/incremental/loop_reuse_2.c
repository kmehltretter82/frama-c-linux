/* run.config
      DONTRUN: main test is in loop_reuse_1.c
      COMMENT: To make line corresponds to the one in loop_reuse_1.c
      COMMENT: To make line corresponds to the one in loop_reuse_1.c
*/
int a;

void loop()
{
    for (int i = 0; i < 15; i++)
    {
        a++;
    }
}

int main()
{
    loop();
}