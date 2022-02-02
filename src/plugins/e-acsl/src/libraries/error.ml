(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

exception Ignored
let ignored () = raise Ignored

exception Typing_error of string
let untypable s = raise (Typing_error s)

exception Not_yet of string
let not_yet s = raise (Not_yet s)

exception Not_memoized
let not_memoized () = raise Not_memoized

module Nb_typing =
  State_builder.Ref
    (Datatype.Int)
    (struct
      let name = "E_ACSL.Error.Nb_typing"
      let default () = 0
      let dependencies = [ Ast.self ]
    end)

let nb_untypable = Nb_typing.get

module Nb_not_yet =
  State_builder.Ref
    (Datatype.Int)
    (struct
      let name = "E_ACSL.Error.Nb_not_yet"
      let default () = 0
      let dependencies = [ Ast.self ]
    end)

let nb_not_yet = Nb_not_yet.get

let print_not_yet msg =
  let msg =
    Format.sprintf "@[E-ACSL construct@ `%s'@ is not yet supported.@]" msg
  in
  Options.warning ~once:true ~current:true "@[%s@ Ignoring annotation.@]" msg;
  Nb_not_yet.set (Nb_not_yet.get () + 1)

let generic_handle f res x =
  try
    f x
  with
  | Typing_error s ->
    let msg = Format.sprintf "@[invalid E-ACSL construct@ `%s'.@]" s in
    Options.warning ~once:true ~current:true "@[%s@ Ignoring annotation.@]" msg;
    Nb_typing.set (Nb_typing.get () + 1);
    res
  | Not_yet s ->
    print_not_yet s;
    res
  | Ignored -> res

let handle f x = generic_handle f x x

type 'a or_error = Res of 'a | Err of exn

let retrieve_preprocessing analyse_name getter parameter =
  try
    match getter parameter with
    | Res res -> res
    | Err exn -> raise exn
  with Not_memoized ->
    Options.fatal "%s was not performed on construct" analyse_name

(*
Local Variables:
compile-command: "make"
End:
*)
