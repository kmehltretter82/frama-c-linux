//@ assigns \nothing;
void foo(void);

/*@
  ensures BUG_WP: \false;
  assigns \nothing;
*/
void bar()
{
  if (0 == 1)
    goto return_label;
  {
    int t1 = 1;
    foo();
    goto return_label;
  }
  return_label: return;
}
