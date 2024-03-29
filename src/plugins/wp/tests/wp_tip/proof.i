/* run.config
   DONTRUN:
*/

/* run.config_qualif
   OPT: -print
 */

// Provers

/*@
  \wp::strategy P1: \prover("alt-ergo");
  \wp::strategy P2: \prover(0.5);
  \wp::strategy P3: \prover("alt-ergo",3.0);
  \wp::strategy P4: P1, P2, P3, \default;
 */
