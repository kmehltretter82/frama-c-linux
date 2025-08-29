(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* ************************************************************************** *)
(** {2 Type declaration} *)
(* ************************************************************************** *)

type t = { pid: int; mutable name: string; mutable unique_name: string }
type project = t

(* ************************************************************************** *)
(** {2 Constructor} *)
(* ************************************************************************** *)

let dummy = { pid = 0; name = ""; unique_name = "(id: 0)"}

module Make_setter () = struct

  let make_unique_name s id = Format.asprintf "%s (id: %d)" s id

  let make =
    let pid = ref 0 in
    fun name ->
      incr pid;
      { pid = !pid; name = name; unique_name = make_unique_name name !pid }

  let set_name p s =
    p.unique_name <- make_unique_name s p.pid;
    p.name <- s

end

let get_project_debug_name p =
  Format.asprintf "%s (id: %d)" p.name p.pid
