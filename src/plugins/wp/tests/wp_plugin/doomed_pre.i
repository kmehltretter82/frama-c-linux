/* run.config
   OPT: -wp-smoke-tests
*/

/* run.config_qualif
   OPT: -wp-smoke-tests
*/

//@ requires a < 0 && a > 0 ;
void default_requires(int a){}

/*@ requires a < 0 ;
    behavior B:
      assumes a > 0 ;
*/
void default_reqs_assumes(int a){}

/*@ behavior B:
      assumes a < 0 && a > 0 ; // not detected
*/
void only_assumes(int a){}

/*@ behavior B:
      assumes  a > 0 ;
      requires a < 0 ;
*/
void bhv_requires_assumes(int a){}
