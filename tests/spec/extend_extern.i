/* run.config
   MACRO: PTEST_MAKE_MODULE make FRAMAC_USER_OFLAGS="-package why3" FRAMAC_USER_BFLAGS="-package why3"
   MODULE: @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT:
 */
/*@ predicate load(char * x) = \true ; */
/*@ why3 load("List"); */
