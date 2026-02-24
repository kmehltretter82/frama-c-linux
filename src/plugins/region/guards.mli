(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

open Memory
open Cil_types

type addr = LV of lval | TLV of term_lval
type value = E of exp | T of term
type guard =
  | Bounds of value * Z.t
  | Non_null of addr
  | Valid of addr
  | Valid_read of addr
  | Valid_region of node * addr
  | Initialized of addr
  | Aligned of addr

type condition = {
  vars : quantifiers ;
  hyps : predicate list ;
  guard : guard ;
}

val pp_addr  : Format.formatter -> addr  -> unit
val pp_value : Format.formatter -> value -> unit
val pp_guard : Format.formatter -> guard -> unit
val pp_condition : Format.formatter -> condition -> unit

val of_value : value -> term
val of_addr  : ?loc:location -> addr -> term
val of_guard : ?loc:location -> ?names:string list -> guard -> predicate
val of_condition : ?loc:location -> ?names:string list -> condition -> predicate

val kind : addr -> Condition.lkind
val typeof : addr -> typ (* of the pointed l-value *)

type env
val create : ?stmt:stmt -> map -> env
val iter : (condition -> valid:bool -> unit) -> env -> unit

val valid : env -> node -> addr -> unit
val valid_read : env -> node -> addr -> unit
val valid_region : env -> node -> addr -> unit
val initialized : env -> node -> addr -> unit
val aligned : env -> node -> addr -> unit
val readable : env -> node -> addr -> unit
val writable : env -> node -> addr -> unit

val glval : env -> lval -> typ * node
val geval : env -> exp -> unit
val gaddr : env -> exp -> node
val gexp : env -> exp -> node option
val write : env -> lval -> unit
val init : env -> init -> unit
val instr : env -> instr -> unit
val skind : env -> stmtkind -> unit

val iter_stmt : map -> (condition -> valid:bool -> unit) -> stmt -> unit
