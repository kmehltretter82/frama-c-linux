
//@ lemma direct_in: 2 \in {1,2,3};
//@ lemma direct_in_singleton: 2 \in {2};

//@ logic set<integer> Set1 = {1,2,3};
//@ lemma indirect_in_constants: 2 \in Set1;
//@ lemma indirect_not_in_constants: ! (4 \in Set1);
//@ lemma indirect_equal_constants: Set1 == {1,2,3};
//@ lemma indirect_not_equal_constants: Set1 != {0,1,2};

//@ logic integer i0 = 0;
//@ logic integer i1 = 1;
//@ logic integer i2 = 2;
//@ logic integer i3 = 3;
//@ logic set<integer> Set3 = {i1,i2,i3};
//@ lemma indirect_in_logical: i2 \in Set3;
//@ lemma indirect_not_in_logical: ! (i0 \in Set3);
//@ lemma indirect_equal_logical: Set3 == {i1,i2,i3};
//@ lemma indirect_not_equal_logical: Set3 != {i0,i1,i2};

//@ ghost int int1 = 1;
//@ ghost int int2 = 2;
//@ ghost int int3 = 3;
//@ logic set<int> Set2 = {int1,int2,int3};
//@ lemma indirect_in_ghost: int2 \in Set2;
//@ lemma indirect_equal_ghost: Set2 == {int1,int2,int3};

/*@
  logic set<integer> iota(integer n) =
    (n <= 0) ? {0} : \union({n}, iota(n-1)) ;

  lemma rec_iota:
    \forall integer i, n;
    i \in iota(n) ==> i==n || i \in iota(n-1);

  lemma iota0_compute_0in_constants: 0 \in iota(0);
  lemma iota3_compute_0in_constants: 0 \in iota(3);
  lemma iota3_compute_2in_constants: 2 \in iota(3);
  lemma iota3_compute_equal_constants: iota(3) == { 0, 1, 2, 3 };

*/
