/* run.config
   LOG: audit-out.json
   STDOPT: #"-audit-check @PTEST_DIR@/audit-in.json -audit-prepare @PTEST_DIR@/result/audit-out.json"
*/

#include "audit_included.h"

void main() {
  float f = 2.1; // to trigger a syntactic warning
}
