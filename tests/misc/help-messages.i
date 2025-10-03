/* run.config
   COMMENT: Test help message for every internalized plug-in. Ideally this
   COMMENT: should be done automatically but then it would not be stable if one
   COMMENT: locally internalize a plug-in.

   STDOPT: +"-h"
   STDOPT: +"-kernel-h"
   STDOPT: +"-load-plugin acsl-importer -acsl-import-h"
   STDOPT: +"-load-plugin alias -alias-h"
   STDOPT: +"-load-plugin aorai -aorai-h"
   STDOPT: +"-load-plugin callgraph -cg-h"
   STDOPT: +"-load-plugin dive -dive-h"
   STDOPT: +"-load-plugin e-acsl -e-acsl-h"
   STDOPT: +"-load-plugin eva -eva-h"
   STDOPT: +"-load-plugin from -from-h"
   STDOPT: +"-load-plugin impact -impact-h"
   STDOPT: +"-load-plugin inout -inout-h"
   STDOPT: +"-load-plugin instantiate -instantiate-h"
   STDOPT: +"-load-plugin loop-analysis -loop-h"
   STDOPT: +"-load-plugin markdown-report -mdr-h"
   STDOPT: +"-load-plugin metrics -metrics-h"
   STDOPT: +"-load-plugin eva.mthread -mt-h"
   STDOPT: +"-load-plugin nonterm -nonterm-h"
   STDOPT: +"-load-plugin obfuscator -obfuscator-h"
   STDOPT: +"-load-plugin occurrence -occurrence-h"
   STDOPT: +"-load-plugin pdg -pdg-h"
   STDOPT: +"-load-plugin reduc -reduc-h"
   STDOPT: +"-load-plugin region -region-h"
   STDOPT: +"-load-plugin report -report-h"
   STDOPT: +"-load-plugin rtegen -rte-h"
   STDOPT: +"-load-plugin scope -scope-h"
   STDOPT: +"-load-plugin security_slicing -security-slicing-h"
   STDOPT: +"-load-plugin constant_propagation -scf-h"
   STDOPT: +"-load-plugin api_generator -server-tsc-h"
   STDOPT: +"-load-plugin slicing -slicing-h"
   STDOPT: +"-load-plugin sparecode -sparecode-h"
   STDOPT: +"-load-plugin studia -studia-h"
   STDOPT: +"-load-plugin users -users-h"
   STDOPT: +"-load-plugin volatile -volatile-h"

   FILTER: sed -e 's+\(proof process .default: \).*+\1<nproc>\)+g'
   STDOPT: +"-load-plugin wp -wp-h"

   ENABLED_IF: %{lib-available:zmq}
   STDOPT: +"-load-plugin server -server-h"
*/
