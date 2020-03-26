(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Basic_blocks
open Cil_types
open Logic_const

type kind = CPtr | Ptr | Len | Int
type action = Strip | Id
type param = string * kind * action
type proto = kind * param list
type 'a spec_gen = location -> typ -> term -> term -> term -> 'a

let unexpected = Options.fatal "Mem_utils: %s"

let mem2s_typing _ = function
  | [ dest ; src ; len ] ->
    (Cil.isIntegralType len) &&
    (Cil_datatype.Typ.equal dest src) &&
    (not (Cil.isVoidType dest)) &&
    (Cil.isCompleteType dest)
  | _ -> false

let mem2s_spec ~requires ~assigns ~ensures _t { svar = vi } loc =
  let (cdest, csrc, clen) = match Cil.getFormalsDecl vi with
    | [ dest ; src ; len ] -> dest, src, len
    | _ -> unexpected "ill-formed fundec in specification generation"
  in
  let t = cdest.vtype in
  let dest = cvar_to_tvar cdest in
  let src = cvar_to_tvar csrc in
  let len = cvar_to_tvar clen in
  let requires = requires loc t dest src len in
  let assigns  = assigns loc t dest src len in
  let ensures  = ensures loc t dest src len in
  make_funspec [make_behavior ~requires ~assigns ~ensures ()] ()

let pcopied_len_bytes ?loc p1 p2 bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len
    (punfold_all_elems_eq ?loc p1 p2)

let memcpy_memmove_common_requires loc _ dest src len =
  List.map new_predicate [
    { (pcorrect_len_bytes ~loc dest.term_type len)
      with pred_name = ["aligned_end"] } ;
    { (pvalid_len_bytes ~loc here_label dest len)
      with pred_name = ["valid_dest"] } ;
    { (pvalid_read_len_bytes ~loc here_label src len)
      with pred_name = ["valid_read_src"] } ;
  ]

let memcpy_memmove_common_assigns loc t dest src len =
  let dest_range = new_identified_term (tunref_range_bytes_len ~loc dest len) in
  let src_range = new_identified_term(tunref_range_bytes_len ~loc src len) in
  let copy = dest_range, From [src_range] in
  let result = new_identified_term (tresult t) in
  let dest = new_identified_term dest in
  let res = result, From [dest] in
  Writes [ copy ; res ]

let presult_dest ?loc t dest =
  prel ?loc (Req, (tresult ?loc t), dest)

let memcpy_memmove_common_ensures name loc t dest src len =
  List.map (fun p -> Normal, new_predicate p) [
    { (pcopied_len_bytes ~loc dest src len) with pred_name = [name] } ;
    { (presult_dest ~loc t dest)           with pred_name = ["result"] }
  ]

module type Function = sig
  val name: string
  val prototype: proto
  val well_typed: typ option -> typ list -> bool
end

module Make (F: Function) =
struct
  let generate_function_type t =
    let to_type = function
      | CPtr -> ptr_of (const_of t)
      | Ptr ->  ptr_of t
      | Len ->  size_t()
      | Int ->  Cil.intType
    in
    let ret, ps = F.prototype in
    let ret = to_type ret in
    let ps = List.map (fun (name, kind, _) -> name, (to_type kind), []) ps in
    TFun(ret, Some ps, false, [])

  let generate_prototype t =
    let ftype = generate_function_type t in
    let name = F.name ^ "_" ^ (string_of_typ t) in
    name, ftype

  let well_typed_call lval args =
    let _, ps = F.prototype in
    if List.length args <> List.length ps then false
    else
      let extract e = function
        | _, (CPtr | Ptr), _ -> exp_type_of_pointed e
        | _, (Len | Int), _ -> Some (Cil.typeOf e)
      in
      let lvt = Extlib.opt_map Cil.typeOfLval lval in
      let pts = List.map2 extract args ps in
      let is_none = function None -> true | _ -> false in
      if List.exists is_none pts then false
      else F.well_typed lvt (List.map (fun x -> Extlib.the x) pts)

  let retype_args _ args =
    let _, ps = F.prototype in
    if List.length args <> List.length ps then
      unexpected "trying to retype arguments on an ill-typed call"
    else
      let retype x = function
        | _, _, Strip -> Cil.stripCasts x
        | _, _, Id -> x
      in
      List.map2 retype args ps

  let key_from_call _ret args =
    let _, ps = F.prototype in
    match ps, args with
    | (_, (Ptr|CPtr), _)::ps, fst::args when List.(length ps = length args) ->
      begin match exp_type_of_pointed fst with
        | Some t -> t
        | None ->
          unexpected "Mem_utils: trying to get key on an ill-typed call"
      end
    | _ ->
      unexpected "Mem_utils: trying to get key on an ill-typed call"
end
