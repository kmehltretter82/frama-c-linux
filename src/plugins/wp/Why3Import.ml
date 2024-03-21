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

module L = Wp_parameters
module P = Why3.Pmodule
module T = Why3.Theory
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

(* -------------------------------------------------------------------------- *)

type _theory = string * string list

let create_why3_env loadpath =
    begin fun () ->
      let main = WConf.get_main (WConf.read_config None) in
      let loadpathes = (WConf.loadpath (main))@loadpath  in
      W.Env.create_env loadpathes
    end
let extract_last_segment (str : string) =
    let segments = String.split_on_char '.' str in
    match List.rev segments with
    | hd :: tl -> (hd, List.rev tl)
    | [] -> ("", [])

let extract_last_segments (str_list : string list) =
  List.map extract_last_segment str_list
let extract_theory_name struc_theories =
  let t = extract_last_segments struc_theories in
  List.map (fun (theory_name, _) -> theory_name) t

let extract_theory_path struc_theories =
    let t = extract_last_segments struc_theories in
    List.map (fun (_, theory_path) -> theory_path) t

(* let rec get_ty_symbols_from_ty (tys : W.Ty.tysymbol) (tymap) =
  try W.Wstdlib.Mstr.find tymap tys
  with Not_found ->
    let ty = tys.tysymbol in
    tymap <- Mty.add tys.tysymbol tymap; *)

let get_name_from_ident (ident) =
  let ident_printer = W.Ident.create_ident_printer [] in
  W.Ident.id_unique (ident_printer) ident

let get_theory_from_user (env) (path) (name) (map) =
  let theory = W.Env.read_theory env ([String.concat "." path]) name in
  let theory_uid = (get_name_from_ident(theory.th_name)) in
    try W.Wstdlib.Mstr.find theory_uid map in map
with Not_found ->
     W.Wstdlib.Mstr.add (theory_uid) (theory) map


let () =
  Boot.Main.extend
    begin fun () ->
      let libs = L.Library.get () in
      List.iter
        (fun dir ->
          L.debug ~level:0 " + LIBS %s@." dir
        ) (F.to_string_list libs) ;
      let thys = L.Import.get () in
      List.iter
        (fun thy ->
           L.debug ~level:0 " + THY %s@." thy
        ) thys ;

      List.iter
        (fun thy ->
           L.debug ~level:0 " + Extracted theory name %s@." thy
        ) (extract_theory_name thys) ;

      List.iter
        (fun thy ->
           List.iter
            (fun p ->
              L.debug ~level:0 " + Extracted theory path %s@." p
            ) (thy);
        ) (extract_theory_path thys) ;



      let libs = L.Library.get () in
      let thys = L.Import.get () in
      let theories_map : W.Theory.theory W.Wstdlib.Mstr.t = W.Wstdlib.Mstr.empty in
      let env = create_why3_env (F.to_string_list libs) () in
      let loadpath = W.Env.get_loadpath env in
      List.iter
        (fun lpath ->
           L.debug ~level:0 " Loadpath %s@." lpath
        ) loadpath ;
      List.iter
      (fun (thy_n, thy_p) ->
        try
        let theory = (W.Env.read_theory env ([String.concat "." thy_p]) (thy_n))  in
        in
        W.Pretty.print_theory Format.std_formatter theory;
        L.debug ~level:0 "INTHY %s" thy_n;

        with W.Env.LibraryNotFound paths ->
          List.iter (
            fun path ->
              L.debug ~level:0 "Library not found at %s " path;
          ) paths;

        (* let _ns = (W.Env.read_theory env (F.to_string_list libs) thy).th_export in *)

         (* let _t =  (W.Wstdlib.Mstr.values (_ns.ns_ts)) in
         L.debug "Nombres de itys trucs : %d" (List.length _t); *)
      ) (extract_last_segments thys) ;
      (* let env = create_why3_env () in
      let _ns = (W.Env.read_theory env ["summodule"] "Sum") in
      L.debug ""; *)


    end

(* -------------------------------------------------------------------------- *)
