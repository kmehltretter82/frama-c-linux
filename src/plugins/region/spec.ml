(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Logic_ptree
open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* ---  Region Specifications                                             --- *)
(* -------------------------------------------------------------------------- *)

type path =
  | Alias of Fileloc.t * term_lval
  | Field of Fileloc.t * term_lval * fieldinfo * fieldinfo
  | Range of Fileloc.t * term * typ * term * term

type region = {
  named : string ;
  paths : path list ;
  flags : Attr.flags ;
}

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

let pp_named fmt a = if a <> "" then Format.fprintf fmt "%s: " a

let pp_path fmt = function
  | Alias(_,lv) ->
    Printer.pp_term_lval fmt lv
  | Field(_,lv,f,g) ->
    let field lv f = Logic_const.addTermOffsetLval (TField(f,TNoOffset)) lv in
    Format.fprintf fmt "%a..%a"
      Printer.pp_term_lval (field lv f)
      Printer.pp_term_lval (field lv g)
  | Range(_,p,_,a,b) ->
    Format.fprintf fmt "%a[%a..%a]"
      Printer.pp_term p
      Printer.pp_term a
      Printer.pp_term b

let pp_region fmt r =
  match r.paths with
  | [] -> Format.pp_print_string fmt ""
  | p::ps ->
    begin
      Format.fprintf fmt "@[<hov 2>" ;
      pp_named fmt r.named ; pp_path fmt p ;
      List.iter (Format.fprintf fmt ",@ %a" pp_path) ps ;
      Attr.iter (Format.fprintf fmt ",@ \\%a" Attr.pp_attr) r.flags ;
      Format.fprintf fmt "@]" ;
    end

let pp_regions fmt = function
  | [] -> Format.pp_print_string fmt ""
  | r::rs ->
    begin
      Format.fprintf fmt "@[<hv 0>" ;
      pp_region fmt r ;
      List.iter (Format.fprintf fmt ",@ %a" pp_region) rs ;
      Format.fprintf fmt "@]" ;
    end

(* -------------------------------------------------------------------------- *)
(* ---  Parsing Environment                                               --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  context: Logic_typing.typing_context ;
  mutable source: Filepos.t ;
  mutable named: string ;
  mutable flags: Attr.flags ;
  mutable rpaths: path list ;
  mutable regions: region list ;
}

let error (env:env) ~loc msg = env.context.error loc msg

(* -------------------------------------------------------------------------- *)
(* ---  Syntactic Filter                                                  --- *)
(* -------------------------------------------------------------------------- *)

let lrange env (e: lexpr) =
  match e.lexpr_node with
  | PLrange(None,None) -> ()
  | _ -> error env ~loc:e.lexpr_loc "Range [..] expected"

let rec lpath env (e: lexpr) =
  let loc = e.lexpr_loc in
  match e.lexpr_node with
  | PLvar _ -> ()
  | PLdot( p , _ ) | PLarrow( p , _ )
  | PLunop( Ustar , p ) | PLunop( Uamp , p ) -> lpath env p
  | PLbinop( p , Badd , rg ) | PLarrget(p,rg) -> lpath env p ; lrange env rg
  | PLcast( _ , p ) -> lpath env p
  | _ ->
    error env ~loc "Unexpected l-value for region spec"

(* -------------------------------------------------------------------------- *)
(* ---  Parsers                                                           --- *)
(* -------------------------------------------------------------------------- *)

let parse_term env t =
  let open Logic_typing in
  let g = env.context in
  g.type_term g g.pre_state t

let parse_lval env p =
  let t = parse_term env p in
  match t.term_node with
  | TLval lv -> lv
  | _ -> error env ~loc:p.lexpr_loc "Expected l-value for region path"

let parse_integer env p =
  let v = parse_term env p in
  if not @@ Ast_types.Acsl.is_plain_integral v.term_type then
    error env ~loc:p.lexpr_loc "Expected integer term for object bounds" ; v

let parse_pointer env p =
  let loc = p.lexpr_loc in
  let a = parse_term env p in
  let te =
    match Ast_types.Acsl.unroll a.term_type with
    | Ctype { tnode = TPtr te } -> te
    | _ -> error env ~loc "Expected pointer l-value for region object"
  in te,a

let rec last_field = function
  | TNoOffset | TModel _ -> raise Not_found
  | TField(fd,TNoOffset) -> TNoOffset, fd
  | TField(f0,ofs) -> let ofs,fd = last_field ofs in TField(f0,ofs), fd
  | TIndex(k0,ofs) -> let ofs,fd = last_field ofs in TIndex(k0,ofs), fd

let parse_field env p =
  try
    let h,ofs = parse_lval env p in
    let ofs,fd = last_field ofs in
    if not fd.fcomp.cstruct then
      error env ~loc:p.lexpr_loc "Expected struct field for range path" ;
    (h,ofs),fd
  with Not_found ->
    error env ~loc:p.lexpr_loc "Expected field l-value for range path"

let garbage = Attr.(add `Garbage empty)

let applies flags = function
  | Range _ -> true
  | Alias(_,(TVar { lv_origin = Some v },_)) ->
    flags = garbage && v.vformal && Ast_types.C.is_struct_or_union v.vtype
  | Alias _ | Field _ -> false

let flush source env =
  if env.flags <> Attr.empty &&
     not @@ List.exists (applies env.flags) env.rpaths
  then
    Options.warning ~source:env.source "%a has no object to apply on"
      Attr.pretty env.flags ;
  if env.rpaths <> [] then
    begin
      env.regions <- {
        named = env.named ;
        flags = env.flags ;
        paths = List.rev env.rpaths ;
      } :: env.regions ;
      env.source <- source ;
      env.rpaths <- [] ;
      env.flags <- Attr.empty ;
    end

let rec parse_region (env:env) p =
  match p.lexpr_node with
  | PLvar "\\nullable"  -> env.flags <- Attr.add `Nullable  env.flags
  | PLvar "\\allocated" -> env.flags <- Attr.add `Allocated env.flags
  | PLvar "\\garbage"   -> env.flags <- Attr.add `Garbage   env.flags
  | PLvar "\\validread"  -> env.flags <- Attr.add `Validread  env.flags
  | PLnamed( name , p ) ->
    flush (fst p.lexpr_loc) env ;
    env.named <- name ;
    parse_region env p
  | PLrange(Some a,Some b) ->
    let l1,f = parse_field env a in
    let l2,g = parse_field env b in
    if not (Term_lval.equal l1 l2) then
      error env ~loc:p.lexpr_loc "Field range from different region paths" ;
    env.rpaths <- Field(p.lexpr_loc,l1,f,g) :: env.rpaths
  | PLarrget(p,{ lexpr_node = PLrange(Some a,Some b) })
  | PLunop(Ustar, {
        lexpr_node = PLbinop(p,Badd, {
            lexpr_node = PLrange(Some a,Some b)
          })}) ->
    let te,q = parse_pointer env p in
    let a = parse_integer env a in
    let b = parse_integer env b in
    env.rpaths <- Range(p.lexpr_loc,q,te,a,b) :: env.rpaths
  | PLunop(Ustar,p) ->
    let te,q = parse_pointer env p in
    let zero = Logic_const.tinteger ~loc:p.lexpr_loc 0 in
    env.rpaths <- Range(p.lexpr_loc,q,te,zero,zero) :: env.rpaths
  | _ ->
    let lv = lpath env p ; parse_lval env p in
    env.rpaths <- Alias(p.lexpr_loc,lv) :: env.rpaths

let parse_case p =
  match p.extended_node with
  | Ext_lexpr(e) when e.ext_name = "pinvariant" ->
    ()
  | Ext_lexpr(e) when e.ext_name = "pframe" ->
    ()
  | Ext_lexpr(e) when e.ext_name = "pwhen" ->
    ()
  | Ext_lexpr(e) ->
    Options.error ~current:true "The clause %s should not be used directly \
                                 inside a pcase."
      e.ext_name ;
    ()
  | Ext_extension(ext) ->
    Options.error ~current:true "The clause %s should not be used directly \
                                 inside a pcase."
      ext.gext_name ;
    ()

let parse_datamodel p =
  match p.extended_node with
  | Ext_lexpr(e) when e.ext_name = "pmodel" ->
    ()
  | Ext_lexpr(e) when e.ext_name = "pinvariant" ->
    ()
  | Ext_lexpr(e) when e.ext_name = "pframe" ->
    ()
  | Ext_lexpr(e) ->
    Options.error ~current:true "The clause %s should not be used directly \
                                 inside a datamodel."
      e.ext_name ;
    ()
  | Ext_extension(ext) when ext.gext_name = "pcase" ->
    List.iter parse_case ext.gext_content ;
    ()
  | Ext_extension(ext) ->
    Options.error ~current:true "The clause %s should not be used directly \
                                 inside a datamodel."
      ext.gext_name ;
    ()

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

let typecheck typing_context loc ps =
  let env = {
    source = fst loc ;
    named = "" ;
    flags = Attr.empty ;
    context = typing_context ;
    rpaths = [] ; regions = [] ;
  } in
  List.iter (parse_region env) ps ;
  let id = !kspec in incr kspec ;
  flush (fst loc) env ;
  Hashtbl.add registry id @@ List.rev env.regions ;
  Ext_id id

let typecheck_dm _ _ ps =
  List.iter parse_datamodel (snd ps) ;
  Ext_id 1

let typecheck_fail clause _ _ _ =
  Options.error ~current:true "The clause %s should not be used at top-level."
    clause ;
  Ext_id 0

let typecheck_tmp _ _ _ =
  Ext_id 1

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
    Acsl_extension.register_global_block
      ~plugin: "region" "datamodel" typecheck_dm false ;
    Acsl_extension.register_global
      ~plugin:"region" "pmodel" (typecheck_fail "pmodel") false ;
    Acsl_extension.register_global
      ~plugin:"region" "pwhen" (typecheck_fail "pwhen") false ;
    Acsl_extension.register_global
      ~plugin:"region" "pinvariant" (typecheck_fail "pinvariant") false ;
    Acsl_extension.register_global
      ~plugin:"region" "pframe" (typecheck_fail "pframe") false ;
    Acsl_extension.register_global_block
      ~plugin:"region" "pcase" (typecheck_fail "pcase") false ;
    Acsl_extension.register_code_annot
      ~plugin:"region" "heap" typecheck_tmp false ;
    Acsl_extension.register_code_annot
      ~plugin:"region" "call" typecheck_tmp false ;
    Acsl_extension.register_code_annot
      ~plugin:"region" "consume" typecheck_tmp false ;
    Acsl_extension.register_code_annot
      ~plugin:"region" "produce" typecheck_tmp false ;
    Acsl_extension.register_code_annot_next_both
      ~plugin:"region" "frame" typecheck_tmp false ;
    Acsl_extension.register_behavior
      ~plugin:"region" "consumes" typecheck_tmp false ;
    Acsl_extension.register_behavior
      ~plugin:"region" "produces" typecheck_tmp false ;
  end


(* -------------------------------------------------------------------------- *)
