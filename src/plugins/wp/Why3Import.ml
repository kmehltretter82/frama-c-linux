(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Cil_datatype

module C = Cil_types
module Cpp = Cil_printer
module L = Wp_parameters
module T = Why3.Theory
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

let dkey = L.register_category "why3.import"

(* -------------------------------------------------------------------------- *)
(* ---    Why3 Environment                                                --- *)
(* -------------------------------------------------------------------------- *)

let create_why3_env loadpath =
  let main = WConf.get_main @@ WConf.read_config None in
  W.Env.create_env @@ WConf.loadpath main @ F.to_string_list loadpath



let extract_path thname =
  let segments = String.split_on_char '.' thname in
  match List.rev segments with
  | hd :: tl -> hd, List.rev tl
  | [] -> "", []

let of_infix s =
  let rec unwrap_any s = function
    | [] -> s
    | prefix::others ->
      if String.starts_with ~prefix s then
        let n = String.length s in
        let p = String.length prefix in
        Printf.sprintf "(%s)" @@ String.sub s p (n-p)
      else unwrap_any s others
  in unwrap_any s ["prefix ";"infix ";"mixfix "]

let construct_acsl_name (id : W.Ident.ident) =
  let (paths,name,scopes) = T.restore_path id in
  match List.rev scopes with
  | (t::q) ->
    String.concat "::" (paths @ name :: List.rev_append q [of_infix t])
  | [] -> ""

(* For debug only*)
let pp_id fmt (id: W.Ident.ident) =
  Format.pp_print_string fmt id.id_string

(* For debug only*)
let pp_tys fmt (tys: W.Ty.tysymbol) =
  W.Pretty.print_ty_decl fmt tys

(* For debug only*)
let pp_ls fmt ls =
  W.Pretty.print_ls fmt ls

(* For debug only*)
let pp_id_loc fmt (id : W.Ident.ident) =
  match id.id_loc with
  | Some loc -> W.Loc.pp_position fmt loc
  | None -> L.error "No location found"

(* For debug only*)
let pp_lti fmt (lti : C.logic_type_info) =
  Cpp.pp_logic_type_info fmt lti

(* For debug only*)
let pp_li fmt (li : C.logic_info) =
  Cpp.pp_logic_info fmt li

(* For debug only*)
let pp_lvs fmt (lvs : C.logic_var list) =
  List.iter (fun (lv: C.logic_var) ->
      Format.fprintf fmt "@ %a: %a"
        Cpp.pp_logic_var lv Cpp.pp_logic_type lv.lv_type
    ) lvs;

  (* -------------------------------------------------------------------------*)
  (* ---    Types                                                           - *)
  (* -------------------------------------------------------------------------*)


type tvars = C.logic_type W.Ty.Mtv.t

type why3module = {
  paths : string list;
  types : C.logic_type_info list;
  logics : C.logic_info list;
}

type env = {
  wenv : W.Env.env;
  tenv : C.logic_type_info W.Ty.Hts.t;
  lenv : C.logic_info W.Term.Hls.t;
  lils : W.Term.lsymbol Logic_info.Hashtbl.t;
  ltits : W.Ty.tysymbol Logic_type_info.Hashtbl.t;
  menv : why3module Datatype.String.Hashtbl.t
}

type temp_menv = {
  mutable lti : C.logic_type_info list;
  mutable li : C.logic_info list;
}

let create_empty_env wenv =
  let tenv  = W.Ty.Hts.create 0 in
  let lenv  = W.Term.Hls.create 0 in
  let lils  = Logic_info.Hashtbl.create 0 in
  let ltits  = Logic_type_info.Hashtbl.create 0 in
  let menv  = Datatype.String.Hashtbl.create 0 in
  { wenv; tenv; lenv; lils; ltits; menv }
(* -------------------------------------------------------------------------- *)
(* ---    Built-in                                                        --- *)
(* -------------------------------------------------------------------------- *)

let add_builtin (tenv) ts lt_name lt_params  =
  W.Ty.Hts.add tenv ts C.{lt_name ; lt_params; lt_def=None; lt_attr=[] }

let find_ts env pkg thy name =
  let th = Why3.Env.read_theory env.wenv pkg thy in
  try
    Why3.Theory.ns_find_ts th.th_export name
  with Not_found ->
    L.fatal "Cannot find %s.%s.%s"
      (String.concat "." pkg ) thy (String.concat "." name)

let add_builtins env =
  begin
    let ts_list = find_ts env ["list"] "List" ["list"] in
    let ts_set = find_ts env ["set"] "Set" ["set"] in
    add_builtin env.tenv W.Ty.ts_bool Utf8_logic.boolean [];
    add_builtin env.tenv ts_list "\\list" ["A"];
    add_builtin env.tenv ts_set "set" ["A"];
  end


(* -------------------------------------------------------------------------- *)
(* ---    Type conversion                                                 --- *)
(* -------------------------------------------------------------------------- *)

let tvars_of_txs (txs: W.Ty.tvsymbol list) : string list * tvars =
  List.iter (fun (tv: W.Ty.tvsymbol) ->
      L.debug ~level:3 "Name of : %a" pp_id tv.tv_name) txs;
  List.fold_right
    (fun (tv: W.Ty.tvsymbol) (txs,tvs) ->
       let x = tv.tv_name.id_string in
       x :: txs, W.Ty.Mtv.add tv (C.Lvar x) tvs
    ) txs ([], W.Ty.Mtv.empty)

let rec lt_of_ty (env : env) (temp_menv) (tvs : tvars)  (ty: W.Ty.ty) : C.logic_type =
  match ty.ty_node with
  | Tyvar x -> W.Ty.Mtv.find x tvs
  | Tyapp(s,[]) when W.Ty.(ts_equal s ts_int) -> C.Linteger
  | Tyapp(s,[]) when W.Ty.(ts_equal s ts_real) -> C.Lreal
  | Tyapp(s,ts) -> C.Ltype( lti_of_ts env temp_menv s ,
                            List.map (lt_of_ty env temp_menv tvs ) ts)

and lti_of_ts (env : env) (temp_menv : temp_menv) (ts : W.Ty.tysymbol) : C.logic_type_info =
  try W.Ty.Hts.find env.tenv ts with Not_found ->
    let (lt_params,tvars) = tvars_of_txs ts.ts_args in
    let lt_def =
      match ts.ts_def with
      | NoDef | Range _ | Float _ -> None
      | Alias ty -> Some (C.LTsyn (lt_of_ty env temp_menv tvars ty))
    in
    let lti =
      C.{
        lt_name =  construct_acsl_name ts.ts_name;
        lt_params ; lt_def ;
        lt_attr = [];
      }
    in W.Ty.Hts.add env.tenv ts lti ;
    temp_menv.lti <- lti :: temp_menv.lti;
    Logic_type_info.Hashtbl.add env.ltits lti ts;
    lti


(* -------------------------------------------------------------------------- *)
(* ---    Functions conversion                                            --- *)
(* -------------------------------------------------------------------------- *)

let lv_of_ty (env:env) (temp_menv : temp_menv) (tvars:tvars) (index) (ty:W.Ty.ty) : C.logic_var =
  Cil_const.make_logic_var_formal (Printf.sprintf "x%d" index)
  @@ (lt_of_ty env temp_menv tvars ty)

let lt_of_ty_opt (lt_opt) =
  match lt_opt with
  | None -> C.Ctype (C.TVoid []) (* Same as logic_typing *)
  | Some tr -> tr

let li_of_ls (env:env) (temp_menv : temp_menv) (ls : W.Term.lsymbol)  : C.logic_info =
  let l_tparams,tvars =
    tvars_of_txs @@ W.Ty.Stv.elements @@  W.Term.ls_ty_freevars ls in
  let l_type = Option.map (lt_of_ty  env temp_menv tvars ) ls.ls_value in
  let l_profile = List.mapi (lv_of_ty env temp_menv tvars ) ls.ls_args in
  let l_args = List.map ( fun (lv:C.logic_var) -> lv.lv_type) l_profile in
  let signature = C.Larrow (l_args, lt_of_ty_opt l_type) in
  let li =
    C.{
      l_var_info = Cil_const.make_logic_var_global
          (construct_acsl_name ls.ls_name)
          signature;
      l_labels = [];
      l_tparams;
      l_type;
      l_profile ;
      l_body = C.LBnone;
    } in W.Term.Hls.add env.lenv ls li;
  temp_menv.li <- li :: temp_menv.li;
  Logic_info.Hashtbl.add env.lils li ls;
  li


(* -------------------------------------------------------------------------- *)
(* ---    Theory                                                          --- *)
(* -------------------------------------------------------------------------- *)

let import_theory (env : env) thname =
  let theory_name, theory_path = extract_path thname in
  try
    let temp_menv : temp_menv = {li = []; lti = []} in
    let theory = W.Env.read_theory env.wenv theory_path theory_name in
    List.iter (fun (tdecl : T.tdecl) ->
        match tdecl.td_node with
        | Decl decl ->
          begin
            match decl.d_node with
            | Dtype ts ->
              L.debug ~dkey "Decl and type %a"  pp_id ts.ts_name;
              L.debug ~dkey "Location %a"  pp_id_loc ts.ts_name;
              let lti =  lti_of_ts env temp_menv ts in
              L.debug ~dkey "Correspondign LTI %a" pp_lti lti;
            | Ddata ddatas ->
              List.iter
                (fun ((ts, _) : W.Decl.data_decl) ->
                   L.debug ~dkey "Decl and data %a" pp_id  ts.ts_name;
                   L.debug ~dkey "Location %a"  pp_id_loc ts.ts_name;
                   let lti =  lti_of_ts env temp_menv ts  in
                   L.debug ~dkey "Correspondign data LTI %a" pp_lti lti;
                ) ddatas
            | Dparam ls ->
              L.debug ~dkey "Decl and dparam %a" pp_id ls.ls_name;
              L.debug ~dkey "Location %a"  pp_id_loc ls.ls_name
            | Dlogic dlogics ->
              List.iter
                (fun ((ls,_):W.Decl.logic_decl) ->
                   L.debug ~dkey "Decl and dlogic %a" pp_id ls.ls_name;
                   L.debug ~dkey "Location %a"  pp_id_loc ls.ls_name;
                   let li = li_of_ls env temp_menv ls in
                   L.debug ~dkey "Corresponding dlogic LTI %a" pp_li li;
                ) dlogics
            | _ -> L.debug ~dkey "Other type of Decl"
          end
        | Use _| Clone _| Meta _ -> L.debug ~dkey ""
      ) theory.th_decls;
    Datatype.String.Hashtbl.add env.menv thname
      { logics =  List.rev temp_menv.li;
        types = List.rev temp_menv.lti;
        paths = theory_path };
  with W.Env.LibraryNotFound _ ->
    L.error "Library %s not found" thname


(* -------------------------------------------------------------------------- *)
(* ---    Main                                                            --- *)
(* -------------------------------------------------------------------------- *)

let () =
  Boot.Main.extend
    begin fun () ->
      let libs = L.Library.get() in
      let imports = L.Import.get() in
      if libs <> [] || imports <> [] then
        begin
          let wenv = create_why3_env @@ libs in
          let env : env = create_empty_env wenv in
          add_builtins env;
          List.iter (import_theory env) @@ imports;
          W.Ty.Hts.iter (fun (tys) (lti) ->
              L.result "Why3 type symbol : %a" pp_tys tys;
              L.result "Corresponding CIL logic type info %a" pp_lti lti;
            ) env.tenv;
          W.Term.Hls.iter (fun (ls) (li) ->
              L.result "Why3 logic symbol : %a" pp_ls ls;
              L.result "Corresponding CIL logic info : %a" pp_li li;
              L.result "Associated parameters : @[<hov2>%a@]" pp_lvs li.l_profile;
            ) env.lenv;
          Datatype.String.Hashtbl.iter (fun (s) (why3mod) ->
              L.result "@[Module %s at %s@]" s (String.concat "::" why3mod.paths);
              List.iter (fun (li) ->
                  L.result "Logic : @[<hov1>%a@]" pp_li li)
                why3mod.logics;
              List.iter (fun (lti) ->
                  L.result "Type : @[<hov1>%a@]" pp_lti lti)
                why3mod.types;
            ) env.menv;
          Logic_type_info.Hashtbl.iter ( fun (lti) (ts) ->
              L.result "Logic type info : %a is associated to ts : %a "
                pp_lti lti pp_tys ts )
            env.ltits;
          Logic_info.Hashtbl.iter ( fun (li) (ls) ->
              L.result "Logic info %a is associated to ls : %a "
                pp_li li pp_ls ls )
            env.lils;
        end

    end

(* -------------------------------------------------------------------------- *)
