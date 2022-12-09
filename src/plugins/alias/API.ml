(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)


open Cil_types

let fold_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a =
  function _ ->  failwith "not implemented"

let fold_new_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a =
  function _ -> failwith "not implemented"

let fold_aliases_kf:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a =
  function _ -> failwith "not implemented"

let fold_fundec_stmts _ =
  failwith "not implemented"

let are_aliased  _ =
  failwith "not implemented"

let fold_points_to _ =
  failwith "not implemented"

let fold_points_to_closure  _ =
  failwith "not implemented"
