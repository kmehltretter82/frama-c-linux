Require Import Datatype.

Parameter cint : Data.
Parameter cflt : Data.
Parameter char : cint.

Parameter irange : cint -> Z -> Prop.
Parameter frange : cflt -> R -> Prop.

Definition ptype := (cint + cflt)%type.
Definition prim  := (Z + R)%type.

Inductive prange : ptype -> prim -> Prop :=
  | PRIM_int : forall i x, irange i x -> prange (inl i) (inl x)
  | PRIM_flt : forall f u, frange f u -> prange (inr f) (inr u).

Parameter op : Data.
Parameter typeof_op : op -> ptype -> ptype -> ptype -> Prop.
Parameter sem_op    : op -> prim ->  prim ->  prim ->  Prop.

Inductive prim_domain : prim -> forall {t : Type}, t -> Prop :=
  | DOMAIN_int : forall x, prim_domain (inl x) x
  | DOMAIN_flt : forall u, prim_domain (inr u) u.
