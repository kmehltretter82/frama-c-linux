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
module LB = LogicBuiltins

let dkey = L.register_category "why3.import"

(* -------------------------------------------------------------------------- *)
(* ---    Why3 Environment                                                --- *)
(* -------------------------------------------------------------------------- *)

let why3_env loadpath =
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

(* -------------------------------------------------------------------------*)
(* ---    Types                                                           - *)
(* -------------------------------------------------------------------------*)

type tvars = C.logic_type W.Ty.Mtv.t

type why3module = {
  paths : string list;
  types : (C.logic_type_info * C.location) list;
  logics : (C.logic_info * C.location) list;
}

type env = {
  wenv : W.Env.env;
  tenv : C.logic_type_info W.Ty.Hts.t;
  lenv : C.logic_info W.Term.Hls.t;
  lils : W.Term.lsymbol Logic_info.Hashtbl.t;
  ltits : W.Ty.tysymbol Logic_type_info.Hashtbl.t;
  menv : why3module Datatype.String.Hashtbl.t;
}

type menv = {
  mutable lti : (C.logic_type_info * C.location) list;
  mutable li : (C.logic_info * C.location) list;
}

let create wenv =
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
(* ---    Location handling                                               --- *)
(* -------------------------------------------------------------------------- *)

let convert_location (wloc : Why3.Loc.position option) : C.location =
  match wloc with
  | Some loc ->
    let (file,lstart,cstart,lend,cend) = Why3.Loc.get loc in
    let pstart = {
      Filepath.pos_path = F.of_string file;
      pos_lnum = lstart;
      pos_bol = 0;
      pos_cnum = cstart;
    }  in
    let pend = {
      Filepath.pos_path = F.of_string file;
      pos_lnum = lend;
      pos_bol = 0;
      pos_cnum = cend;
    } in (pstart, pend)
  | None ->
    (Position.unknown, Position.unknown)


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

let rec lt_of_ty (env : env) (menv) (tvs : tvars)  (ty: W.Ty.ty) : C.logic_type =
  match ty.ty_node with
  | Tyvar x -> W.Ty.Mtv.find x tvs
  | Tyapp(s,[]) when W.Ty.(ts_equal s ts_int) -> C.Linteger
  | Tyapp(s,[]) when W.Ty.(ts_equal s ts_real) -> C.Lreal
  | Tyapp(s,ts) -> C.Ltype( lti_of_ts env menv s ,
                            List.map (lt_of_ty env menv tvs ) ts)

and lti_of_ts (env : env) (menv : menv) (ts : W.Ty.tysymbol) : C.logic_type_info =
  try W.Ty.Hts.find env.tenv ts with Not_found ->
    let (lt_params,tvars) = tvars_of_txs ts.ts_args in
    let lt_def =
      match ts.ts_def with
      | NoDef | Range _ | Float _ -> None
      | Alias ty -> Some (C.LTsyn (lt_of_ty env menv tvars ty))
    in
    let lti =
      C.{
        lt_name =  construct_acsl_name ts.ts_name;
        lt_params ; lt_def ;
        lt_attr = [];
      }
    in W.Ty.Hts.add env.tenv ts lti ;
    menv.lti <- (lti, (convert_location ts.ts_name.id_loc) ) :: menv.lti;
    Logic_type_info.Hashtbl.add env.ltits lti ts;
    lti

(* -------------------------------------------------------------------------- *)
(* ---    Functions conversion                                            --- *)
(* -------------------------------------------------------------------------- *)

let lv_of_ty (env:env) (menv : menv) (tvars:tvars) (index) (ty:W.Ty.ty) : C.logic_var =
  Cil_const.make_logic_var_formal (Printf.sprintf "x%d" index)
  @@ (lt_of_ty env menv tvars ty)

let lt_of_ty_opt (lt_opt) =
  match lt_opt with
  | None -> C.Ctype (C.TVoid []) (* Same as logic_typing *)
  | Some tr -> tr

let li_of_ls (env:env) (menv : menv) (ls : W.Term.lsymbol)  : C.logic_info =
  let l_tparams,tvars =
    tvars_of_txs @@ W.Ty.Stv.elements @@  W.Term.ls_ty_freevars ls in
  let l_type = Option.map (lt_of_ty  env menv tvars ) ls.ls_value in
  let l_profile = List.mapi (lv_of_ty env menv tvars ) ls.ls_args in
  let l_args = List.map ( fun (lv:C.logic_var) -> lv.lv_type) l_profile in
  let l_result = lt_of_ty_opt l_type in
  let signature = if l_args = [] then l_result else C.Larrow (l_args, l_result) in
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
  menv.li <- (li, (convert_location ls.ls_name.id_loc) ):: menv.li;
  Logic_info.Hashtbl.add env.lils li ls;
  li


(* -------------------------------------------------------------------------- *)
(* ---    Theory                                                          --- *)
(* -------------------------------------------------------------------------- *)

let get_theory (env) (theory_name) (theory_path) =
  try W.Env.read_theory env.wenv theory_path theory_name
  with W.Env.LibraryNotFound _ ->
    L.error "Library %s not found" theory_name; W.Theory.ignore_theory

let parse_theory (env) (theory:W.Theory.theory) (menv) =
  begin
    List.iter (fun (tdecl : T.tdecl) ->
        match tdecl.td_node with
        | Decl decl ->
          begin
            match decl.d_node with
            | Dtype ts ->
              L.debug ~dkey "Decl: type %a"  pp_id ts.ts_name;
              let lti =  lti_of_ts env menv ts in
              L.debug ~dkey "Corresponding LTI %a" pp_lti lti;
            | Ddata ddatas ->
              List.iter
                (fun ((ts, _) : W.Decl.data_decl) ->
                   L.debug ~dkey "Decl: data %a" pp_id  ts.ts_name;
                   let lti =  lti_of_ts env menv ts  in
                   L.debug ~dkey "Correspondign data LTI %a" pp_lti lti;
                ) ddatas
            | Dparam ls ->
              L.debug ~dkey "Decl: param %a" pp_id ls.ls_name;
              let li = li_of_ls env menv ls in
              L.debug ~dkey "Corresponding dlogic LI %a" pp_li li
            | Dlogic dlogics ->
              List.iter
                (fun ((ls,_):W.Decl.logic_decl) ->
                   L.debug ~dkey "Decl:logic %a" pp_id ls.ls_name;
                   L.debug ~dkey "Location %a"  pp_id_loc ls.ls_name;
                   let li = li_of_ls env menv ls in
                   L.debug ~dkey "Corresponding dlogic LI %a" pp_li li;
                ) dlogics
            | Dind (_,dec) ->
              List.iter (fun ((ls,_) : W.Decl.ind_decl) ->
                  L.debug ~dkey "Ddecl: indutive %a" pp_id ls.ls_name;
                  let li = li_of_ls env menv ls in
                  L.debug ~dkey "Corresponding dlogic LI %a" pp_li li;
                ) dec;

            | Dprop _ -> ()
          end
        | Use _ | Clone _ | Meta _ -> ()
      ) theory.th_decls;
  end


let register_builtin env thname =
  let kind_of_lt (lt : C.logic_type) : LB.kind =
    match lt with
    | C.Linteger -> LB.Z
    | C.Lreal -> LB.R
    | _ -> LB.A
  in
  let kind_of_lv (lv : C.logic_var) : LB.kind =
    kind_of_lt lv.lv_type
  in
  let sort_of_lt (lt : C.logic_type) : Qed.Logic.sort =
    match lt with
    | C.Linteger -> Qed.Logic.Sint
    | C.Lreal -> Qed.Logic.Sreal
    | _ -> Qed.Logic.Sdata
  in
  let sort_of_lv (lv : C.logic_var) : Qed.Logic.sort =
    sort_of_lt lv.lv_type
  in
  begin
    let current_module = Datatype.String.Hashtbl.find env.menv thname in
    List.iter (fun (lti, _) ->
        let ty = Logic_type_info.Hashtbl.find env.ltits lti in
        let (package,theory,name) = T.restore_path ty.ts_name in
        LB.add_builtin_type lti.lt_name @@ Lang.imported_t ~package ~theory ~name ;
        L.result "Imported type ! %a" pp_lti lti;
      ) current_module.types;

    List.iter (fun (li, _) ->
        let ls = Logic_info.Hashtbl.find env.lils li in
        let (package,theory,name) = T.restore_path ls.ls_name in
        let params = List.map (sort_of_lv) li.l_profile in
        let result = match li.l_type with
          | Some a -> sort_of_lt a
          | None -> Qed.Logic.Sprop
        in
        LB.add_builtin li.l_var_info.lv_name (List.map (kind_of_lv) li.l_profile) @@
        Lang.imported_f ~package ~theory ~name ~params ~result  ();
        L.result "Imported logic ! %a" pp_li li;
      ) current_module.logics;
  end

let import_theory (env : env) thname =
  let theory_name, theory_path = extract_path thname in
  let menv : menv = {li = []; lti = []} in
  try
    let i = Datatype.String.Hashtbl.find env.menv thname in
    List.iter (L.result "%s") i.paths;
  with Not_found ->
    let theory = get_theory env theory_name theory_path in
    parse_theory env theory menv;
    Datatype.String.Hashtbl.add env.menv thname
      { logics =  List.rev menv.li;
        types = List.rev menv.lti;
        paths = theory_path };
    register_builtin env thname

(* -------------------------------------------------------------------------- *)
(* ---    Module registration                                             --- *)
(* -------------------------------------------------------------------------- *)

module Env = WpContext.StaticGenerator
    (Datatype.Unit)
    (struct
      type key = unit
      type data = env
      let name = "Wp.Why3Import.Env"
      let compile () =
        let env = create @@ why3_env @@ L.Library.get () in
        add_builtins env ; env
    end)

let loader (ctxt: Logic_typing.module_builder) (_: C.location) (m: string list) =
  begin

    (* Use Env.get () to obtain the global env of the current project *)
    (* Use import_theory if the module is not in the hashtbl *)
    (* Register logics in ctxt for the imported (or cached) module *)


    L.result "Importing Why3 theory %s.@." (String.concat "::" m) ;
    let thname = String.concat "." m in
    import_theory (Env.get ()) thname;
    let env = Env.get () in
    let current_module = Datatype.String.Hashtbl.find env.menv thname in

    List.iter (fun (lti,loc) ->
        ctxt.add_logic_type loc lti;
        L.result "%a" pp_lti lti;
      ) current_module.types;
    List.iter (fun (li, loc) ->
        ctxt.add_logic_function loc li;
        L.result "%a" pp_li li;

      ) current_module.logics;
    L.result "Successfully imported theory at %s"
    @@ String.concat "::" current_module.paths;

  end

let registered = ref false

let register () =
  if not !registered then
    begin
      registered := true ;
      Acsl_extension.register_module_importer ~plugin:"wp" "why3" loader ;
    end

let () = Cmdline.run_after_extended_stage register

(* -------------------------------------------------------------------------- *)
