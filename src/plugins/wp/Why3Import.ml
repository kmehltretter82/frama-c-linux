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
module T = Why3.Theory
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

(* -------------------------------------------------------------------------- *)

type _theory = string * string list

let create_why3_env loadpath =
  let main = WConf.get_main (WConf.read_config None) in
  let loadpathes = (WConf.loadpath (main))@loadpath  in
  W.Env.create_env loadpathes

let extract_last_segments (str_list : string list) =
  List.map (fun str ->
      let segments = String.split_on_char '.' str in
      match List.rev segments with
      | hd :: tl -> (hd, List.rev tl)
      | [] -> ("", [])
    ) str_list

let get_name_from_ident (ident) =
  let ident_printer = W.Ident.create_ident_printer [] in
  W.Ident.id_unique (ident_printer) ident


let open_theories_of_user (env) (theories) =
  List.iter
    (fun (theory_name, theory_path) ->
       try
         let theory = (W.Env.read_theory env (theory_path) (theory_name)) in
         List.iter ( fun (tdecl : T.tdecl) ->
             match tdecl.td_node with
             | Decl decl ->
               (match (decl.d_node : W.Decl.decl_node) with
                | Dtype dtype -> L.debug ~level:0 "Decl and type, named : %s.@"  (get_name_from_ident dtype.ts_name);
                | Ddata ddatas ->
                  List.iter (fun ((tysymbol, _) : W.Decl.data_decl) ->
                      L.debug ~level:0 "Decl and dtata, named : %s.@" (get_name_from_ident tysymbol.ts_name);
                    ) ddatas;
                | Dparam dparam -> L.debug ~level:0 "Decl and dparam, named : %s.@" (get_name_from_ident dparam.ls_name);
                | Dlogic dlogics ->
                  List.iter (fun ((ls,_):W.Decl.logic_decl) ->
                      L.debug ~level:0 "Decl and dlogic, named : %s.@" (get_name_from_ident ls.ls_name);
                    ) dlogics;
                | _ -> L.debug ~level:0 "Decl but whatever")
             | Use _ -> L.debug ~level:0 "Use"
             | Clone _ -> L.debug ~level:0 "Clone"
             | Meta _ -> L.debug ~level:0 "Meta"
           ) theory.th_decls;

       with W.Env.LibraryNotFound paths ->
         L.debug ~level:0 "Library %s not found at %s " theory_name (String.concat "." paths);
    ) (extract_last_segments theories)


let open_modules_of_user (env) (modules) =
  List.iter
  (fun (theory_name, theory_path) ->
     try
       let pmodule = (W.Pmodule.read_module env (theory_path) (theory_name)) in
       List.iter ( fun (modunit : W.Pmodule.mod_unit) ->
        L.debug ~level:0 "Meta";
         ) pmodule.mod_units;

     with W.Env.LibraryNotFound paths ->
       L.debug ~level:0 "Library %s not found at %s " theory_name (String.concat "." paths);
  ) (extract_last_segments modules)



let () =
  Boot.Main.extend
    begin fun () ->
      let user_libraries = L.Library.get () in
      (* DEBUG ONLY *)
      List.iter (fun dir ->
          L.debug ~level:0 " + LIBS %s@." dir
        ) (F.to_string_list user_libraries) ;
      (* DEBUG ONLY *)
      let user_theories = L.Import.get () in
      List.iter (fun thy ->
          L.debug ~level:0 " + THY %s@." thy
        ) user_theories ;

      let user_libraries = L.Library.get () in
      let user_theories = L.Import.get () in
      let env = create_why3_env (F.to_string_list user_libraries) in
      open_theories_of_user (env) (user_theories);


    end

(* -------------------------------------------------------------------------- *)
