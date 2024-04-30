(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2024                                               *)
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

open Cil_types

type scope =
  | Global
  | Function
  | Block

module H = Datatype.String.Hashtbl
let tbl = H.create 7
let globals = H.create 7

let get ~scope s =
  let _, u =
    Extlib.make_unique_name
      (fun s -> H.mem tbl s || H.mem globals s)
      ~sep:"_"
      s
  in
  let add = match scope with
    | Global -> H.add globals
    | Function | Block -> H.add tbl
  in
  add u ();
  u

let clear_locals () = H.clear tbl

let rec of_exp ?default exp = match exp.enode with
  | Lval (Var {vorig_name}, NoOffset) -> vorig_name
  | Const (CInt64 (i, _, _)) -> "const_" ^ Integer.to_string i
  | BinOp (MinusA, x, y, _) -> "minus_" ^ of_exp x ^ "_" ^ of_exp y
  | BinOp (PlusA, x, y, _) -> "plus_" ^ of_exp x ^ "_" ^ of_exp y
  | e ->
    match default with
    | None ->
      Options.debug "Varname.of_exp: supply default or extend this function \
                     to handle enodes like: %a" Cil_types_debug.pp_exp_node e;
      "exp"
    | Some default -> default

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
