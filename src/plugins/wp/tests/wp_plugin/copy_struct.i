/* run.config
   OPT: -wp-model region -wp-msg-key print-generated -wp-havoc
   OPT: -wp-model region -wp-msg-key print-generated -wp-no-havoc
*/
/* run.config_qualif
   OPT: -wp-model region -wp-havoc
   OPT: -wp-model region -wp-no-havoc
*/


struct S {
    int fi;
    short fs;
    char fca [6];
};

/*@ predicate pointed(struct S *p, struct S * q) = p==q || \separated(p,q);
*/

/*@
    requires \separated (a, b);
    ensures *a == *b;
*/
//int
void
copy_struct (struct S * a, struct S * b)
{
    *a = *b;
    //return a->fi + a->fs + a->fca[3];
}
