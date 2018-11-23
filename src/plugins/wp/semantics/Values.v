Require Import Datatype.
Require Import Cil.
Require Import Pointer.
Require Import Machine.
Require Import Layout.

(** * Type Interpretation *)

Definition Ccomp := [ cfield => ctype ].
Definition Dcomp := [ cfield => Type ].

Inductive domain : ctype -> Type -> Prop :=
  | Dptr : forall p, domain (Cptr p) Addr
  | Dint : forall i, domain (Cint i) Z
  | Dflt : forall f, domain (Cflt f) R
  | Darr : forall t n d, domain t d -> domain (Carray t n) (d[n])
  | Dstruct : forall s r, compound s r -> domain (Cstruct s) {[ r ]}
  | Dunion  : forall s r, compound s r -> domain (Cunion s) {[ r ?]} 

with compound : Ccomp -> Dcomp -> Prop :=
  | Dempty : compound empty empty
  | Dfield : forall f t d T D, 
             domain t d -> 
             compound T D ->
	     compound (add f t T) (add f d D).

(** * Type Layout *)

Definition head_record (f : cfield) T R (r : record (add f T R)) : T * record R :=
  match r with
  | Rempty => False
  | Rfield _ _ v _ r => (v,r)
  end.

Definition struct_field (f : cfield) {T R} : 
  layout T -> layout (record R) -> layout (record (add f T R))
  := fun a r => interpret (head_record f T R) (concat a r).

Definition head_union (f : cfield) T U (u : union (add f T U)) : (option T) * union U :=
  match u with
  | Uempty => False
  | Uskip _ _ _ u => (None,u)
  | Ufield _ _ v _ u => (Some v,u)
  end.

Definition union_field (f : cfield) {T R} :
  layout T -> layout (union R) -> layout (union (add f T R))
  := fun a r => interpret (head_union f T R) (superpose (option_layout a) r).

Inductive overlay arch : ctype -> forall {t}, layout t -> Prop :=
  | Lptr : forall p, overlay arch (Cptr p) (ptr_layout arch)
  | Lint : forall i, overlay arch (Cint i) (int_layout arch i)
  | Lflt : forall f, overlay arch (Cflt f) (flt_layout arch f)
  | Lstruct : forall s r (e : layout {[ r ]}), struct_overlay arch s e -> overlay arch (Cstruct s) e
  | Lunion  : forall s r (e : layout {[ r ?]}), union_overlay arch s e -> overlay arch (Cunion s) e

with struct_overlay arch : Ccomp -> forall {r:Dcomp}, layout {[ r ]} -> Prop :=
  | Sempty : struct_overlay arch empty (empty_layout {[ empty ]})
  | Sfield : forall (f : cfield) t {d} (e : layout d) 
                                 T {D} (R : layout {[ D ]}),
               overlay arch t e ->
	       struct_overlay arch T R ->
	       struct_overlay arch (add f t T) (struct_field f e R)

with union_overlay arch : Ccomp -> forall {r:Dcomp}, layout {[ r ?]} -> Prop :=
  | Uempty : union_overlay arch empty (empty_layout {[ empty ?]})
  | Ufield : forall (f : cfield) t {d} (e : layout d) 
                                   T {D} (R : layout {[ D ?]}),
               overlay arch t e ->
	       union_overlay arch T R ->
	       union_overlay arch (add f t T) (union_field f e R).

Inductive field_offset arch : cfield -> Z -> Ccomp -> Prop :=
  | Ofs_field : forall f t T, field_offset arch f 0 (add f t T)
  | Ofs_next  : forall f k g (t : ctype) {d} (enc : layout d) T, 
       overlay arch t enc ->
       field_offset arch f k T ->
       field_offset arch f (sizeof enc + k) (add g t T).

(** * Type and Domain Consistency *)

Theorem overlay_domain : forall arch t d (e : layout d), overlay arch t e -> domain t d
   with struct_overlay_domain : forall arch T D (R : layout {[ D ]}), struct_overlay arch T R -> compound T D
   with union_overlay_domain : forall arch T D (R : layout {[ D ?]}), union_overlay arch T R -> compound T D.
Proof.
* intros.
  induction H.
  + apply Dptr.
  + apply Dint.
  + apply Dflt.
  + apply Dstruct.
    apply (struct_overlay_domain arch s r e). assumption.
  + apply Dunion.
    apply (union_overlay_domain arch s r e). assumption.
* intros.
  induction H. 
  - apply Dempty. 
  - apply Dfield. 
      + by (apply (overlay_domain arch t d e)).
      + by (apply (struct_overlay_domain arch T D R)).
* intros. 
  induction H.
  - apply Dempty.
  - apply Dfield.
      + by (apply (overlay_domain arch t d e)).
      + by (apply (union_overlay_domain arch T D R)).
Qed.


