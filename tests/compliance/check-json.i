/*run.config
 NOFRAMAC:
  EXECNOW: LOG json_@PTEST_NAME@_1.txt python3 -m json.tool < share/compliance/c11_functions.json | head -n 2 > json_@PTEST_NAME@_1.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_2.txt python3 -m json.tool < share/compliance/glibc_functions.json | head -n 2 > json_@PTEST_NAME@_2.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_3.txt python3 -m json.tool < share/compliance/nonstandard_identifiers.json | head -n 2 > json_@PTEST_NAME@_3.txt 2> @DEV_NULL@
  EXECNOW: LOG json_@PTEST_NAME@_4.txt python3 -m json.tool < share/compliance/posix_identifiers.json | head -n 2 > json_@PTEST_NAME@_4.txt 2> @DEV_NULL@
*/
