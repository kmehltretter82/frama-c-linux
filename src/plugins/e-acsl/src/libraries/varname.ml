(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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

let of_binop = function
  | PlusA -> "plus"
  | PlusPI -> "plus"
  | MinusA -> "minus"
  | MinusPI -> "minus"
  | MinusPP -> "minus"
  | Mult -> "mult"
  | Div -> "div"
  | Mod -> "mod"
  | Shiftlt -> "shiftl"
  | Shiftrt -> "shiftr"
  | Lt -> "lt"
  | Gt -> "gt"
  | Le -> "le"
  | Ge -> "ge"
  | Eq -> "eq"
  | Ne -> "ne"
  | BAnd -> "and"
  | BXor -> "xor"
  | BOr -> "or"
  | LAnd -> "and"
  | LOr -> "or"

let of_unop = function
  | Neg -> "neg"
  | BNot -> "not"
  | LNot -> "not"

let rec of_exp ?default exp = match exp.enode with
  | Lval (Var {vorig_name}, NoOffset) -> vorig_name
  | Const (CInt64 (i, _, _)) -> "const_" ^ Z.to_string i
  | BinOp (op, x, y, _) -> of_binop op ^ of_exp x ^ "_" ^ of_exp y
  | UnOp (op, x, _) -> of_unop op ^ of_exp x
  | e ->
    match default with
    | None ->
      Options.debug "Varname.of_exp: supply default or extend this function \
                     to handle enodes like: %a" Cil_types_debug.pp_exp_node e;
      "exp"
    | Some default -> default
