/* run.config
<<<<<<< HEAD
   CMD: @frama-c@ -wp -wp-msg-key shell,cluster,print-generated -wp-prover why3 -wp-gen @OPTIONS@ -wp-warn-key "pedantic-assigns=inactive"
||||||| ac7807782d
   CMD: @frama-c@ -wp -wp-msg-key shell,cluster,print-generated -wp-prover why3 -wp-gen -wp-share ./share
=======
   CMD: @frama-c@ -wp -wp-msg-key shell,cluster,print-generated -wp-prover why3 -wp-gen -wp-share ./share -wp-warn-key "pedantic-assigns=inactive"
>>>>>>> origin/master
   OPT:
*/

/* run.config_qualif
   DONTRUN:
*/

struct FD {
	int pos;
	int *adr;
};

struct A { int dummy; };

/*@
	//requires \valid(fd);
	//requires \valid(a);
	//requires \separated(a,fd);
	assigns fd->pos;
	assigns *a;
	ensures fd->pos != \old(fd->pos);
*/
int myRead(struct FD* fd,struct A* a);

/*@
	//requires \valid(fd);
	//requires \valid(a);
	//requires \separated(a,fd);
	ensures KO: *a == \old(*a);
*/
void myMain(struct FD* fd,struct A* a)
{
	//@ assigns KO: *a;
	myRead(fd,a);
}
