/* run.config
  MODULE: Extend_plugin
  STDOPT: +"-kernel-warn-key=extension-unknown=active"
*/

/*@ \myplugin::foo x == 0;
    \myplugin::bar x == 0;
    \unknown_plugin::bar x == 0;
 */
int f(int x) {
  return x;
}
