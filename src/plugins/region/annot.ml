(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Logic_ptree
open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* ---  Region Specifications                                             --- *)
(* -------------------------------------------------------------------------- *)

type lpath = {
  loc : location ;
  ltype : typ ;
  lnode : lnode ;
}

and lnode =
  | L_var of varinfo
  | L_region of string
  | L_addr of lpath
  | L_star of lpath
  | L_index of lpath
  | L_shift of lpath
  | L_field of lpath * fieldinfo
  | L_cast of typ * lpath

type region = {
  rname: string option ;
  rpath: lpath list ;
}

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

let atomic = function
  | L_var _ | L_region _ | L_addr _ | L_star _ | L_index _ | L_field _ -> true
  | L_shift _ | L_cast _ -> false

let rec pp_lnode fmt = function
  | L_var x -> Varinfo.pretty fmt x
  | L_region a -> Format.pp_print_string fmt a
  | L_field(p,f) -> pfield p f fmt
  | L_index a -> Format.fprintf fmt "%a[..]" pp_latom a
  | L_shift a -> Format.fprintf fmt "%a+(..)" pp_latom a
  | L_star a -> Format.fprintf fmt "*%a" pp_latom a
  | L_addr a -> Format.fprintf fmt "&%a" pp_latom a
  | L_cast(t,a) -> Format.fprintf fmt "(%a)@,%a" Typ.pretty t pp_latom a

and pfield p fd fmt =
  match p.lnode with
  | L_star p -> Format.fprintf fmt "%a->%a" pp_latom p Fieldinfo.pretty fd
  | _ -> Format.fprintf fmt "%a.%a" pp_latom p Fieldinfo.pretty fd

and pp_latom fmt a =
  if atomic a.lnode then pp_lnode fmt a.lnode
  else Format.fprintf fmt "@[<hov 2>(%a)@]" pp_lnode a.lnode

and pp_lpath fmt a = pp_lnode fmt a.lnode

let pp_named fmt = function None -> () | Some a -> Format.fprintf fmt "%s: " a

let pp_region fmt r =
  match r.rpath with
  | [] -> Format.pp_print_string fmt "\null"
  | p::ps ->
    begin
      Format.fprintf fmt "@[<hov 2>]" ;
      pp_named fmt r.rname ;
      pp_lpath fmt p ;
      List.iter (Format.fprintf fmt ",@ %a" pp_lpath) ps ;
      Format.fprintf fmt "@]" ;
    end

let pp_regions fmt = function
  | [] -> Format.pp_print_string fmt "\null"
  | r::rs ->
    begin
      Format.fprintf fmt "@[<hv 0>]" ;
      pp_region fmt r ;
      List.iter (Format.fprintf fmt ",@ %a" pp_region) rs ;
      Format.fprintf fmt "@]" ;
    end

(* -------------------------------------------------------------------------- *)
(* ---  Parsers                                                           --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  context: Logic_typing.typing_context ;
  mutable named: string option ;
  mutable paths: lpath list ;
  mutable specs: region list ;
}

let error (env:env) ~loc msg = env.context.error loc msg

let getCompoundType env ~loc typ =
  match Cil.unrollType typ with
  | TComp(comp,_) -> comp
  | _ -> error env ~loc "Expected compound type for term"

let parse_name (env:env) ~loc x =
  try
    match env.context.find_var x with
    | { lv_origin = Some v } -> { loc ; ltype = v.vtype ; lnode = L_var v }
    | _ -> error env ~loc "Variable '%s' is not a C-variable" x
  with Not_found -> { loc ; ltype = TVoid [] ; lnode = L_region x }

let parse_field env ~loc comp f =
  try List.find (fun fd -> fd.fname = f) (Option.value ~default:[] comp.cfields)
  with Not_found ->
    error env ~loc "No field '%s' in compound type '%s'" f comp.cname

let parse_lrange (env: env) (e : lexpr) =
  match e.lexpr_node with
  | PLrange(None,None) -> ()
  | _ ->
    error env ~loc:e.lexpr_loc "Unexpected index (use unspecified range only)"

let parse_ltype env ~loc t =
  let open Logic_typing in
  let g = env.context in
  let t = g.logic_type g loc g.pre_state t in
  match Logic_utils.unroll_type t with
  | Ctype typ -> typ
  | _ -> error env ~loc "C-type expected for casting l-values"

let rec parse_lpath (env:env) (e: lexpr) =
  let loc = e.lexpr_loc in
  match e.lexpr_node with
  | PLvar x -> parse_name env ~loc x
  | PLunop( Ustar , p ) ->
    let lv = parse_lpath env p in
    if Cil.isPointerType lv.ltype then
      let te = Cil.typeOf_pointed lv.ltype in
      { loc ; lnode = L_star lv ; ltype = te }
    else
      error env ~loc "Pointer-type expected for operator '&'"
  | PLunop( Uamp , p ) ->
    let lv = parse_lpath env p in
    let ltype = TPtr( lv.ltype , [] ) in
    { loc ; lnode = L_addr lv ; ltype }
  | PLbinop( p , Badd , rg ) ->
    parse_lrange env rg ;
    let { ltype } as lv = parse_lpath env p in
    if Cil.isPointerType ltype then
      { loc ; lnode = L_shift lv ; ltype = ltype }
    else
    if Cil.isArrayType ltype then
      let te = Cil.typeOf_array_elem ltype in
      { loc ; lnode = L_shift lv ; ltype = TPtr(te,[]) }
    else
      error env ~loc "Pointer-type expected for operator '+'"
  | PLdot( p , f ) ->
    let lv = parse_lpath env p in
    let comp = getCompoundType env ~loc:lv.loc lv.ltype in
    let fd = parse_field env ~loc comp f in
    { loc ; lnode = L_field(lv,fd) ; ltype = fd.ftype }
  | PLarrow( p , f ) ->
    let sp = { lexpr_loc = loc ; lexpr_node = PLunop(Ustar,p) } in
    let pf = { lexpr_loc = loc ; lexpr_node = PLdot(sp,f) } in
    parse_lpath env pf
  | PLarrget( p , rg ) ->
    parse_lrange env rg ;
    let { ltype } as lv = parse_lpath env p in
    if Cil.isPointerType ltype then
      let pointed = Cil.typeOf_pointed ltype in
      let ls = { loc ; lnode = L_shift lv ; ltype } in
      { loc ; lnode = L_star ls ; ltype = pointed }
    else
    if Cil.isArrayType ltype then
      let elt = Cil.typeOf_array_elem ltype in
      { loc ; lnode = L_index lv ; ltype = elt }
    else
      error env ~loc:lv.loc "Pointer or array type expected"
  | PLcast( t , a ) ->
    let lv = parse_lpath env a in
    let ty = parse_ltype env ~loc t in
    { loc ; lnode = L_cast(ty,lv) ; ltype = ty }
  | _ ->
    error env ~loc "Unexpected expression for region spec"

let rec parse_named_lpath (env:env) p =
  match p.lexpr_node with
  | PLnamed( name , p ) ->
    if env.named <> None && env.paths <> [] then
      begin
        env.specs <- { rname = env.named ; rpath = env.paths } :: env.specs ;
        env.paths <- [] ;
      end ;
    env.named <- Some name ;
    parse_named_lpath env p
  | _ ->
    let path = parse_lpath env p in
    env.paths <- path :: env.paths

(* -------------------------------------------------------------------------- *)
(* --- Spec Typechecking & Printing                                       --- *)
(* -------------------------------------------------------------------------- *)

let kspec = ref 0
let registry = Hashtbl.create 0

let of_extid = Hashtbl.find registry
let of_extrev = function
  | { ext_name="region" ; ext_kind = Ext_id k } -> of_extid k
  | _ -> raise Not_found
let of_extension e = List.rev (of_extrev e)
let of_behavior bhv =
  List.fold_left
    (fun acc e -> List.rev_append (try of_extrev e with Not_found -> []) acc)
    [] bhv.Cil_types.b_extended

let typecheck typing_context _loc ps =
  let env = {
    named = None ;
    context = typing_context ;
    paths = [] ; specs = [] ;
  } in
  List.iter (parse_named_lpath env) ps ;
  let id = !kspec in incr kspec ;
  let specs = { rname = env.named ; rpath = env.paths } :: env.specs in
  Hashtbl.add registry id @@ List.rev specs ;
  Ext_id id

let printer _pp fmt = function
  | Ext_id k ->
    let rs  = try Hashtbl.find registry k with Not_found -> [] in
    pp_regions fmt rs
  | _ -> ()

let () =
  Acsl_extension.register_behavior
    ~plugin:"region" "alias" typecheck ~printer false

(* -------------------------------------------------------------------------- *)
