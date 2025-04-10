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

open Annot
open Memory

(* -------------------------------------------------------------------------- *)
(* ---  Process ACSL region annotations                                   --- *)
(* -------------------------------------------------------------------------- *)

let rec add_path (m:map) (p:path): node =
  match p.step with
  | Var x -> add_root m x
  | Field(lv,fd) -> Memory.add_field m (add_path m lv) fd
  | Index(lv,_) -> Memory.add_index m (add_path m lv) lv.typ
  | Star e | Cast(_,e) -> add_pointer m e
  | Shift _ | AddrOf _ ->
    Options.error ~source:(fst p.loc)
      "Unexpected expression (l-value expected)" ;
    Memory.new_chunk m ()
and add_pointer  (m:map) (p:path): Memory.node =
  match add_exp m p with
  | None -> Memory.new_chunk m ()
  | Some r -> r

and add_exp (m:map) (p:path): Memory.node option =
  match p.step with
  | (Var _ | Field _ | Index _ | Star _ | Cast _) ->
    let r = add_path m p in
    add_value m r p.typ
  | AddrOf p -> Some (add_path m p)
  | Shift p -> add_exp m p

let add_region (m: map) (r : Annot.region) =
  let rs = List.map (add_path m) r.rpath in
  merge_all m @@
  match r.rname with
  | None -> rs
  | Some a -> add_label m a :: rs

(* -------------------------------------------------------------------------- *)
(* ---  Process ACSL logic                                                --- *)
(* -------------------------------------------------------------------------- *)

open LDomain
open Cil_types
open Cil_datatype


type env = {
  map : map ;
  result : domain ;
  formal : domain Varinfo.Map.t ;
  property : Property.t ;
}

let merge env a b = Memory.merge env.map a b ; min a b

let pointer (env:env) (d:domain) : node =
  match LDomain.pointed (merge env) d with
  | Some p -> p
  | None -> Options.abort "Not a pointer value"

type lv_value =
  | VAL of domain
  | VAR of varinfo

let logic_var env lv =
  match lv.lv_origin with
  | None -> VAL (Memory.add_logic_var env.map lv)
  | Some x ->
    if x.vformal then
      try VAL (Varinfo.Map.find x env.formal) with Not_found -> VAR x
    else VAR x

let rec load env acs (ty:typ) r : domain =
  match ty.tnode with
  | TVoid | TInt _ | TFloat _ | TEnum _ | TBuiltin_va_list | TPtr _ | TFun _ ->
    Memory.add_read env.map r acs ;
    LDomain.scalar @@ Memory.add_value env.map r ty
  | TArray(te,_) ->
    let r' = Memory.add_index env.map r ty in
    array (load env acs te r')
  | TNamed _ -> Options.abort "logic.load: TNamed not implemented"
  | TComp { cfields } ->
    let add_field d fd =
      merge_domain env.map d
      @@ LDomain.field fd
      @@ load env acs fd.ftype
      @@ Memory.add_field env.map r fd
    in List.fold_left add_field pure @@ Option.value ~default:[] cfields

let rterm = ref (fun _ _ -> assert false)

let rec addr_offset (env:env) (ty:typ) (r:node) = function
  | TNoOffset -> r
  | TModel _ -> Options.not_yet_implemented "Model field"
  | TField (f,offset) ->
    addr_offset env f.ftype (Memory.add_field env.map r f) offset
  | TIndex(k,offset) ->
    ignore @@ !rterm env k ;
    let te = Ast_types.direct_element_type ty in
    addr_offset env te (Memory.add_index env.map r ty) offset

let rec term_offset (env:env) (d:domain) = function
  | TNoOffset -> d
  | TModel _ -> Options.not_yet_implemented "Model field"
  | TField (f,offset) ->
    term_offset env (LDomain.get_field (merge env) d f) offset
  | TIndex(k,offset) ->
    ignore @@ !rterm env k ;
    term_offset env (LDomain.get_index (merge env) d) offset

let add_term_lval (env:env) lv =
  let acs = Access.Term (env.property, lv) in
  let (lhost,loffset) = lv in
  match lhost with
  | TResult _ -> term_offset env env.result loffset
  | TMem e ->
    let rh = pointer env (!rterm env e) in
    let te = Logic_typing.ctype_of_pointed e.term_type in
    load env acs te @@ addr_offset env te rh loffset
  | TVar lv ->
    begin match logic_var env lv with
      | VAL d -> term_offset env d loffset
      | VAR x ->
        let rh = Memory.add_root env.map x in
        load env acs x.vtype @@ addr_offset env x.vtype rh loffset
    end

let add_addr_lval (env:env) (lhost,loffset) : node =
  match lhost with
  | TResult tr -> addr_offset env tr (pointer env env.result) loffset
  | TMem e ->
    let rh = pointer env (!rterm env e) in
    let te = Logic_typing.ctype_of_pointed e.term_type in
    addr_offset env te rh loffset
  | TVar lv ->
    begin match logic_var env lv with
      | VAL d ->
        let te = Logic_utils.logicCType lv.lv_type in
        addr_offset env te (pointer env d) loffset
      | VAR x ->
        addr_offset env x.vtype (Memory.add_root env.map x) loffset
    end


let add_term (env:env) (t:term) : domain = match t.term_node with
  | TConst _  | TSizeOf _ | TSizeOfE _ | TSizeOfStr _ | TAlignOf _ | TAlignOfE _
    -> pure
  | TLval lval -> add_term_lval env lval
  | TAddrOf lval | TStartOf lval -> ptr @@ add_addr_lval env lval
  | _ -> assert false

let () = rterm := add_term
