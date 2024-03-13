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
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

(* -------------------------------------------------------------------------- *)

let create_why3_env =
    begin fun () ->
      W.Env.create_env (WConf.loadpath (WConf.get_main (WConf.read_config None)))
    end

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
      let env = create_why3_env () in
      List.iter
      (fun thy ->
         let ns = (P.read_module env (F.to_string_list libs) thy).mod_export in
         let _t = List.map (fun (ity : W.Ity.itysymbol) -> ity.its_ts) (W.Wstdlib.Mstr.values (ns.ns_ts)) in
         List.iter (
          fun _ty ->
            match W.Ty.ts_hash _ty with
            | 1 -> L.debug "NoDef %s@." thy
            | _ -> L.debug "Otr %s@." thy
         ) _t;
      ) thys ;
      (* let _ns = (P.read_module env (F.to_string_list libs) (List.hd thys)).mod_export in
      L.debug ""; *)


    end

(* -------------------------------------------------------------------------- *)
