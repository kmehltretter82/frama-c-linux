/* run.config
  EXIT: 1
*/

int z;

/*@ assigns z, z;
    assigns z \from z;
    assigns z, z;
 */
void function(void)
{
  return;
}
