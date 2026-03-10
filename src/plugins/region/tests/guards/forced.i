/* run.config
  OPT: -region-force -rte -then -region-annotate -then -print
  OPT: -region-force -region-annotate -then -rte -then -print
  OPT: -region-no-force -rte -then -region-annotate -then -print
  OPT: -region-no-force -region-annotate -then -rte -then -print
*/

/*@ region *p, \nullable; */
int access(int *p) { return *p; }
