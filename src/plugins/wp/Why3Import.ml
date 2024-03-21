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

let open_theory (env) (theories) =
  List.iter
    (fun (thy_n, thy_p) ->
       try
         let theory = (W.Env.read_theory env (thy_p) (thy_n)) in
         W.Pretty.print_theory Format.std_formatter theory;
         L.debug ~level:0 "INTHY %s" thy_n;

       with W.Env.LibraryNotFound paths ->
         List.iter (
           fun path ->
             L.debug ~level:0 "Library not found at %s " path;
         ) paths;
    ) (extract_last_segments theories)


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

      let libs = L.Library.get () in
      let thys = L.Import.get () in
      let env = create_why3_env (F.to_string_list libs) in
      open_theory (env) (thys);


    end

(* -------------------------------------------------------------------------- *)
