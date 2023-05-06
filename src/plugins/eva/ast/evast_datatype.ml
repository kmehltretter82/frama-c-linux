(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

open Evast

(* Comparison helper *)

let (<?>) c lcmp =
  if c <> 0 then c else Lazy.force lcmp


(* Prototype modules for Evast types *)

module Prototypes =
struct
  module type S =
  sig
    type t
    val compare : t -> t -> int
    val hash : t -> int
  end

  module rec Lval : S with type t = lval =
  struct
    type t = lval

    let compare (h1,o1) (h2,o2) =
      Lhost.compare h1 h2 <?> lazy (Offset.compare o1 o2)

    let hash (h,o) =
      Hashtbl.hash (Lhost.hash h, Offset.hash o)
  end

  and Lhost : S with type t = lhost =
  struct
    type t = lhost

    let compare h1 h2 =
      match h1, h2 with
      | Var v1, Var v2 -> Cil_datatype.Varinfo.compare v1 v2
      | Var _, Mem _ -> 1
      | Mem e1, Mem e2 -> Exp.compare e1 e2
      | Mem _, Var _ -> -1

    let hash = function
      | Var v -> Hashtbl.hash (1, Cil_datatype.Varinfo.hash v)
      | Mem e -> Hashtbl.hash (2, Exp.hash e)
  end

  and Offset : S with type t = offset =
  struct
    type t = offset

    let rec compare o1 o2 =
      match o1, o2 with
      | NoOffset, NoOffset -> 0
      | NoOffset, _ -> 1
      | _, NoOffset -> -1
      | Field (f1, o1), Field (f2, o2) ->
        Cil_datatype.Fieldinfo.compare f1 f2 <?> lazy (compare o1 o2)
      | Field _, _ -> 1
      | _, Field _ -> -1
      | Index (e1, o1), Index (e2, o2) ->
        Exp.compare e1 e2 <?> lazy (compare o1 o2)

    let rec hash = function
      | NoOffset -> Hashtbl.hash (1, ())
      | Index (e, o) -> Hashtbl.hash (2, Exp.hash e, hash o)
      | Field (f, o) -> Hashtbl.hash (3, f.forder, hash o)
  end

  and Exp : S with type t = exp =
  struct
    type t = exp

    let rec compare e1 e2 =
      match e1.node, e2.node with
      | Const (CString b1 ), Const (CString b2) -> Base.compare b1 b2
      | Const c1, Const c2 -> Constant.compare c1 c2
      | Const _, _ -> 1
      | _, Const _ -> -1
      | Lval lv1, Lval lv2 -> Lval.compare lv1 lv2
      | Lval _, _ -> 1
      | _, Lval _ -> -1
      | SizeOf t1, SizeOf t2 -> Cil_datatype.Typ.compare t1 t2
      | SizeOf _, _  -> 1
      | _, SizeOf _ -> -1
      | SizeOfE e1, SizeOfE e2 -> compare e1 e2
      | SizeOfE _, _ -> 1
      | _, SizeOfE _ -> -1
      | SizeOfStr s1, SizeOfStr s2 -> String.compare s1 s2
      | SizeOfStr _, _ -> 1
      | _, SizeOfStr _ -> -1
      | AlignOf ty1, AlignOf ty2 -> Cil_datatype.Typ.compare ty1 ty2
      | AlignOf _, _ -> 1
      | _, AlignOf _ -> -1
      | AlignOfE e1, AlignOfE e2 -> compare e1 e2
      | AlignOfE _, _ -> 1
      | _, AlignOfE _ -> -1
      | UnOp (op1, e1, ty1), UnOp (op2, e2, ty2) ->
        Extlib.compare_basic op1 op2 <?>
        lazy (compare e1 e2) <?>
        lazy (Cil_datatype.Typ.compare ty1 ty2)
      | UnOp _, _ -> 1
      | _, UnOp _ -> -1
      | BinOp (op1, e11, e21, ty1), BinOp (op2, e12, e22, ty2) ->
        Extlib.compare_basic op1 op2 <?>
        lazy (compare e11 e12) <?>
        lazy (compare e21 e22) <?>
        lazy (Cil_datatype.Typ.compare ty1 ty2)
      | BinOp _, _ -> 1
      | _, BinOp _ -> -1
      | CastE(t1,e1), CastE(t2, e2) ->
        Cil_datatype.Typ.compare t1 t2 <?>
        lazy (compare e1 e2)
      | CastE _, _ -> 1
      | _, CastE _ -> -1
      | AddrOf lv1, AddrOf lv2 -> Lval.compare lv1 lv2
      | AddrOf _, _ -> 1
      | _, AddrOf _ -> -1
      | StartOf lv1, StartOf lv2 -> Lval.compare lv1 lv2

    let rec hash e =
      match e.node with
      | Const c -> Hashtbl.hash (1, Constant.hash c)
      | Lval lv -> Hashtbl.hash (2, Lval.hash lv)
      | SizeOf ty -> Hashtbl.hash (3, Cil_datatype.Typ.hash ty)
      | SizeOfE e -> Hashtbl.hash (4, hash e)
      | SizeOfStr s -> Hashtbl.hash (5, s)
      | AlignOf ty -> Hashtbl.hash (6, Cil_datatype.Typ.hash ty)
      | AlignOfE e -> Hashtbl.hash (7, hash e)
      | UnOp (op, e, ty) ->
        Hashtbl.hash (8, op, hash e, Cil_datatype.Typ.hash ty)
      | BinOp (op, e1, e2, ty) ->
        Hashtbl.hash (9, op, hash e1, hash e2, Cil_datatype.Typ.hash ty)
      | CastE (ty, e) -> Hashtbl.hash (10, Cil_datatype.Typ.hash ty, hash e)
      | AddrOf lv -> Hashtbl.hash (11, Lval.hash lv)
      | StartOf lv -> Hashtbl.hash (12, Lval.hash lv)
  end

  and Constant : S with type t = constant =
  struct
    type t = constant

    let compare c1 c2 =
      match c1, c2 with
      | CInt64 (v1,k1,s1), CInt64(v2,k2,s2) ->
        Integer.compare v1 v2 <?>
        lazy (Extlib.compare_basic k1 k2) <?>
        (* this last comparison is probably not useful ; maybe remove from AST *)
        lazy (Option.compare String.compare s1 s2)
      | CString b1, CString b2 -> Base.compare b1 b2
      | CChr c1, CChr c2 -> Char.compare c1 c2
      | CReal (f1, k1, s1), CReal (f2, k2, s2) ->
        Float.compare f1 f2 <?>
        lazy (Extlib.compare_basic k1 k2) <?>
        (* The string representation is used when option
           -eva-all-rounding-modes-constants is enabled *)
        lazy (Option.compare String.compare s1 s2)
      | CEnum e1, CEnum e2 -> Cil_datatype.Enumitem.compare e1 e2
      | (CInt64 _, (CString _ | CChr _ | CReal _ | CEnum _)) -> 1
      | (CString _, (CChr _ | CReal _ | CEnum _)) -> 1
      | (CChr _, (CReal _ | CEnum _)) -> 1
      | (CReal _, CEnum _) -> 1
      | (CString _ | CChr _ | CReal _ | CEnum _),
        (CInt64 _ | CString _ | CChr _ | CReal _) -> -1

    let hash c =
      match c with
      | CString _ | CChr _ -> Hashtbl.hash (1, c)
      | CReal (fn, fk, _) -> Hashtbl.hash (2, fn, fk)
      | CInt64 (n, k, _) -> Hashtbl.hash (3, n, k )
      | CEnum ei -> Hashtbl.hash (4, ei)
  end
end

module Lval =
  Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototypes.Lval

    let name = "Eva.Evast_datatype.Lval"
    let reprs = List.map (fun v -> Var v, NoOffset) Cil_datatype.Varinfo.reprs
    let pretty = Evast_printer.pp_lval
    let equal = Datatype.from_compare
  end)

module Lhost =
  Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototypes.Lhost

    let name = "Eva.Evast_datatype.Lhost"
    let reprs = List.map (fun v -> Var v) Cil_datatype.Varinfo.reprs
    let pretty fmt h = Evast_printer.pp_lval fmt (h, NoOffset)
    let equal = Datatype.from_compare
  end)

module Offset = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototypes.Offset

    let name = "Eva.Evast_datatype.Offset"
    let reprs = [NoOffset]
    let pretty = Evast_printer.pp_offset
    let equal = Datatype.from_compare
  end)

module Exp = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototypes.Exp

    let name = "Eva.Evast_datatype.Exp"
    let reprs =
      List.map (fun e -> Evast_builder.translate_exp e) Cil_datatype.Exp.reprs
    let pretty = Evast_printer.pp_exp
    let equal = Datatype.from_compare
  end)

module Constant = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    include Prototypes.Constant

    let name = "Eva.Evast_datatype.Constant"
    let reprs = [ CInt64(Integer.zero, IInt, Some "0") ]
    let pretty = Evast_printer.pp_constant
    let equal = Datatype.from_compare
  end)
