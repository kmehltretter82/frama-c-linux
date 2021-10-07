/*run.config
 MACRO: SHARE share/compliance
 NOFRAMAC:
  EXECNOW: LOG json_@PTEST_NAME@_1.txt python3 -m json.tool < @SHARE@/c11_functions.json | head -n 2 > @PTEST_RESULT@/json_@PTEST_NAME@_1.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_2.txt python3 -m json.tool < @SHARE@/glibc_functions.json | head -n 2 > @PTEST_RESULT@/json_@PTEST_NAME@_2.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_3.txt python3 -m json.tool < @SHARE@/nonstandard_identifiers.json | head -n 2 > @PTEST_RESULT@/json_@PTEST_NAME@_3.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_4.txt python3 -m json.tool < @SHARE@/posix_identifiers.json | head -n 2 > @PTEST_RESULT@/json_@PTEST_NAME@_4.txt 2> @DEV_NULL@
*/
