/* run.config
   LOG: audit-out.json
   STDOPT: #"-audit-check @PTEST_DIR@/audit-in.json -audit-prepare @PTEST_RESULT@/audit-out.json -kernel-warn-key audit=active"
*/

#include "audit_included.h"
#include "audit_included_but_not_listed.h"

void main() {
  float f = 2.1; // to trigger a syntactic warning
}
