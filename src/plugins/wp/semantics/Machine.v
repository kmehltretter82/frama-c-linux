Require Import Datatype.
Require Import Primitive.
Require Import Pointer.

Set Implicit Arguments.

Inductive byte : Type :=
  | Byte  : forall b, 0 <= b < 255 -> byte
  | Ptr   : Addr -> nat -> byte
  | Undef : byte.

Inductive perm := Read | Write.
Definition grants p q := p = Write \/ q = Read.
Definition granted q p := p = Write \/ q = Read. 

Definition bytes := Z -> byte.
Definition perms := Z -> perm.

Record layout (A : Type) := {
  encoding :> A -> bytes -> Prop ;
  sizeof : Z ;
  positive : 0 <= sizeof ;
  footprint : forall {wa wb},
      	      wa =/ sizeof wb ->
      	      forall v, encoding v wa <-> encoding v wb
}.

Record architecture := {
  int_layout : cint -> layout Z ;
  flt_layout : cflt -> layout R ;
  ptr_layout : layout Addr ;
  char_size  : sizeof (int_layout char) = 1
}.

Record mem := { 
  byte_at : Addr -> byte ;
  perm_at : Addr -> perm ;
  arch :> architecture
}.

Definition undef {A} : A -> byte := fun _ => Undef.

Definition mload (m : mem) (p : Addr) (n : Z) : bytes :=
  select (range_dec n) (byte_at m @ p) undef.

Definition store (m : mem) (p : Addr) n (v : bytes) : mem := 
{|
  arch := m ;
  perm_at := perm_at m ;
  byte_at := select (ptr_range p n) (v & p) (byte_at m)
|}.

Definition valid (pi : perm) (m : mem) (p : Addr) n : Prop :=
  (fun k => grants (perm_at m (shift p k)) pi) /: n.

Record read {A} (T : layout A) 
  (m : mem) (p : Addr) (a : A) : Prop 
:= {
  valid_read :> valid Read m p (sizeof T) ;
  value_read :> T a (mload m p (sizeof T))
}.

Record written {A} (T : layout A)
  (m : mem) (p : Addr) (a : A) (v : bytes) (m' : mem) : Prop
:= {
  valid_write :> valid Write m p (sizeof T) ;
  value_write :> T a v ;
  mem_write : m' = store m p (sizeof T) v
}.

Definition write {A} (T : layout A)
  (m : mem) (p : Addr) (a : A) (m' : mem) : Prop 
  := exists v, written T m p a v m'.
