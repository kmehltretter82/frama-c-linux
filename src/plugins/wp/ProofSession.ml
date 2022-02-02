(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

open Wpo

type script =
  | NoScript
  | Script of string
  | Deprecated of string

let files : (string,script) Hashtbl.t = Hashtbl.create 32

let jsonfile (dir:Datatype.Filepath.t) =
  Format.sprintf "%s/%s.json" (dir :> string)

let filename ~force wpo =
  let dscript = Wp_parameters.get_session_dir ~force "script" in
  jsonfile dscript wpo.po_sid (* no model in name *)

let legacies wpo =
  let mid = WpContext.MODEL.id wpo.po_model in
  let dscript = Wp_parameters.get_session_dir ~force:false "script" in
  let dmodel = Wp_parameters.get_session_dir ~force:false mid in
  [
    jsonfile dscript wpo.po_gid ;
    jsonfile dmodel wpo.po_gid ;
    jsonfile dmodel wpo.po_leg ;
  ]

let get wpo =
  let f = filename ~force:false wpo in
  try Hashtbl.find files f
  with Not_found ->
    let script =
      if Sys.file_exists f then Script f else
        try
          let f' = List.find Sys.file_exists (legacies wpo) in
          Wp_parameters.warning ~current:false
            "Deprecated script for '%s'" wpo.po_sid ;
          Deprecated f'
        with Not_found -> NoScript
    in Hashtbl.add files f script ; script

let pp_file fmt s = Filepath.Normalized.(pretty fmt (of_string s))

let pp_script fmt = function
  | NoScript -> Format.pp_print_string fmt "no script file"
  | Script f -> Format.fprintf fmt "script '%a'" pp_file f
  | Deprecated f -> Format.fprintf fmt "script '%a' (deprecated)" pp_file f

let pp_script_for fmt wpo = pp_script fmt (get wpo)

let exists wpo =
  match get wpo with NoScript -> false | Script _ | Deprecated _ -> true

let load wpo =
  match get wpo with
  | NoScript -> `Null
  | Script f | Deprecated f ->
      if Sys.file_exists f then Json.load_file f else `Null

let remove wpo =
  match get wpo with
  | NoScript -> ()
  | Script f ->
      begin
        Extlib.safe_remove f ;
        Hashtbl.replace files f NoScript ;
      end
  | Deprecated f0 ->
      begin
        Wp_parameters.feedback
          "Removed deprecated script for '%s'" wpo.po_sid ;
        Extlib.safe_remove f0 ;
        let f = filename ~force:false wpo in
        Hashtbl.replace files f NoScript ;
      end

let save wpo js =
  let empty =
    match js with
    | `Null | `List [] | `Assoc [] -> true
    | _ -> false in
  if empty then remove wpo else
    match get wpo with
    | Script f ->
        Json.save_file f js
    | NoScript ->
        begin
          let f = filename ~force:true wpo in
          Json.save_file f js ;
          Hashtbl.replace files f (Script f) ;
        end
    | Deprecated f0 ->
        begin
          Wp_parameters.feedback
            "Upgraded script for '%s'" wpo.po_sid ;
          Extlib.safe_remove f0 ;
          let f = filename ~force:true wpo in
          Json.save_file f js ;
          Hashtbl.replace files f (Script f) ;
        end
