(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
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
