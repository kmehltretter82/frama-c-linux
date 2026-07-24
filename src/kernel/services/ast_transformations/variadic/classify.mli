(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Checks if the given name is the name of one of the variadic va_* builtins *)
val is_va_builtin : string -> bool

(** Build a variadic function record for the given [varinfo] according to its
    classification. Returns [None] if the function is not variadic. *)
val classify : Environment.t -> Cil_types.varinfo ->
  Va_types.variadic_function option
