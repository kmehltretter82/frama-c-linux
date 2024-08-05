(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let list_plugin_names () =
  Plugin.fold_on_plugins (fun p acc -> p.Plugin.p_name :: acc) []

let dump_parameter tp =
  let open Typed_parameter in
  let json_value = match tp.accessor with
    | Bool (accessor,_) -> `Bool (accessor.get ())
    | Int (accessor,_) -> `Int (accessor.get ())
    | String (accessor,_) -> `String (accessor.get ())
  in
  tp.name, json_value

let dump_all_parameters () =
  let add_category _ l acc =
    List.fold_left (fun acc tp -> dump_parameter tp :: acc) acc l
  in
  let add_plugin plugin acc =
    Hashtbl.fold add_category plugin.Plugin.p_parameters acc
  in
  Plugin.fold_on_plugins add_plugin []

let dump_to_json () =
  let string s = `String s in
  let list f l = `List (List.map f l) in
  `Assoc [
    "version", `String System_config.Version.id ;
    "codename", `String System_config.Version.codename ;
    "version_and_codename", `String System_config.Version.id_and_codename ;
    "major_version", `Int System_config.Version.major ;
    "minor_version", `Int System_config.Version.minor ;
    "is_gui", `Bool System_config.is_gui ;
    (* "lablgtk", `String System_config.lablgtk ;
     * "ocamlc", `String System_config.ocamlc ;
     * "ocamlopt", `String System_config.ocamlopt ;
     * "ocaml_wflags", `String System_config.ocaml_wflags ; *)
    "datadir", `String (System_config.Share.main:>string) ;
    "datadirs",
    list string (Filepath.Normalized.to_string_list System_config.Share.dirs) ;
    "framac_libc", `String (System_config.Share.libc:>string) ;
    "plugin_dir",
    list string (Filepath.Normalized.to_string_list System_config.Plugins.dirs) ;
    "lib_dir", `String (System_config.Lib.main:>string) ;
    "lib_dirs",
    list string (Filepath.Normalized.to_string_list System_config.Lib.dirs) ;
    "preprocessor", `String System_config.Preprocessor.command ;
    "using_default_cpp", `Bool System_config.Preprocessor.is_default ;
    "preprocessor_is_gnu_like", `Bool System_config.Preprocessor.is_gnu_like ;
    "preprocessor_supported_arch_options",
    list string System_config.Preprocessor.supported_arch_options ;
    "preprocessor_keep_comments", `Bool System_config.Preprocessor.keep_comments ;
    "current_machdep", `String (Kernel.Machdep.get ()) ;
    "machdeps", list string (File.list_available_machdeps ()) ;
    "plugins", list string (list_plugin_names ()) ;
    "parameters", `Assoc (dump_all_parameters ()) ;
  ]

let dump_to_stdout () =
  let json = dump_to_json () in
  Yojson.Basic.(pretty_to_channel stdout (sort json))

let () =
  let action () =
    if Kernel.PrintConfigJson.get () then begin
      dump_to_stdout ();
      raise Cmdline.Exit
    end else
      Cmdline.nop
  in
  Cmdline.run_after_exiting_stage action
