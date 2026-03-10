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

type addr = LV of lval | TLV of term_lval | ADDR of exp | TADDR of term
type value = E of exp | T of term
type guard =
  | Bounds of value * Z.t
  | Non_null of addr
  | Valid of addr
  | Valid_read of addr
  | Valid_object of addr
  | Valid_region of node * addr
  | Initialized of addr
  | Aligned of addr

type condition =
  | Forall of quantifiers * condition
  | Hyp of predicate * condition
  | Let of logic_info * condition
  | At of condition * logic_label
  | Guard of guard

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
val create : kernel_function -> ?stmt:stmt -> map -> env
val iter : (names:string list -> invalid:bool -> condition -> unit) -> env -> unit

val valid : env -> node -> addr -> unit
val valid_read : env -> node -> addr -> unit
val valid_region : env -> node -> addr -> unit
val initialized : env -> node -> addr -> unit
val aligned : env -> node -> addr -> unit
val readable : env -> node -> addr -> unit
val writable : env -> node -> addr -> unit

val lval : env -> lval -> typ * node
val eval : env -> exp -> unit
val addr : env -> exp -> node
val exp : env -> exp -> node option
val write : env -> lval -> unit
val init : env -> init -> unit
val instr : env -> instr -> unit
val stmtkind : env -> stmtkind -> unit

val term : env -> term -> domain
val pred : env -> predicate -> unit

class visit : env -> Visitor.frama_c_inplace

val guards : kernel_function -> map ->
  (names:string list -> invalid:bool -> condition -> unit) ->
  stmt -> unit

val add_annotation :
  ?kf:kernel_function ->
  ?emitter:Emitter.t ->
  ?names:string list ->
  ?status:Property_status.emitted_status ->
  ?hyps:Property.t list ->
  stmt -> condition -> unit

val is_annotated : kernel_function -> bool
val set_annotated : kernel_function -> unit
val annotate : kernel_function -> unit
