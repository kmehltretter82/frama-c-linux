(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Memory

(* -------------------------------------------------------------------------- *)
(* ---  Expression Lookup                                                 --- *)
(* -------------------------------------------------------------------------- *)

let rec lval (m: map) (h,ofs) : node =
  offset (lhost m h) (Cil.typeOfLhost h) ofs

and lhost (m: map) (h: lhost) : node =
  match h with
  | Var x -> cvar m x
  | Mem e ->
    match exp m e with
    | Some r -> r
    | None -> raise Not_found

and offset (r: node) (ty: typ) (ofs: offset) : node =
  match ofs with
  | NoOffset -> r
  | Field (fd, ofs) ->
    offset (field r fd) fd.ftype ofs
  | Index (_, ofs) ->
    let te = Ast_types.direct_element_type ty in
    offset (index r te) te ofs

and exp (m: map) (e: exp) : node option =
  match e.enode with
  | Const _
  | SizeOf _ | SizeOfE _ | AlignOf _ | AlignOfE _ -> None
  | Lval lv -> points_to @@ lval m lv
  | AddrOf lv | StartOf lv -> Some (lval m lv)
  | CastE(_, e) -> exp m e
  | BinOp((PlusPI|MinusPI),p,_,_) -> exp m p
  | UnOp (_, _, _) | BinOp (_, _, _, _) -> None

(* -------------------------------------------------------------------------- *)
(* ---  Logic Environment                                                 --- *)
(* -------------------------------------------------------------------------- *)

module Vmap = Cil_datatype.Varinfo.Map

type env = {
  map : map ;
  result : node option ; (* where returned value is stored *)
  formals : domain Vmap.t ;
  context : Access.clause ;
}

let lvar env lv =
  match lv.lv_origin with
  | None -> Either.Right (Memory.add_lvar env.map lv)
  | Some x ->
    if x.vformal then
      try Either.Right (Vmap.find x env.formals)
      with Not_found -> Either.Left x
    else Either.Left x

(* -------------------------------------------------------------------------- *)
(* ---  Terms Lookup                                                      --- *)
(* -------------------------------------------------------------------------- *)

let rec term_lval (env : env) (lv : term_lval) : domain =
  let lhost, loffset = lv in
  match lhost with
  | TMem _ -> assert false
  | TResult ty ->
    begin match env.result with
      | None -> Options.fatal "\\result undefined"
      | Some r -> Domain.ptr @@ addr_offset env r ty loffset
    end
  | TVar v ->
    let left x =
      let r = Memory.cvar env.map x in
      Domain.ptr @@ addr_offset env r x.vtype loffset in
    let right d = term_offset env d loffset in
    Either.fold ~left ~right @@ lvar env v

and addr_offset env r ty = function
  | TNoOffset -> r
  | TModel _ -> Options.not_yet_implemented "Unsupported model fields"
  | TField(fd,offset) -> addr_offset env (field r fd) fd.ftype offset
  | TIndex(_,offset) ->
    let te = Ast_types.direct_element_type ty in
    addr_offset env (index r ty) te offset

and term_offset env d = function
  | TNoOffset -> d
  | TModel _ -> Options.not_yet_implemented "Unsupported model fields"
  | TIndex(_,offset) -> term_offset env (Memory.dindex d) offset
  | TField(fd,offset) -> term_offset env (Memory.dfield d fd) offset
[@@ warning "-32"]

let term _ _ = assert false

(* -------------------------------------------------------------------------- *)
