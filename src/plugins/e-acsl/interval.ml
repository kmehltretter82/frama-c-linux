(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2015                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* Implement Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince". *)

exception Not_an_integer

(* ********************************************************************* *)
(* Basic datatypes and operations *)
(* ********************************************************************* *)

type interv = { lower: Integer.t; upper: Integer.t }

include Datatype.Make
(struct
  type t = interv
  let name = "E_ACSL.Interval.t"
  let reprs = [ { lower = Integer.zero; upper = Integer.one } ]
  include Datatype.Undefined
  let pretty fmt i =
    let pp = Integer.pretty ~hexa:false in
    Format.fprintf fmt "[ %a; %a ]" pp i.lower pp i.upper
 end)

(* constructors *)

let make lower upper = { lower; upper }

let singleton_of_int n =
  let z = Integer.of_int n in
  make z z

let rec interv_of_typ ty = match Cil.unrollType ty with
  | TInt (k,_) as ty ->
    let n = Cil.bitsSizeOf ty in
    let l, u =
      if Cil.isSigned k then Cil.min_signed_number n, Cil.max_signed_number n
      else Integer.zero, Cil.max_unsigned_number n
    in
    make l u
  | TEnum(enuminfo, _) -> interv_of_typ (TInt (enuminfo.ekind, []))
  | _ ->
    raise Not_an_integer

let interv_of_unknown_block =
  (* since we have no idea of the size of this block, we take the largest
     possible one which is unfortunately quite large *)
  lazy
    (let u = Integer.div (Bit_utils.max_bit_address ()) Integer.eight in
     make Integer.zero u)

let add i n = { lower = Integer.add i.lower n; upper = Integer.add i.upper n }

(* intervals as a lattice *)

let meet i1 i2 =
  make (Integer.max i1.lower i2.lower) (Integer.min i1.upper i2.upper)

let join i1 i2 =
  make (Integer.min i1.lower i2.lower) (Integer.max i1.upper i2.upper)

(* imperative environments *)

module Env = struct
  open Cil_datatype
  let tbl: interv Logic_var.Hashtbl.t = Logic_var.Hashtbl.create 7
  let clear () = Logic_var.Hashtbl.clear tbl
  let add = Logic_var.Hashtbl.add tbl
  let find = Logic_var.Hashtbl.find tbl
end

(* ********************************************************************* *)
(* Main algorithm *)
(* ********************************************************************* *)

let combine op i1 i2 =
  (* probably not the most efficient way to compute the result, but the
     shortest and the simplest *)
   (* TODO: alternatively, we could use Value's domain for that purpose. The Cfp
      plug-in actually implements this solution. *)
  let ll = op i1.lower i2.lower in
  let lu = op i1.lower i2.upper in
  let ul = op i1.upper i2.lower in
  let uu = op i1.upper i2.upper in
  let lower = Integer.min ll (Integer.min lu (Integer.min ul uu)) in
  let upper = Integer.max ll (Integer.max lu (Integer.max ul uu)) in
  make lower upper

let infer_sizeof ty =
  try singleton_of_int (Cil.bytesSizeOf ty)
  with Cil.SizeOfError _ -> interv_of_typ Cil.theMachine.Cil.typeOfSizeOf

let infer_alignof ty = singleton_of_int (Cil.bytesAlignOf ty)

let rec infer t =
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  match t.term_node with
  | TConst (Integer (n,_)) -> make n n
  | TConst (LChr c) ->
    let n = Cil.charConstToInt c in
    make n n
  | TConst (LEnum enumitem) ->
    let rec find_idx n = function
      | [] -> assert false
      | ei :: l -> if ei == enumitem then n else find_idx (n + 1) l
    in
    let n = Integer.of_int (find_idx 0 enumitem.eihost.eitems) in
    make n n
  | TLval lv -> infer_term_lval lv
  | TSizeOf ty -> infer_sizeof ty
  | TSizeOfE t -> infer_sizeof (get_cty t)
  | TSizeOfStr str -> singleton_of_int (String.length str + 1 (* '\0' *))
  | TAlignOf ty -> infer_alignof ty
  | TAlignOfE t -> infer_alignof (get_cty t)

  | TUnOp (Neg, t) ->
    let { lower; upper } = infer t in
    make (Integer.neg upper) (Integer.neg lower)
  | TUnOp (BNot, t) ->
    let { lower; upper } = infer t in
    let nl = Integer.lognot lower in
    let nu = Integer.lognot upper in
    make (Integer.min nl nu) (Integer.max nl nu)
  | TUnOp (LNot, _)

  | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), _, _) ->
    make Integer.zero Integer.one
  | TBinOp (PlusA, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    make (Integer.add i1.lower i2.lower) (Integer.add i1.upper i2.upper)
  | TBinOp (MinusA, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    make (Integer.sub i1.lower i2.upper) (Integer.sub i1.upper i2.lower)
  | TBinOp (Mult, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    combine Integer.mul i1 i2
  | TBinOp (Div, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    if Integer.le i2.lower Integer.zero && Integer.ge i2.upper Integer.zero then
      (* 0 \in i2 *)
      let l = Integer.min i1.lower (Integer.neg i1.upper) in
      let u = Integer.max (Integer.neg i1.lower) i1.upper in
      make l u
    else
      (* O \not\in i2: i2 is either positive or negative *)
      let div a b =
        try Integer.c_div a b with Division_by_zero -> assert false
      in
      combine div i1 i2
  | TBinOp (Mod, t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    (* the sign of the result is the sign of [t1];
       also no more elements than [t2-1] and no more than [t1] *)
    let nb1 = Integer.max (Integer.abs i1.lower) (Integer.abs i1.upper) in
    let nb2 = Integer.max (Integer.abs i2.lower) (Integer.abs i2.upper) in
    (* nb = min (max |l1| |u1|) (max |l2| |u2| - 1) *)
    let nb = Integer.min nb1 (Integer.pred nb2) in
    let l =
      (* potential negative integers, or positive *)
      if Integer.le i1.lower Integer.zero then Integer.neg nb else Integer.zero
    in
    let u =
      (* negative, or potential positive integers *)
      if Integer.le i1.upper Integer.zero then Integer.zero else nb
    in
    make l u

  | TBinOp (Shiftlt ,_,_) -> Error.not_yet "left shift"
  | TBinOp (Shiftrt ,_,_) -> Error.not_yet "right shift"
  | TBinOp (BAnd ,_,_) -> Error.not_yet "bitwise and"
  | TBinOp (BXor ,_,_) -> Error.not_yet "bitwise xor"
  | TBinOp (BOr ,_,_) -> Error.not_yet "bitwise or"

  | TCastE (ty, t)
  | TCoerce (t, ty) ->
    let it = infer t in
    let ity = interv_of_typ ty in
    meet it ity
  | Tif (_, t2, t3) ->
    let i2 = infer t2 in
    let i3 = infer t3 in
    join i2 i3
  | Tat (t, _) -> infer t
  | TBinOp (MinusPP, t, _) ->
    (match Cil.unrollType (get_cty t) with
    | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
      (* the second argument must be in the same block than [t]. Consequently
         the result of the difference belongs to [0; \block_length(t)] *)
      let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
      make Integer.zero (Integer.of_int nb_bytes)
    | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block
    | _ -> assert false)
  | Tblock_length (_, t)
  | Toffset(_, t) ->
    (match Cil.unrollType (get_cty t) with
    | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
      let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
      singleton_of_int nb_bytes
    | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block
    | _ -> assert false)
  | Tnull  -> singleton_of_int 0
  | TLogic_coerce (_, t) -> infer t
  | TCoerceE (t1, t2) ->
    let i1 = infer t1 in
    let i2 = infer t2 in
    meet i1 i2

  | Tapp (li, _, _args) ->
    (match li.l_type with
    | None -> assert false (* [None] only possible for predicates *)
    | Some Linteger -> Error.not_yet "logic function returning an integer"
    | Some (Ctype ty) -> interv_of_typ ty
    | Some _ -> raise Not_an_integer)
  | Tunion _ -> Error.not_yet "tset union"
  | Tinter _ -> Error.not_yet "tset intersection"
  | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
  | Trange (_,_) -> Error.not_yet "trange"
  | Tlet (_,_) -> Error.not_yet "let binding"

  | TConst (LStr _ | LWStr _ | LReal _)
  | TBinOp (PlusPI,_,_)
  | TBinOp (IndexPI,_,_)
  | TBinOp (MinusPI,_,_)
  | TAddrOf _
  | TStartOf _
  | Tlambda (_,_)
  | TDataCons (_,_)
  | Tbase_addr (_,_)
  | TUpdate (_,_,_)
  | Ttypeof _
  | Ttype _
  | Tempty_set  -> raise Not_an_integer

and infer_term_lval (host, offset as tlv) =
  match offset with
  | TNoOffset -> infer_term_host host
  | _ ->
    let ty = Logic_utils.logicCType (Cil.typeOfTermLval tlv) in
    interv_of_typ ty

and infer_term_host = function
  | TVar v ->
    (try Env.find v
     with Not_found -> interv_of_typ (Logic_utils.logicCType v.lv_type))
  | TResult ty -> interv_of_typ ty
  | TMem t ->
    let ty = Logic_utils.logicCType t.term_type in
    match Cil.unrollType ty with
    | TPtr(ty, _) | TArray(ty, _, _, _) -> interv_of_typ ty
    | _ ->
      Options.fatal "unexpected type %a for term %a"
        Printer.pp_typ ty
        Printer.pp_term t

(*
Local Variables:
compile-command: "make"
End:
 *)
