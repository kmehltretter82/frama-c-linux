int a, b, c, d, e;

/*@ assigns a;
    assigns a \from a, a, b, c, c;
    assigns a \from c, b, d, e, a;
    assigns a;
    assigns b \from a, e, b, d, c;
    assigns c \from c, c, c, c, c;
 */
void function(void)
{
  return;
}
