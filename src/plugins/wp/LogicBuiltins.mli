(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Linker for ACSL Builtins                                           --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Lang

type category = Lang.lfun Lang.extern Qed.Logic.category

type kind =
  | B                   (** boolean *)
  | Z                   (** integer *)
  | R                   (** real *)
  | I of Ctypes.c_int   (** C-ints *)
  | F of Ctypes.c_float (** C-floats *)
  | A                   (** Abstract Data *)

val kind_of_tau : tau -> kind

(** Add a new builtin. This builtin will be shared with all created drivers. *)
val add_builtin : string -> kind list -> lfun extern -> unit

(** Add a new builtin type.
    Must be an extern or imported type.
    This builtin will be shared with all created drivers. *)
val add_builtin_type : string -> adt extern -> unit

type driver
val driver: driver Context.value

val new_driver:
  id:string ->
  ?base:driver ->
  ?descr:string ->
  ?configure:(unit -> unit) -> unit ->
  driver
(** Creates a configured driver from an existing one.
    Default:
    - base: builtin WP driver
    - descr: id
    - includes: []
    - configure: No-Op
      The configure is the only operation allowed to modify the content of the
      newly created driver. Except during static initialization of builtin driver.
*)

val id : driver -> string
val descr : driver -> string
val is_default : driver -> bool
val compare : driver -> driver -> int

val add_type : ?source:Fileloc.t ->
  string -> link:string -> unit

val add_alias : source:Fileloc.t ->
  string -> kind list -> alias:string -> unit

val add_ctor : source:Fileloc.t ->
  string -> kind list -> link:string -> unit

val add_logic : source:Fileloc.t ->
  ?category:category -> kind -> string -> kind list -> link:string -> unit

val add_predicate : source:Fileloc.t ->
  string -> kind list -> link:string -> unit

type builtin =
  | ACSLDEF
  | LFUN of lfun extern
  | HACK of (F.term list  -> F.term)

type t_builtin =
  | ADT of adt extern
  | HACKT of (F.tau list -> F.tau)

val logic : logic_info -> builtin
val ctor : logic_ctor_info -> builtin
val constant : string -> builtin
val lookup : string -> kind list -> builtin
val lookup_t : string -> t_builtin
val resolve_t : string -> tau list -> tau

(** Replace a logic definition or predicate by a built-in function.
    The LogicSemantics compilers will replace `Pcall` and `Tcall` instances
    of this symbol with the provided Qed function on terms. *)
val hack : string -> (F.term list -> F.term) -> unit

(** Replace a logic type definition or predicate by a built-in type. *)
val hack_type : string -> (F.tau list -> F.tau) -> unit

val is_builtin_type : string -> bool

val dump : unit -> unit
