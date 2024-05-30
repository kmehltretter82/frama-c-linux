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

(* Script used to generate the interface file Eva.mli from other .mli files,
   given as argument of this script. *)

let usage_msg = Sys.argv.(0) ^ " <file1.mli> [<file2.mli>] ..."

let fail =
  Printf.kfprintf (fun _ -> exit 1) stderr

let file_contents filename =
  let input = open_in_bin filename in
  let contents = really_input_string input (in_channel_length input) in
  close_in input;
  contents

let extract_exported_interface s =
  let regexp =
    Str.regexp "\\[@@@ api_start\\]\\(\\(.\\|\n\\)*\\)\\[@@@ api_end\\]"
  in
  let rec iter acc i =
    match Str.search_forward regexp s i with
    | i ->
      let subpart = Str.matched_group 1 s in
      iter (acc ^ subpart) (i + String.length subpart)
    | exception Not_found -> acc
  in
  String.trim (iter "" 0)

let indent s =
  Str.(global_replace (regexp "^.+$") ("  \\0") s) ^ "\n"

let generate_api input_files =
  let mli_out = open_out "Eva.mli"
  and ml_out = open_out "Eva.ml"
  in
  let add_file filename =
    let contents = file_contents filename in
    match Filename.extension filename with
    | ".header" ->
      output_string mli_out contents;
      output_string mli_out "(* This file is generated. Do not edit. *)\n";
      output_string ml_out contents;
      output_string ml_out "(* This file is generated. Do not edit. *)\n\n";
    | ".mli" ->
      let module_name =
        String.capitalize_ascii Filename.(basename filename |> chop_extension)
      in
      Printf.fprintf mli_out "\n";
      Printf.fprintf mli_out "module %s: sig\n" module_name;
      output_string mli_out (indent (extract_exported_interface contents));
      Printf.fprintf mli_out "end\n";
      Printf.fprintf ml_out "module %s = %s\n" module_name module_name;
    | extension ->
      fail "unrecognized extension: %s\n" extension
  in
  List.iter add_file input_files;
  close_out mli_out;
  close_out ml_out

let () =
  let input_files = ref [] in
  let add_file name = input_files := name :: !input_files in
  let specs = [] in
  Arg.parse specs add_file usage_msg;
  generate_api (List.rev !input_files)
