Require Import Datatype.
Require Import Primitive.

Parameter cvar : Data.
Parameter cfield : Data.
Parameter ctypedef : Data.
Parameter label : Data.

Inductive cref : Set :=
  | Rvoid : cref
  | Rint : cint -> cref
  | Rflt : cflt -> cref
  | Rdef : ctypedef -> cref.

Inductive ctype : Set := 
  | Cptr : cref -> ctype
  | Cint : cint -> ctype
  | Cflt : cflt -> ctype
  | Carray  : ctype -> Z -> ctype
  | Cstruct : [ cfield => ctype ] -> ctype
  | Cunion  : [ cfield => ctype ] -> ctype.

Record cenv : Type := {
  g_var : cvar -> ctype ;
  g_typedef : ctypedef -> ctype
}.

Inductive lval : Set :=
  | Lvar : cvar -> lval
  | Lshift : lval -> exp -> lval
  | Lfield : lval -> cfield -> lval
  | Lderef : exp -> lval

with exp : Set :=
  | Lval   : lval -> exp
  | AddrOf : lval -> exp
  | Shift  : exp -> exp -> exp
  | Op     : op -> exp -> exp -> exp.

Inductive instr : Set :=
  | Instr : lval -> exp -> instr
  | Guard : exp -> instr.

Definition stmt := ( label * instr * label )%type.
Definition program := List.list stmt.




