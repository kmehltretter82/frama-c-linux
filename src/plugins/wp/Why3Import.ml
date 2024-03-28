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

let create_why3_env loadpath =
  let main = WConf.get_main @@ WConf.read_config None in
  W.Env.create_env @@ WConf.loadpath main @ F.to_string_list loadpath

let extract_path thname =
  let segments = String.split_on_char '.' thname in
  match List.rev segments with
  | hd :: tl -> hd, List.rev tl
  | [] -> "", []

(* For debug only*)
let pp_id fmt (id: W.Ident.ident) =
  Format.pp_print_string fmt id.id_string

(* For debug only*)
let pp_id_loc fmt (id : W.Ident.ident) =
  match id.id_loc with
  | Some loc -> W.Loc.pp_position fmt loc
  | None -> L.debug ~level:0 "No location found"

let pp_lti fmt (lti : C.logic_type_info) =
  Cpp.pp_logic_type_info fmt lti

type tenv = C.logic_type_info W.Ty.Hts.t
type tvars = C.logic_type W.Ty.Mtv.t
type uid_tvars = string W.Ty.Mtv.t

let rec lt_of_ty (tenv : tenv) (tvs : tvars) (ty: W.Ty.ty) : C.logic_type =
  match ty.ty_node with
  | Tyvar x -> W.Ty.Mtv.find x tvs
  | Tyapp(s,ts) -> C.Ltype( ls_of_ts tenv s, List.map (lt_of_ty tenv tvs) ts)

and ls_of_ts (tenv : tenv) (ts : W.Ty.tysymbol): C.logic_type_info =
  try W.Ty.Hts.find tenv ts with Not_found ->
    let temp_env = create_temp_env ts
    in
    let lt_params =
      List.map
        (fun (tv : W.Ty.tvsymbol) -> tv.tv_name.id_string)
        ts.ts_args in
    let lt_def =
      lt_def_of_ts tenv ts temp_env
    in
    let lti =
      C.{
        lt_name = ts.ts_name.id_string;
        lt_params ; lt_def ;
        lt_attr = [];
      }
    in W.Ty.Hts.add tenv ts lti ;
    L.debug ~level:0 "Added LTI %a" pp_lti lti; lti
and lt_def_of_ts (tenv:tenv) (ts : W.Ty.tysymbol) (temp_env : uid_tvars) =
  match ts.ts_def with
  | NoDef | Range _ | Float _ -> None
  | Alias ty ->
    let tvars =
      W.Ty.Mtv.map (fun aleph_name -> C.Lvar aleph_name) temp_env
    in
    Some (C.LTsyn (lt_of_ty tenv tvars ty))
and create_temp_env (ts: W.Ty.tysymbol) : uid_tvars =
    List.fold_left
      (fun (tvs: uid_tvars) (tv: W.Ty.tvsymbol) ->
         W.Ty.Mtv.add tv (tv.tv_name.id_string) tvs
      ) W.Ty.Mtv.empty ts.ts_args

let import_theory env (tenv:tenv) thname =
  let theory_name, theory_path = extract_path thname in
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
              let lti =  ls_of_ts  tenv ts in
              L.debug ~level:0 "Correspondign LTI %a" pp_lti lti;
            | Ddata ddatas ->
              List.iter
                (fun ((ts, _) : W.Decl.data_decl) ->
                   L.debug ~level:0 "Decl and data %a" pp_id  ts.ts_name;
                   L.debug ~level:0 "Location %a"  pp_id_loc ts.ts_name
                ) ddatas
            | Dparam ls ->
              L.debug ~level:0 "Decl and dparam %a" pp_id ls.ls_name;
              L.debug ~level:0 "Location %a"  pp_id_loc ls.ls_name
            | Dlogic dlogics ->
              List.iter
                (fun ((ls,_):W.Decl.logic_decl) ->
                   L.debug ~level:0 "Decl and dlogic %a" pp_id ls.ls_name;
                   L.debug ~level:0 "Location %a"  pp_id_loc ls.ls_name
                ) dlogics
            | _ -> L.debug ~level:0 "Decl but whatever"
          end
        | Use _ -> L.debug ~level:0 "Use"
        | Clone _ -> L.debug ~level:0 "Clone"
        | Meta _ -> L.debug ~level:0 "Meta"
      ) theory.th_decls
  with W.Env.LibraryNotFound _ ->
    L.error "Library %s not found" thname

let () =
  Boot.Main.extend
    begin fun () ->
      let env = create_why3_env @@ L.Library.get () in
      let tenv : tenv = W.Ty.Hts.create 3 in
      List.iter (import_theory env tenv) @@ L.Import.get ();
      L.debug ~level:0 "Length of type environment : %d " (W.Ty.Hts.length tenv);
      W.Ty.Hts.iter (fun (ty) (lti) ->
          L.debug ~level:0 "TY %a" pp_id ty.ts_name;
          L.debug ~level:0 "LTI %a" pp_lti lti;
        ) tenv
    end

(* -------------------------------------------------------------------------- *)
