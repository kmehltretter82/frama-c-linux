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

type path = {
  loc : location ;
  typ : typ ;
  step: step ;
}

and step =
  | Var of varinfo
  | AddrOf of path
  | Star of path
  | Shift of path
  | Index of path * int
  | Field of path * fieldinfo
  | Cast of typ * path

type region = {
  rname: string option ;
  rpath: path list ;
}

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

let atomic = function
  | Var _ | AddrOf _ | Star _ | Index _ | Field _ -> true
  | Shift _ | Cast _ -> false

let rec pp_step fmt = function
  | Var x -> Varinfo.pretty fmt x
  | Field(p,f) -> pfield p f fmt
  | Index(a,n) -> Format.fprintf fmt "%a[%d]" pp_atom a n
  | Shift a -> Format.fprintf fmt "%a+(..)" pp_atom a
  | Star a -> Format.fprintf fmt "*%a" pp_atom a
  | AddrOf a -> Format.fprintf fmt "&%a" pp_atom a
  | Cast(t,a) -> Format.fprintf fmt "(%a)@,%a" Typ.pretty t pp_atom a

and pfield p fd fmt =
  match p.step with
  | Star p -> Format.fprintf fmt "%a->%a" pp_atom p Fieldinfo.pretty fd
  | _ -> Format.fprintf fmt "%a.%a" pp_atom p Fieldinfo.pretty fd

and pp_atom fmt a =
  if atomic a.step then pp_step fmt a.step
  else Format.fprintf fmt "@[<hov 2>(%a)@]" pp_step a.step

and pp_path fmt a = pp_step fmt a.step

let pp_named fmt = function None -> () | Some a -> Format.fprintf fmt "%s: " a

let pp_region fmt r =
  match r.rpath with
  | [] -> Format.pp_print_string fmt "\null"
  | p::ps ->
    begin
      Format.fprintf fmt "@[<hov 2>" ;
      pp_named fmt r.rname ;
      pp_path fmt p ;
      List.iter (Format.fprintf fmt ",@ %a" pp_path) ps ;
      Format.fprintf fmt "@]" ;
    end

let pp_regions fmt = function
  | [] -> Format.pp_print_string fmt "\null"
  | r::rs ->
    begin
      Format.fprintf fmt "@[<hv 0>" ;
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
  mutable paths: path list ;
  mutable specs: region list ;
}

let error (env:env) ~loc msg = env.context.error loc msg

let parse_variable (env:env) ~loc x =
  match env.context.find_var x with
  | { lv_origin = Some v } -> { loc ; typ = v.vtype ; step = Var v }
  | _ -> error env ~loc "Variable '%s' is not a C-variable" x

let parse_field env ~loc comp f =
  try Cil.getCompField comp f with Not_found ->
    error env ~loc "No field '%s' in compound type '%s'" f comp.cname

let parse_compinfo env ~loc typ =
  try Cil.getCompType typ with Not_found ->
    error env ~loc "Expected compound type for term"

let parse_lrange (env: env) (e : lexpr) =
  match e.lexpr_node with
  | PLrange(None,None) -> ()
  | _ ->
    error env ~loc:e.lexpr_loc "Unexpected index (use unspecified range only)"

let parse_typ env ~loc t =
  let open Logic_typing in
  let g = env.context in
  let t = g.logic_type g loc g.pre_state t in
  match Logic_utils.unroll_type t with
  | Ctype typ -> typ
  | _ -> error env ~loc "C-type expected for casting l-values"

let rec parse_lpath (env:env) (e: lexpr) =
  let loc = e.lexpr_loc in
  match e.lexpr_node with
  | PLvar x -> parse_variable env ~loc x
  | PLunop( Ustar , p ) ->
    let lv = parse_lpath env p in
    if Cil.isPointerType lv.typ then
      let te = Cil.typeOf_pointed lv.typ in
      { loc ; step = Star lv ; typ = te }
    else
      error env ~loc "Pointer-type expected for operator '*'"
  | PLunop( Uamp , p ) ->
    let lv = parse_lpath env p in
    let typ = TPtr( lv.typ , [] ) in
    { loc ; step = AddrOf lv ; typ }
  | PLbinop( p , Badd , rg ) ->
    parse_lrange env rg ;
    let { typ } as lv = parse_lpath env p in
    if Cil.isPointerType typ then
      { loc ; step = Shift lv ; typ = typ }
    else
    if Cil.isArrayType typ then
      let te = Cil.typeOf_array_elem typ in
      { loc ; step = Shift lv ; typ = TPtr(te,[]) }
    else
      error env ~loc "Pointer-type expected for operator '+'"
  | PLdot( p , f ) ->
    let lv = parse_lpath env p in
    let comp = parse_compinfo env ~loc:lv.loc lv.typ in
    let fd = parse_field env ~loc comp f in
    { loc ; step = Field(lv,fd) ; typ = fd.ftype }
  | PLarrow( p , f ) ->
    let sp = { lexpr_loc = loc ; lexpr_node = PLunop(Ustar,p) } in
    let pf = { lexpr_loc = loc ; lexpr_node = PLdot(sp,f) } in
    parse_lpath env pf
  | PLarrget( p , rg ) ->
    parse_lrange env rg ;
    let { typ } as lv = parse_lpath env p in
    if Cil.isPointerType typ then
      let pointed = Cil.typeOf_pointed typ in
      let ls = { loc ; step = Shift lv ; typ } in
      { loc ; step = Star ls ; typ = pointed }
    else
    if Cil.isArrayType typ then
      let elt,size = Cil.typeOf_array_elem_size typ in
      { loc ; step = Index(lv,Z.to_int @@ Option.get size) ; typ = elt }
    else
      error env ~loc:lv.loc "Pointer or array type expected"
  | PLcast( t , a ) ->
    let lv = parse_lpath env a in
    let ty = parse_typ env ~loc t in
    { loc ; step = Cast(ty,lv) ; typ = ty }
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

let of_extid id = try Hashtbl.find registry id with Not_found -> []
let of_extension = function
  | { ext_name="region" ; ext_kind = Ext_id k } -> of_extid k
  | _ -> []
let of_code_annot = function
  | { annot_content = AExtended(_,_,e) } -> of_extension e
  | _ -> []

let of_behavior bhv = List.concat_map of_extension bhv.b_extended

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
  begin
    Acsl_extension.register_behavior
      ~plugin:"region" "region" typecheck ~printer false ;
    Acsl_extension.register_code_annot
      ~plugin:"region" "alias" typecheck ~printer false ;
  end


(* -------------------------------------------------------------------------- *)
