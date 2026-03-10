/* run.config
  OPT: -region-force -rte -then -region-rte -then -print
  OPT: -region-force -region-rte -then -rte -then -print
  OPT: -region-no-force -rte -then -region-rte -then -print
  OPT: -region-no-force -region-rte -then -rte -then -print
*/

int access(int *p) { return *p; }
