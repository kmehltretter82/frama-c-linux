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
  | Alias of location * term_lval
  | Field of location * term_lval * fieldinfo * fieldinfo

type region = {
  name : string option ;
  paths : path list ;
}

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

let pp_named fmt = function None -> () | Some a -> Format.fprintf fmt "%s: " a

let pp_path fmt = function
  (* | Array(a,p,q) ->
     Format.fprintf fmt "%a[%a..%a]"
      Printer.pp_term a
      Printer.pp_term p
      Printer.pp_term q *)
  | Alias(_,lv) ->
    Printer.pp_term_lval fmt lv
  | Field(_,lv,f,g) ->
    let field lv f = Logic_const.addTermOffsetLval (TField(f,TNoOffset)) lv in
    Format.fprintf fmt "%a..%a"
      Printer.pp_term_lval (field lv f)
      Printer.pp_term_lval (field lv g)

let pp_region fmt r =
  match r.paths with
  | [] -> Format.pp_print_string fmt "\\empty"
  | p::ps ->
    begin
      Format.fprintf fmt "@[<hov 2>" ;
      pp_named fmt r.name ; pp_path fmt p ;
      List.iter (Format.fprintf fmt ",@ %a" pp_path) ps ;
      Format.fprintf fmt "@]" ;
    end

let pp_regions fmt = function
  | [] -> Format.pp_print_string fmt "\\empty"
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
  mutable named: string option ;
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

let rec parse_region (env:env) p =
  match p.lexpr_node with
  | PLnamed( name , p ) ->
    if env.named <> None && env.rpaths <> [] then
      begin
        env.regions <- {
          name = env.named ;
          paths = List.rev env.rpaths ;
        } :: env.regions ;
        env.rpaths <- [] ;
      end ;
    env.named <- Some name ;
    parse_region env p
  | PLrange(Some a,Some b) ->
    let l1,f = parse_field env a in
    let l2,g = parse_field env b in
    if not (Term_lval.equal l1 l2) then
      error env ~loc:p.lexpr_loc "Field range from different region paths" ;
    env.rpaths <- Field(p.lexpr_loc,l1,f,g) :: env.rpaths
  | _ ->
    let lv = lpath env p ; parse_lval env p in
    env.rpaths <- Alias(p.lexpr_loc,lv) :: env.rpaths

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
    rpaths = [] ; regions = [] ;
  } in
  List.iter (parse_region env) ps ;
  let id = !kspec in incr kspec ;
  let regions =
    if env.rpaths <> [] then
      { name = env.named ; paths = List.rev env.rpaths } :: env.regions
    else env.regions in
  Hashtbl.add registry id @@ List.rev regions ;
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
