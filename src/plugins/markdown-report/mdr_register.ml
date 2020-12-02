(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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

let load_eva_info () =
  if not !Md_gen.Eva_info.loaded then begin
    let eva_info = "top/eva_info.cmo" in
    try
      List.iter
        (fun dir ->
           let path = dir ^ "/" ^ eva_info in
           if Sys.file_exists path then begin
             Dynamic.load_module (dir ^ "/" ^ eva_info);
             (* do not try to load it twice. *)
             raise Exit
           end)
        Fc_config.plugin_dir;
      Mdr_params.warning "Impossible to load Eva-specific operations"
    with Exit -> ()
  end

(*  end *)

let main () =
  match Mdr_params.Generate.get () with
  | "none" -> ()
  | "md" -> Md_gen.gen_report ~draft:false ()
  | "draft" -> Md_gen.gen_report ~draft:true ()
  | "sarif" -> Sarif_gen.generate ()
  | s ->
    Mdr_params.fatal "Unexpected value for option %s: %s"
      Mdr_params.Generate.option_name s

let () =
  Cmdline.run_after_extended_stage load_eva_info;
  Db.Main.extend main
