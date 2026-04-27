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
module Fmap = Cil_datatype.Fieldinfo.Map

type env = {
  map : map ;
  result : node option ; (* where returned value is stored *)
  formals : domain Vmap.t ;
  context : Access.clause ;
}

let local map ip =
  { map ; result = None ; formals = Vmap.empty ; context = Access.Prop ip }

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

let rec load env (ty,r) : domain =
  match Ast_types.unroll_node ty with
  | TArray(te,_) ->
    let re = Memory.add_index r te in
    Domain.array (load env (te,re))
  | TComp { cfields } ->
    Domain.record @@
    List.fold_left
      (fun fds fd -> Fmap.add fd (load env (fd.ftype, Memory.field r fd)) fds)
      Fmap.empty @@ Option.value ~default:[] cfields
  | _ ->
    Domain.scalar @@ Memory.points_to r

let logic_call map (l:logic_info) (ds:domain list) : domain =
  let sigma = ref Domain.empty in
  let unify = Domain.unify any sigma in
  List.iter2 (fun x -> unify (Memory.lvar map x)) l.l_profile ds ;
  Domain.subst !sigma @@ Memory.logic map l

let logic_ctor (c:logic_ctor_info) (ds:domain list) : domain =
  (* we need a local unification for polymorphic variables *)
  let sigma = ref Domain.empty in
  let pany = Option.merge any in
  let pfrom = Domain.map (fun r -> Some r) in
  let unify = Domain.unify pany sigma in
  let fresh () = None in
  List.iter2 (fun t d -> unify (Domain.of_ltype fresh t) (pfrom d)) c.ctor_params ds ;
  let rec resolve = function
    | Domain.Pure | Ptr None -> Domain.pure
    | Dvar x -> resolve (Domain.getvar ~default:Domain.pure !sigma x)
    | Ptr (Some r) -> Domain.ptr r
    | Array a -> Domain.array @@ resolve a
    | Record m -> Domain.record @@ Fmap.map resolve m
    | Logic(t,ds) -> Domain.logic t @@ List.map resolve ds
    | Arrow(ds,d) -> Domain.arrow (List.map resolve ds) (resolve d)
  in Domain.logic c.ctor_type @@
  List.map (fun a -> resolve (Domain.getvar !sigma a)) c.ctor_type.lt_params

let rec dispatch_lval env lv : (typ * node,domain) Either.t =
  let lhost, loffset = lv in
  match lhost with
  | TMem e ->
    let rh = Option.get @@ Memory.dpointed @@ term env e in
    let te = Logic_typing.ctype_of_pointed e.term_type in
    Either.Left (addr_offset env rh te loffset)
  | TResult ty ->
    begin match env.result with
      | None -> Options.fatal "\\result undefined"
      | Some r -> Either.Left (addr_offset env r ty loffset)
    end
  | TVar v ->
    let left x =
      let r = Memory.cvar env.map x in
      addr_offset env r x.vtype loffset in
    let right d = term_offset env d loffset in
    Either.map ~left ~right @@ lvar env v

and tval env lv : (node,domain) Either.t =
  Either.map_left snd @@ dispatch_lval env lv

and term_lval env lv : domain =
  Either.fold ~left:(load env) ~right:Fun.id @@ dispatch_lval env lv

and addr_lval env lv : node =
  match dispatch_lval env lv with
  | Left (_,r) -> r
  | Right _ ->
    Options.fatal "address of logic value (%a)" Printer.pp_term_lval lv

and addr_offset env r ty = function
  | TNoOffset -> ty,r
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

and term env (t : term) : domain =
  match t.term_node with
  | TLval lval -> term_lval env lval
  | TAddrOf lval | TStartOf lval -> Domain.ptr @@ addr_lval env lval
  | Tif(_,ct,cf) -> Memory.dmerge (term env ct) (term env cf)
  | TBinOp((PlusPI|MinusPI),p,_) | Tat(p,_) | TCast(_,_,p) -> term env p
  | TBinOp(_,_,_) | TUnOp _ | Tbase_addr _ | Toffset _ | Tblock_length _
    -> Domain.pure
  | TUpdate(r,_,_) -> term env r
  | Tunion ts | Tinter ts ->
    List.fold_left (fun w t -> Memory.dmerge w (term env t)) Domain.pure ts
  | Tcomprehension(t,_,_) -> term env t
  | Tapp(f,_,ts) -> logic_call env.map f @@ List.map (term env) ts
  | TDataCons(c,ts) -> logic_ctor c @@ List.map (term env) ts
  | Tlambda(q,t) ->
    Domain.arrow (List.map (Memory.lvar env.map) q) @@ term env t
  | Tlet({ l_body ; l_var_info=v },b) ->
    begin match l_body with
      | LBterm a ->
        let dv = Memory.lvar env.map v in
        let da = term env a in
        let sigma = ref Domain.empty in
        Domain.unify any sigma da dv ;
        Domain.subst !sigma @@ term env b
      | LBpred _ -> Domain.pure
      | _ ->
        Options.not_yet_implemented
          ~source:(fst t.term_loc) "Unsupported complex \\let"
    end
  | TConst _  | TSizeOf _ | TSizeOfE _ | TAlignOf _ | TAlignOfE _
  | Tnull | Tempty_set | Ttypeof _ | Ttype _  | Trange _ -> pure

(* -------------------------------------------------------------------------- *)
