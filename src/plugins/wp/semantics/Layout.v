Require Import Datatype.
Require Import Pointer.
Require Import Machine.

Open Scope Z_scope.

Program Definition empty_layout (A : Type) : layout A := {|
  sizeof := 0 ;
  encoding := fun p w => True
|}.
Next Obligation. intuition. Qed.

Program Definition interpret {A B} (phi : B -> A) : layout A -> layout B := 
  fun enc => {| encoding := fun v w => enc (phi v) w ; sizeof := sizeof enc |}.
Next Obligation.
  by (apply (positive enc)).
Qed.
Next Obligation.
  apply (footprint enc H).
Qed. 

Program Definition concat {A B} : layout A -> layout B -> layout (A*B) :=
  fun a b => {| 
    sizeof := sizeof a + sizeof b ;
    encoding := fun p w => (a (fst p) w /\ b (snd p) (w <+> sizeof a)) 
  |}.
Next Obligation.
  generalize (positive a).
  generalize (positive b).
  auto with zarith.
Qed.
Next Obligation.
  simpl.
  cut (b b0 (wa <+> sizeof a) <-> b b0 (wb <+> sizeof a)).
  cut (a a0 wa <-> a a0 wb).
  intuition.
  * apply (footprint a).
      unfold eq_range. 
      intros k R. apply H.
      generalize (positive a).
      generalize (positive b).
      auto with zarith.
  * apply (footprint b).
      unfold eq_range.
      intros k R. unfold offset. apply H.
      generalize (positive a).
      generalize (positive b).
      auto with zarith.
Defined.

Program Definition superpose {A B} : layout A -> layout B -> layout (A * B) :=
  fun a b => {|
    sizeof := Z.max (sizeof a) (sizeof b) ;
    encoding := fun p w => (a (fst p) w /\ b (snd p) w)
  |}.
Next Obligation.
  apply Z.max_case. apply (positive a). apply (positive b).
Qed.
Next Obligation.
  simpl.
  cut (b b0 wa <-> b b0 wb).
  cut (a a0 wa <-> a a0 wb).
  intuition.
  * apply (footprint a).
      unfold eq_range. 
      intros k R. apply H. 
      generalize (Z.le_max_l (sizeof a) (sizeof b)).
      omega.
  * apply (footprint b).
      unfold eq_range.
      intros k R. apply H.
      generalize (Z.le_max_r (sizeof a) (sizeof b)).
      omega.
Defined.

Program Definition concat_n {A} : layout A -> forall n, layout (A[n]) :=
  fun a n => {|
    sizeof := Z.max 0 (n * sizeof a) ;
    encoding := fun v w => forall (k : range n), a (v k) (w <+> k * sizeof a)
  |}.
Next Obligation.
  by (apply Z.le_max_l). 
Qed.
Next Obligation.
  cut (forall k : range n, a (v k) (wa <+> k * sizeof a) 
                       <-> a (v k) (wb <+> k * sizeof a)).
  intuition ; apply H0 ; apply H1.
  intro k.
  apply (footprint a).
    unfold eq_range, forall_range, offset. intros i Ri. simpl. apply H.
    generalize (in_range k). intro Rk.
    generalize (positive a). intro Pa.
    rewrite Z.max_r ; auto with zarith.
    assert (R1 : k <= n-1) by auto with zarith.
    assert (R2 : k * sizeof a <= (n-1) * sizeof a) 
       by (apply Zmult_le_compat_r ; forward).
    assert (R3 : (n-1) * sizeof a = n * sizeof a - sizeof a) by ring.
    rewrite R3 in R2.
    auto with zarith.
Defined.

Program Definition option_layout {A} : layout A -> layout (option A) :=
  fun a => {|
    sizeof := sizeof a ;
    encoding := fun v w => 
      match v with
      | None => forall x, not (a x w)
      | Some x => a x w
      end
  |}.
Next Obligation. exact (positive a). Qed.
Next Obligation.
  induction v.
  + apply (footprint a H).
  + generalize (footprint a H).
    intuition.
    apply (H1 x). by (rewrite H0).
    apply (H1 x). by (rewrite <- H0).
Qed.

