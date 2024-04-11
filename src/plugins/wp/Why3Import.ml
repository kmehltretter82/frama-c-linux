(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module C = Cil_types
module Cpp = Cil_printer
module L = Wp_parameters
module T = Why3.Theory
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

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

let construct_acsl_name thpaths thname sname =
  (String.concat "::" thpaths) ^ "::" ^ thname ^ "::" ^ sname

(* For debug only*)
let pp_id fmt (id: W.Ident.ident) =
  Format.pp_print_string fmt id.id_string

(* For debug only*)
let pp_id_loc fmt (id : W.Ident.ident) =
  match id.id_loc with
  | Some loc -> W.Loc.pp_position fmt loc
  | None -> L.debug ~level:0 "No location found"

(* For debug only*)
let pp_lti fmt (lti : C.logic_type_info) =
  Cpp.pp_logic_type_info fmt lti

(* For debug only*)
let pp_li fmt (li : C.logic_info) =
  Cpp.pp_logic_info fmt li

(* -------------------------------------------------------------------------- *)
(* ---    Types                                                           --- *)
(* -------------------------------------------------------------------------- *)

type tenv = C.logic_type_info W.Ty.Hts.t
type lenv = C.logic_info W.Term.Hls.t
type tvars = C.logic_type W.Ty.Mtv.t


let tvars_of_txs (txs: W.Ty.tvsymbol list) : string list * tvars =
  List.fold_right
    (fun (tv: W.Ty.tvsymbol) (txs,tvs) ->
       let x = tv.tv_name.id_string in
       x :: txs, W.Ty.Mtv.add tv (C.Lvar x) tvs
    ) txs ([], W.Ty.Mtv.empty)

let rec lt_of_ty (tenv : tenv) (tvs : tvars) ((thname, thpaths)) (ty: W.Ty.ty) : C.logic_type =
  match ty.ty_node with
  | Tyvar x -> W.Ty.Mtv.find x tvs
  | Tyapp(s,ts) -> C.Ltype( lti_of_ts tenv s (thname, thpaths), List.map (lt_of_ty tenv tvs (thname, thpaths)) ts)

and lti_of_ts (tenv : tenv) (ts : W.Ty.tysymbol) ((thname, thpaths)): C.logic_type_info =
  try W.Ty.Hts.find tenv ts with Not_found ->
    let (lt_params,tvars) = tvars_of_txs ts.ts_args in
    let lt_def =
      match ts.ts_def with
      | NoDef | Range _ | Float _ -> None
      | Alias ty -> Some (C.LTsyn (lt_of_ty tenv tvars (thname, thpaths) ty))
    in
    let lti =
      C.{
        lt_name =  construct_acsl_name thpaths thname ts.ts_name.id_string; (* "int::Int::add" *)
        lt_params ; lt_def ;
        lt_attr = [];
      }
    in W.Ty.Hts.add tenv ts lti ;
    L.debug ~level:0 "Added LTI %a" pp_lti lti; lti

(* -------------------------------------------------------------------------- *)
(* ---    Functions                                                       --- *)
(* -------------------------------------------------------------------------- *)

let lv_of_ty (tenv:tenv) (tvars:tvars) ((thname, thpaths)) (index) (ty:W.Ty.ty)  : C.logic_var =
  Cil_const.make_logic_var_formal (Printf.sprintf "x%d" index)
  @@ (lt_of_ty tenv tvars ((thname, thpaths)) ty)

let lr_of_ty_opt (lt_opt) =
  match lt_opt with
  | None -> C.Ctype (C.TVoid []) (* Same as logic_typing *)
  | Some tr -> tr


let li_of_ls (tenv:tenv) (ls : W.Term.lsymbol) (lenv:lenv) ((thname, thpaths)) : C.logic_info =
  let l_tparams,tvars =
    tvars_of_txs @@ W.Ty.Stv.elements @@  W.Term.ls_ty_freevars ls in
  let l_type = Option.map (lt_of_ty tenv tvars (thname, thpaths)) ls.ls_value in
  let l_profile = List.mapi (lv_of_ty tenv tvars (thname, thpaths)) ls.ls_args in
  let l_args = List.map ( fun (lv:C.logic_var) -> lv.lv_type) l_profile in
  let signature = C.Larrow (l_args, lr_of_ty_opt l_type) in
  let li =
    C.{
      l_var_info = Cil_const.make_logic_var_global
          (construct_acsl_name thpaths thname ls.ls_name.id_string)
          signature;
      l_labels = [];
      l_tparams;
      l_type;
      l_profile ;
      l_body = C.LBnone;
    } in W.Term.Hls.add lenv ls li; li


(* -------------------------------------------------------------------------- *)
(* ---    Theory                                                          --- *)
(* -------------------------------------------------------------------------- *)




let import_theory env (tenv:tenv) (lenv:lenv) thname =
  let theory_name, theory_path = extract_path thname in
  L.debug ~level:0 "Theory name : %s" theory_name;
  List.iter (L.debug ~level:0 "%s") theory_path;
  try
    let theory = W.Env.read_theory env theory_path theory_name in
    List.iter (fun (tdecl : T.tdecl) ->
        match tdecl.td_node with
        | Decl decl ->
          begin
            match decl.d_node with
            | Dtype ts ->
              L.debug ~level:0 "Decl and type %a"  pp_id ts.ts_name;
              L.debug ~level:0 "Location %a"  pp_id_loc ts.ts_name;
              let lti =  lti_of_ts  tenv ts (theory_name, theory_path) in
              L.debug ~level:0 "Correspondign LTI %a" pp_lti lti;
            | Ddata ddatas ->
              List.iter
                (fun ((ts, _) : W.Decl.data_decl) ->
                   L.debug ~level:0 "Decl and data %a" pp_id  ts.ts_name;
                   L.debug ~level:0 "Location %a"  pp_id_loc ts.ts_name;
                   let lti =  lti_of_ts  tenv ts (theory_name, theory_path) in
                   L.debug ~level:0 "Correspondign data LTI %a" pp_lti lti;
                ) ddatas
            | Dparam ls ->
              L.debug ~level:0 "Decl and dparam %a" pp_id ls.ls_name;
              L.debug ~level:0 "Location %a"  pp_id_loc ls.ls_name
            | Dlogic dlogics ->
              List.iter
                (fun ((ls,_):W.Decl.logic_decl) ->
                   L.debug ~level:0 "Decl and dlogic %a" pp_id ls.ls_name;
                   L.debug ~level:0 "Location %a"  pp_id_loc ls.ls_name;
                   let li = li_of_ls tenv ls lenv (theory_name,theory_path) in
                   L.debug ~level:0 "Corresponding dlogic LTI %a" pp_li li;
                ) dlogics
            | _ -> L.debug ~level:0 "Decl but whatever"
          end
        | Use _ -> L.debug ~level:0 "Use"
        | Clone _ -> L.debug ~level:0 "Clone"
        | Meta _ -> L.debug ~level:0 "Meta"
      ) theory.th_decls
  with W.Env.LibraryNotFound _ ->
    L.error "Library %s not found" thname

(* -------------------------------------------------------------------------- *)
(* ---    Main                                                            --- *)
(* -------------------------------------------------------------------------- *)

let () =
  Boot.Main.extend
    begin fun () ->
      let env = create_why3_env @@ L.Library.get () in
      let tenv : tenv = W.Ty.Hts.create 0 in
      let lenv : lenv = W.Term.Hls.create 0 in
      List.iter (import_theory env tenv lenv) @@ L.Import.get ();
      L.debug ~level:0 "Length of type environment : %d " (W.Ty.Hts.length tenv);
      W.Ty.Hts.iter (fun (ty) (lti) ->
          L.debug ~level:0 "TY %a" pp_id ty.ts_name;
          L.debug ~level:0 "LTI %a" pp_lti lti;
        ) tenv;
      W.Term.Hls.iter (fun (ls) (li) ->
          L.debug ~level:0 "TY %a" pp_id ls.ls_name;
          L.debug ~level:0 "LI %a" pp_li li;
        ) lenv

    end

(* -------------------------------------------------------------------------- *)
