Require Import Datatype.
Require Import Primitive.
Require Import Cil.
Require Import Pointer.
Require Import Machine.
Require Import Values.
Require Import Typing.

Record Compiler := { cc_env :> Gamma ; cc_link : cvar -> base }.

Inductive sem_lval (G : Compiler) (m : mem) : lval -> Addr -> Prop :=

  | Svar : forall x,
      (* ----------------------------------------------- *)
      sem_lval G m (Lvar x) ( G.(cc_link) x , 0 )

  | Sshift_l : forall l t {d} (enc : layout d) p a (k:Z),
      typeof_lval G l t ->
      overlay m t enc ->
      sem_lval G m l p ->
      sem_exp G m a k ->
      (* ----------------------------------------------- *)
      sem_lval G m (Lshift l a) (shift p (sizeof enc * k))

  | Sfield_s : forall l s p f k,
      typeof_lval G l (Cstruct s) ->
      field_offset m f k s ->
      sem_lval G m l p ->
      (* ----------------------------------------------- *)
      sem_lval G m (Lfield l f) (shift p k)

  | Sfield_u : forall l s p f,
      typeof_lval G l (Cunion s) ->
      sem_lval G m l p ->
      (* ----------------------------------------------- *)
      sem_lval G m (Lfield l f) p

with sem_exp (G : Compiler) (m : mem) : exp -> forall {T : Type}, T -> Prop :=

  | Sem_lval : forall l t p d (enc : layout d) (v : d),
      typeof_lval G l t ->
      overlay m t enc ->
      sem_lval G m l p ->
      read enc m p v ->
      (* ----------------------------------------------- *)
      sem_exp G m (Lval l) v

  | Sem_addrof : forall l p,
      sem_lval G m l p ->
      (* ----------------------------------------------- *)
      sem_exp G m (AddrOf l) p

  | Sem_shift : forall a p r {d} (enc : layout d) b k,
      typeof_exp G a (Cptr r) ->
      overlay m (typeof_ref G r) enc ->
      sem_exp G m a p ->
      sem_exp G m b k ->
      (* ----------------------------------------------- *)
      sem_exp G m (Shift a b) (shift p (sizeof enc * k))

  | Sem_op : forall op a b (ta tb tc : Type)
             pa (va : ta) pb (vb : tb) pc (vc : tc),	
      prim_domain pa va -> sem_exp G m a va ->
      prim_domain pb vb -> sem_exp G m b vb ->
      prim_domain pc vc -> sem_op op pa pb pc ->
      (* ----------------------------------------------- *)
      sem_exp G m (Op op a b) vc
      
.

Theorem sem_welltyped (G : Compiler) (m : mem) :
  forall e t d (v : d),
    typeof_exp G e t ->
    sem_exp G m e v ->
    domain t d.
Admitted.

