Require Import Datatype.
Require Import Primitive.
Require Import Cil.

Record Gamma : Type := {
  g_var : cvar -> ctype ;
  g_type : ctypedef -> ctype
}.

Definition typeof_ref (G : Gamma) (r : cref) : ctype :=
  match r with
  | Rvoid  => Cint char
  | Rint i => Cint i
  | Rflt f => Cflt f
  | Rdef d => G.(g_type) d
  end.

Definition ptype (p : ptype) : ctype := 
  match p with 
  | inl i => Cint i 
  | inr f => Cflt f 
  end.

Inductive typeof_exp (G : Gamma) : exp -> ctype -> Prop := 

  | Tlval : forall l t,
      typeof_lval G l t ->  
      (* -------------------------------------- *)
      typeof_exp G (Lval l) t

  | Taddrof : forall l r,
      typeof_lval G l (typeof_ref G r) -> 
      (* -------------------------------------- *)
      typeof_exp G (AddrOf l) (Cptr r)

  | Tshift : forall p k r i,
      typeof_exp G p (Cptr r) ->
      typeof_exp G k (Cint i) ->
      (* -------------------------------------- *)
      typeof_exp G (Shift p k) (Cptr r)

  | Top : forall op a pa b pb pr,
     typeof_op op pa pb pr ->
     typeof_exp G a (ptype pa) ->
     typeof_exp G b (ptype pb) ->
     (* --------------------------------------- *)
     typeof_exp G (Op op a b) (ptype pr)

with typeof_lval (G : Gamma) : lval -> ctype -> Prop :=

  | Tvar : forall x, 
      (* -------------------------------------- *)
      typeof_lval G (Lvar x) (G.(g_var) x)

  | Tshift_l : forall l t n e i, 
      typeof_lval G l (Carray t n) ->
      typeof_exp  G e (Cint i) ->
      (* -------------------------------------- *)
      typeof_lval G (Lshift l e) t                     

  | Tfield_s : forall l s f t,
      typeof_lval G l (Cstruct s) ->
      bind f t s ->
      (* -------------------------------------- *)
      typeof_lval G (Lfield l f) t

  | Tfield_u : forall l s f t,
      typeof_lval G l (Cunion s) ->
      bind f t s ->
      (* -------------------------------------- *)
      typeof_lval G (Lfield l f) t

  | Tderef : forall p r,
      typeof_exp G p (Cptr r) ->
      (* -------------------------------------- *)
      typeof_lval G (Lderef p) (typeof_ref G r)
.

