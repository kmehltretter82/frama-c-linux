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

open Cil_types
open Cil_datatype

open Spec
open Memory
open Ldomain

(* -------------------------------------------------------------------------- *)
(* ---  Process ACSL region annotations                                   --- *)
(* -------------------------------------------------------------------------- *)

let rec add_path (m:map) (p:path): node =
  match p.step with
  | Var x -> add_cvar m x
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

let add_region (m: map) (r : Spec.region) =
  let rs = List.map (add_path m) r.rpath in
  merge_all m @@
  match r.rname with
  | None -> rs
  | Some a -> add_label m a :: rs

(* -------------------------------------------------------------------------- *)
(* ---  Process ACSL logic terms & predicates                             --- *)
(* -------------------------------------------------------------------------- *)

type result = node option

type env = {
  map : map ;
  result : result ;
  formal : domain Varinfo.Map.t ;
  property : Property.t ;
}

let merge env a b = Memory.merge env.map a b ; min a b

let pointer (env:env) (d:domain) : node =
  match Ldomain.pointed (merge env) d with
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

let rec load env lv (ty:typ) r : domain =
  match Ast_types.unroll_node ty with
  | TArray(te,_) ->
    let r' = Memory.add_index env.map r ty in
    let ofs = TIndex (Logic_const.trange (None,None), TNoOffset) in
    let lv = Logic_const.addTermOffsetLval ofs lv in
    array (load env lv te r')
  | TComp { cfields } ->
    let add_field d fd =
      let ofs = TField (fd,TNoOffset) in
      let lv = Logic_const.addTermOffsetLval ofs lv in
      merge_domain env.map d
      @@ Ldomain.field fd
      @@ load env lv fd.ftype
      @@ Memory.add_field env.map r fd
    in List.fold_left add_field pure @@ Option.value ~default:[] cfields
  | _ ->
    let acs = Access.Term (env.property, lv) in
    Memory.add_read env.map r acs ;
    Ldomain.scalar @@ Memory.add_value env.map r ty

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
    term_offset env (Ldomain.get_field (merge env) d f) offset
  | TIndex(k,offset) ->
    ignore @@ !rterm env k ;
    term_offset env (Ldomain.get_index (merge env) d) offset

let get_result env = match env.result with
  | None -> Memory.add_result env.map
  | Some r -> r

let add_term_lval (env:env) lv =
  let (lhost,loffset) = lv in
  match lhost with
  | TResult ty ->
    load env lv ty @@ addr_offset env ty (get_result env) loffset
  | TMem e ->
    let rh = pointer env (!rterm env e) in
    let te = Logic_typing.ctype_of_pointed e.term_type in
    load env lv te @@ addr_offset env te rh loffset
  | TVar v ->
    begin match logic_var env v with
      | VAL d -> term_offset env d loffset
      | VAR x ->
        let rh = Memory.add_cvar env.map x in
        load env lv x.vtype @@ addr_offset env x.vtype rh loffset
    end

let add_addr_lval (env:env) (lhost,loffset) : node =
  match lhost with
  | TResult ty -> addr_offset env ty (get_result env) loffset
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
        addr_offset env x.vtype (Memory.add_cvar env.map x) loffset
    end

let rec add_loffset (env:env) loffest d = match loffest with
  | TNoOffset -> d
  | TField(fd,offset) -> Ldomain.field fd @@ add_loffset env offset d
  | TModel _ -> Options.abort "Region.Logic.add_loffset: TModel not implemented"
  | TIndex(_,offset) -> Ldomain.array @@ add_loffset env offset d

let call (env:env) (l:logic_info) (ds:domain list) : domain =
  let sigma = ref Ldomain.empty in
  let unify = Ldomain.unify (merge env) sigma in
  List.iter2 (fun x -> unify (Memory.add_logic_var env.map x)) l.l_profile ds ;
  Ldomain.subst !sigma @@ Memory.add_logic_info env.map l

let iadd_logic_var m v = ignore @@ add_logic_var m v

let rec add_term (env:env) (t:term) : domain = match t.term_node with
  | TConst _  | TSizeOf _ | TSizeOfE _ | TSizeOfStr _ | TAlignOf _ | TAlignOfE _
  | Tnull | Tempty_set | Ttypeof _ | Ttype _  | Trange _ -> pure
  | TLval lval -> add_term_lval env lval
  | TAddrOf lval | TStartOf lval -> ptr @@ add_addr_lval env lval
  | Tif (b,ct, cf) ->
    iadd_term env b ;
    let dt = add_term env ct in
    let df = add_term env cf in
    merge_domain env.map dt df
  | TUnOp(_,t) | TCast(_,_,t) | Tat(t,_) -> add_term env t
  | TBinOp ((PlusPI|MinusPI),t1,t2) ->
    let d1 = add_term env t1 in
    let d2 = add_term env t2 in
    merge_domain env.map d1 d2
  | TBinOp(_,t1,t2) -> iadd_term env t1 ; iadd_term env t2 ; pure
  | Tbase_addr(_,t) | Toffset (_,t) | Tblock_length(_,t) ->
    iadd_term env t ; pure
  | TUpdate(lv,o,v) ->
    merge_domain env.map (add_term env lv) @@ add_loffset env o @@ add_term env v
  | Tunion ts | Tinter ts ->
    List.fold_left (fun d t -> merge_domain env.map d @@ add_term env t) pure ts
  | Tcomprehension(t,q,p) ->
    Option.iter (add_predicate env) p ;
    List.iter (iadd_logic_var env.map) q ;
    add_term env t
  | Tapp(f,_,ts) -> call env f @@ List.map (add_term env) ts
  | Tlambda(q,t) ->
    Ldomain.arrow (List.map (Memory.add_logic_var env.map) q) @@ add_term env t
  | Tlet({ l_body ; l_var_info=v },b) ->
    begin match l_body with
      | LBterm a ->
        let dv = add_logic_var env.map v in
        let da = add_term env a in
        let sigma = ref Ldomain.empty in
        Ldomain.unify (merge env) sigma da dv ;
        Ldomain.subst !sigma @@ add_term env b
      | LBpred p ->
        iadd_logic_var env.map v ;
        add_predicate env p ;
        add_term env t
      | _ ->  Options.abort "Logic.add_term: Tlet without term nor predicate"
    end
  | TDataCons(c,ts) ->
    let ds = List.map (add_term env) ts in
    let args = List.map (of_ltype (new_chunk env.map)) c.ctor_params in
    let sigma = ref Ldomain.empty in
    List.iter2 (unify (merge env) sigma) ds args ;
    match c.ctor_type.lt_def with
    | Some (LTsyn lt) -> of_ltype (new_chunk env.map) lt
    | None | Some (LTsum _) -> pure

and iadd_term env t = ignore @@ add_term env t

and add_predicate (env:env) (p:predicate) = match p.pred_content with
  | Pfalse | Ptrue -> ()
  | Pseparated ts -> List.iter (iadd_term env) ts
  | Prel(_,t1,t2) | Pfresh(_,_,t1,t2) -> iadd_term env t1 ; iadd_term env t2
  | Pand(p1,p2) | Por(p1,p2) | Pxor(p1,p2) | Piff(p1,p2) | Pimplies(p1,p2) ->
    add_predicate env p1 ;
    add_predicate env p2 ;
  | Pnot p | Pat(p,_) -> add_predicate env p
  | Pif(c,pt,pf) ->
    iadd_term env c ;
    add_predicate env pt ;
    add_predicate env pf ;
  | Pobject_pointer(_,t) | Pvalid(_,t) | Pvalid_read(_,t)
  | Pvalid_function t | Pinitialized(_,t) | Pdangling(_,t)
  | Pallocable(_,t) | Pfreeable(_,t) -> iadd_term env t
  | Pforall (q,p) | Pexists (q,p) ->
    List.iter (iadd_logic_var env.map) q ; add_predicate env p
  | Plet({ l_var_info = v ; l_body = LBterm t ; },p2) ->
    let dv = add_logic_var env.map v in
    let dt = add_term env t in
    let sigma = ref empty in
    Ldomain.unify (merge env) sigma dt dv ;
    add_predicate env p2
  | Plet({ l_var_info = v ; l_body = LBpred p1 ; },p2) ->
    iadd_logic_var env.map v ;
    add_predicate env p1 ;
    add_predicate env p2
  | Plet({ l_body = LBnone ; },p2) ->
    add_predicate env p2
  | Plet _ ->
    Options.abort "Logic.add_predicate: (%a) not yet implemented"
      Printer.pp_predicate p
  | Papp(f,_,ts) -> ignore @@ call env f @@ List.map (add_term env) ts

let () = rterm := add_term

(* -------------------------------------------------------------------------- *)
(* ---  Process ACSL logic                                                --- *)
(* -------------------------------------------------------------------------- *)

let add_logic_info_body (env:env) (l:logic_info) : domain = match l.l_body with
  | LBnone -> pure
  | LBpred p -> add_predicate env p ; pure
  | LBterm t -> add_term env t
  | LBreads ts -> List.iter (fun t -> iadd_term env t.it_content) ts ; pure
  | LBinductive _ ->
    Options.abort "Logic.add_logic_info: inductive not implemented yet"
