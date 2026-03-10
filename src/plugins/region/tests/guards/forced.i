/* run.config
  OPT: -region-force -rte -then -region-rte -then -print
  COMMENT: .0 => both annotations (rte first, region second)
  OPT: -region-force -region-rte -then -rte -then -print
  COMMENT: .1 => both annotations (region first, rte second)
  OPT: -region-no-force -rte -then -region-rte -then -print
  COMMENT: .2 => RTE annotations only
  COMMENT: .2 TODO: FIXME: does not work (alignment and pointer value still required)
  OPT: -region-no-force -region-rte -then -rte -then -print
  COMMENT: .3 => REGION annotations only
*/

int access(int *p) { return *p; }
