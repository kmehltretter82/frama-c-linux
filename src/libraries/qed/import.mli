(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type depends
val depends : unit -> depends
val iter : (Why3.Theory.tdecl -> unit) -> depends -> unit

type 'a symbol
val use : depends -> 'a symbol -> 'a

val find_ts : Why3.Env.env -> string -> Why3.Ty.tysymbol symbol
val find_ls : Why3.Env.env -> string -> Why3.Term.lsymbol symbol
val find_pr : Why3.Env.env -> string -> Why3.Decl.prsymbol symbol
