Require Import Datatype.
Open Scope Z_scope.

Parameter base : Data. 

Definition Addr := Pair base Int.

Definition shift (p : Addr) (k : Z) : Addr := ( fst p , snd p + k ).

Definition separated p n q m :=
  forall i j, 0 <= i <= n -> 0 <= j <= m -> shift p i <> shift q j.

Definition in_ptr_range (p : Addr) n q :=
  fst p = fst q /\ snd p <= snd q < snd p + n.

Definition ptr_range (p:Addr) n q : decide ( in_ptr_range p n q ).
Proof.
  unfold in_ptr_range.
  induction (eqdec base (fst p) (fst q)) as [Eq | Neq] ;
  induction (range_dec n (snd q - snd p)) ;
  try (by left) ;
  try (by right).
Qed.

Definition read_at_ptr {A} (phi : Addr -> A) (p : Addr) : Z -> A 
  := fun k => phi (shift p k).
Infix "@" := read_at_ptr (at level 70).

Definition copy_to_ptr {A} (phi : Z -> A) (p : Addr) : Addr -> A
  := fun (q : Addr) => phi (snd q - snd p).
Infix "&" := copy_to_ptr (at level 70).

Definition offset {A:Type} (m : Z -> A) (p:Z) := fun k => m (p+k).
Infix "<+>" := offset (at level 70).

Definition forall_range (phi : Z -> Prop) n : Prop := forall k, 0 <= k < n -> phi k.
Infix "/:" := forall_range (at level 70).

Definition eq_range {A : Type} n (a b : Z -> A) := (fun k => a k = b k) /: n.
Notation "a =/ n b" := (eq_range n a b) (at level 70, n at level 0).

