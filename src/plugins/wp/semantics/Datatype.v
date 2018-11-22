(** Basic Datatypes *)

Set Implicit Arguments.

Require Export Bool.
Require Export Reals.
Require Export ZArith.
Require Export Program.
Open Scope Z_scope. 

(** ** Tactics for finishing proof trees. *)

Ltac forward := 
  repeat (first [ split | intros ]) ; 
  try discriminate ; 
  try contradiction ; 
  try tauto ; 
  try constructor ; 
  try (apply False_ind ; omega ; fail) ;
  try (apply False_ind ; auto with zarith ; fail) ;
  auto with zarith.

Ltac finish := forward ; fail.

Tactic Notation "by" tactic(A) := A ; finish.

(** ** Empty Set. *)

Inductive Void : Set := .

(** ** Unit Set. *)

Inductive Unit : Set := unit.

(** ** Decidability. *)

Definition decide P := {P}+{~P}.

Definition isTrue p := (p = true).
Definition isFalse p := (p = false).
(*
Lemma not_is_true  : forall p, ~(isTrue p) -> isFalse p.
Lemma not_is_false : forall p, ~(isFalse p) -> isTrue p.
*)

Coercion bool2p := isTrue.

Lemma split_andb : forall p q, p && q <-> p /\ q. 
Proof. intros p q. induction p ; induction q ; intuition. Qed.

Lemma split_orb  : forall p q, p || q <-> p \/ q. 
Proof. intros p q. induction p ; induction q ; intuition. Qed.

(** ** Types with decidable equality. *)

Record Data := {
  type :> Set ;
  eqdec : forall (a b : type), decide (a=b)
}.

Definition eqb {D : Data} (a b : D) :=
  match eqdec _ a b with
  | left _ => true
  | right _ => false
  end.

Notation "a == b" := (@eqb _ a b) (at level 70).

(** ** Tactics for proof by case on Data equality. *)

Lemma eqb_true : forall (D : Data) (x y : D), x=y -> (x==y) = true.
Proof. intros. rewrite H. unfold eqb. induction (eqdec _ y y). trivial. auto. Qed.

Lemma eqb_false : forall (D : Data) (x y : D), x<>y -> (x==y) = false.
Proof. intros. unfold eqb. induction (eqdec _ x y). rewrite a in H. intuition. trivial. Qed.

Ltac equality a b :=
  let Eq := fresh "Eq_" a "_" b in
  let Neq := fresh "Neq_" a "_" b in
  induction (eqdec _ a b) as [ Eq | Neq ] ; 
  [ try (rewrite Eq in *) ; try (rewrite eqb_true in *) 
  | try (rewrite Neq in *) ; try (rewrite eqb_false in *)
  ] ; auto.

(** ** Dependent Equalities. *)

(** Lift an equality [x = y] into an equality over [u : B x] and [v : B y]. *)
Definition lift_eq {A : Set} (B : A -> Set) {x y : A} (p : x = y) : B x -> B y -> Prop :=
  let P := fun z => B x -> B z -> Prop in
  let E := (@eq (B x)) in
  eq_rect x P E y p.

(** List is the expected equality. *)
Lemma lift_eq_is_eq : 
  forall (A : Set) (B : A -> Set) x, 
  lift_eq B (eq_refl x) = (fun (y z : B x) => y = z).
Proof. intros. simpl. trivial. Qed.

(** ** Typical Data *)

Program Definition Int : Data := {| type := Z |}.
Next Obligation. apply Z.eq_dec. Qed.

Lemma fst_neq : forall A B, forall (p q : A*B), fst p <> fst q -> p <> q.
  Proof. intros. unfold not. intro E. rewrite E in H. auto. Qed.
Lemma snd_neq : forall A B, forall (p q : A*B), snd p <> snd q -> p <> q.
  Proof. intros. unfold not. intro E. rewrite E in H. auto. Qed.

Program Definition Pair (A B : Data) : Data := {| type := A * B |}.
Next Obligation.
  elim (eqdec A t1 t) ; elim (eqdec B t2 t0) ; intros.
  * left. rewrite a,a0. trivial.
  * right. apply snd_neq. auto.
  * right. apply fst_neq. auto.
  * right. apply fst_neq. auto.
Qed.

(** ** Functional Updates *)

Definition select {A B : Type} {P : A -> Prop} (s : forall a, decide(P a)) (a b : A -> B) 
  := fun k => if s k then a k else b k.

(** ** Finite Environments *)

Inductive env {A B : Type} : Type :=
  | empty : env
  | add : A -> B -> env -> env.

Notation "[ A => B ]" := (@env A B).

Fixpoint map {A B C : Type} (f : A -> B -> C) (e : [A => B]) : [A => C] :=
  match e with
  | empty => empty
  | add x v e => add x (f x v) (map f e)
  end.

Fixpoint find {A : Data} {B : Type} (x : A) e (d : B) :=
  match e with	
  | empty => d
  | add x' v e => if x == x' then v else find x e d
  end.

Fixpoint bind {A : Data} {B : Type} (x : A) (v : B) e : Prop :=
  match e with
  | empty => False
  | add x' v' e => if x == x' then v = v' else bind x v e
  end.

Lemma bind_map_exists :
  forall (A : Data) (B C : Type) (f : A -> B -> C),
    forall x w e, bind x w (map f e) -> exists v, bind x v e /\ w = f x v.
Proof.
  intros.
  induction e.
  * by (simpl in H).
  * simpl in H. equality x a. 
    - exists b. simpl. rewrite eqb_true ; auto.
    - simpl. rewrite eqb_false ; auto.
Qed.

Lemma bind_map :
  forall (A : Data) (B C : Type) (f : A -> B -> C),
    forall x v e, bind x v e -> bind x (f x v) (map f e).
Proof.
  intros.
  induction e ; simpl in * ; auto.
  equality x a ; rewrite H ; auto.
Qed.

Inductive subset {A B : Type} : [ A => B ] -> [ A => B ] -> Prop :=
  | Sub_empty : subset empty empty
  | Sub_skip  : forall a b w1 w2, subset w1 w2 -> subset w1 (add a b w2)
  | Sub_same  : forall a b w1 w2, subset w1 w2 -> subset (add a b w1) (add a b w2).

(** ** Records (dependent maps) *)

Inductive record {A : Type} : [ A => Type ] -> Type :=
  | Rempty : record empty
  | Rfield : forall (a:A) {t:Type} (v:t) 
                          {r:[A => Type]} (R:record r),
                          record (add a t r).

Notation "{[ m ]}" := (record m).

Inductive union {A : Type} :  [ A => Type ] -> Type :=
  | Uempty : union empty
  | Uskip  : forall (a:A) { t: Type } (* no value *)
                          { u: [A => Type] } (U:union u),
                          union (add a t u)
  | Ufield : forall (a:A) { t: Type } (v:t) (* some value *)
                          { u: [A => Type] } (U:union u),
                          union (add a t u).

Notation "{[ m ?]}" := (union m).

(** ** Positive integers *)

Coercion Z.pos : positive >-> Z.

(** ** Finite integers *)

Record range (n : Z) : Type :=
  { index :> Z ; in_range : 0 <= index < n }.

Definition range_dec (n k : Z) : decide (0 <= k < n).
Proof.
  induction (Z_le_dec 0 k) ; induction (Z_lt_dec k n) ; try (by left) ; try (by right).
Qed.

Fixpoint iter (P : nat -> bool) n := 
  match n with
  | O => true
  | S n => P n && iter P n
  end.

Lemma iter_forall : 
  forall P n, iter P n -> (forall k, (k < n)%nat -> P k).
Proof.
  intros P n.
  induction n.
  * simpl. intros. omega.
  * simpl. intros Step k Rk.
    rewrite split_andb in Step.
    assert (Rn : (k <= n)%nat) by omega.
    induction (le_lt_eq_dec k n) as [Lt | Eq] ; auto with arith.
    + by (apply IHn).
    + by (rewrite Eq).
Qed.

(** ** Arrays of known size *)

Definition array (A : Type) (n : Z) : Type := range n -> A.
Notation "a [ n ]" := (array a n) (at level 10).

Definition slice {A} p n (w : Z -> A) : A[n] := fun k : range n => w (p+k).

Definition get {A n} (a : A[n]) k rk := a {| index := k ; in_range := rk |}.
Implicit Arguments get [A n].

Definition split {n m} (k : range (n+m)) : {0 <= k < n}+{0<= k-n < m}.
Proof. 
  generalize (in_range k). intro Rk.
  induction (range_dec n k) ; [ left | right] ; forward.
Qed.

Definition concat {A n m} (a : A[n]) (b : A[m]) : A[n+m] :=
  fun k : range (n+m) =>
    match split k with
    | left p => get a k p
    | right q => get b (k-n) q
    end.

Lemma concat_l {A n m} (a : A[n]) (b : A[m]) :
  forall (k : range (n+m)) (r : 0 <= k < n), (concat a b) k = get a k r.
Proof.
  intros.
  unfold concat.
  destruct (split k).
  + apply f_equal. apply proof_irrelevance.
  + generalize (in_range k). intros. omega.
Qed.

Lemma concat_r {A n m} (a : A[n]) (b : A[m]) :
  forall (k : range (n+m)) (r : 0 <= k-n < m), (concat a b) k = get b (k-n) r.
Proof.
  intros.
  unfold concat.
  destruct (split k).
  + generalize (in_range k). intros. omega.
  + apply f_equal. apply proof_irrelevance.
Qed.

Lemma array_inj {A n} : forall (a b : A[n]),
  (forall k : range n, a k = b k) -> a = b.
Proof.
  intros a b Elt.
  extensionality k.
  apply Elt.
Qed.

Record vector (A : Type) : Type := { size ; elt :> A[size] }.
Notation "a []" := (vector a) (at level 10).

Definition compatible {A n m} (a : A[n]) (b : A[m]) :=
  forall k (ka : 0 <= k < n) (kb : 0 <= k < m), 
    get a k ka = get b k kb.




