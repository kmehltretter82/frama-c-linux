(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

open CamomileLibrary

(**************************************************************************)
(* Utils *)

let read_buffered channel =
  let buffer = Buffer.create 0 in
  let size = 4096 in
  let load = Bytes.create size in
  let read = ref @@ input channel load 0 size in
  while !read <> 0 do
    Buffer.add_subbytes buffer load 0 !read ;
    read := input channel load 0 size
  done ;
  Buffer.to_bytes buffer

let rec lines_from_buffer acc buffer start =
  if start = Bytes.length buffer then acc
  else
    let line_end = Bytes.index_from buffer start '\000' in
    let len = line_end - start in
    let line = Bytes.sub_string buffer start len in
    lines_from_buffer (line :: acc) buffer (line_end + 1)

let lines_from_in channel =
  let content = read_buffered channel in
  let acc = lines_from_buffer [] content 0 in
  List.rev acc

(**************************************************************************)
(* Available Checks and corresponding attributes *)

type checks =
  { eoleof : bool
  ; indent : bool
  ; syntax : bool
  ; utf8 : bool
  }

let no_checks =
  { eoleof = false
  ; indent = false
  ; syntax = false
  ; utf8 = false
  }

let add_attr checks attr value =
  let value = value = "set" in
  match attr with
  | "check-eoleof" -> { checks with eoleof = value }
  | "check-indent" -> { checks with indent = value }
  | "check-syntax" -> { checks with syntax = value }
  | "check-utf8"   -> { checks with utf8 = value }
  | _ -> failwith (Printf.sprintf "Unknown attr %s" attr)

let handled_attr s =
  s = "check-eoleof" || s = "check-indent" ||
  s = "check-syntax" || s = "check-utf8"

let ignored_attr s =
  not (handled_attr s)

(**************************************************************************)
(* Table of the files to control *)

let table = Hashtbl.create 1031

let get file =
  try Hashtbl.find table file
  with Not_found -> no_checks

let rec collect = function
  | _file :: attr :: _value :: tl when ignored_attr attr ->
    collect tl
  | file :: attr :: value :: tl ->
    let checks = get file in
    Hashtbl.replace table file (add_attr checks attr value) ;
    collect tl
  | [] -> ()
  | l -> List.iter (Printf.eprintf "Could not load file list %s\n") l

(**************************************************************************)
(* Functions used to check lint *)

(* UTF8 *)

let is_utf8 content =
  try UTF8.validate (Bytes.to_string content) ; true
  with UTF8.Malformed_code -> false

(* Syntax *)

let check_syntax ~update content =
  let size = Bytes.length content in
  let out = Buffer.create 0 in
  let exception Bad_syntax in
  try
    let i = ref 0 in
    let blank = ref (-1) in
    while !i < size do
      let byte = Bytes.get content !i in
      if byte = '\t' then begin
        if not update then raise Bad_syntax ;
        if !blank = -1 then blank := Buffer.length out ;
        Buffer.add_string out "  "
      end
      else if byte = ' ' then begin
        if !blank = -1 then blank := Buffer.length out ;
        Buffer.add_char out ' '
      end
      else if byte = '\n' && !blank <> -1 then begin
        if not update then raise Bad_syntax ;
        Buffer.truncate out !blank ;
        Buffer.add_char out '\n' ;
        blank := -1
      end
      else begin
        Buffer.add_char out byte ;
        blank := -1
      end ;
      incr i
    done ;
    if !blank <> -1 then
      Buffer.truncate out !blank ;
    let out = Buffer.to_bytes out in
    if not @@ Bytes.equal out content
    then out, false
    else content, true
  with Bad_syntax ->
    content, false

(* EOL/EOF *)

let check_eoleof ~update content =
  let length = Bytes.length content in
  if length = 0 then content, true
  else if '\n' = Bytes.get content (length - 1) then content, true
  else if update then begin
    let new_content = Bytes.extend content 0 1 in
    Bytes.set new_content length '\n' ;
    new_content, false
  end else
    content,false

(* Indentation *)

(* ML(I) *)

(* Basically this is OCP-Indent main where all elements related to options have
   been removed and the printer changed so that it prints into a buffer and not
   a file.
*)

let global_config = ref None
let config () =
  match !global_config with
  | None ->
    let config, syntaxes, dlink = IndentConfig.local_default () in
    IndentLoader.load ~debug:false dlink ;
    Approx_lexer.disable_extensions ();
    List.iter
      (fun stx ->
         try Approx_lexer.enable_extension stx
         with IndentExtend.Syntax_not_found name ->
           Format.eprintf "Warning: unknown syntax extension %S@." name)
      syntaxes ;
    global_config := Some config ;
    config
  | Some config -> config

let ocp_indent channel =
  let config = config () in
  let buffer = Buffer.create 0 in
  let out = IndentPrinter.{
      debug = false; config = config; indent_empty = false; adaptive = true;
      in_lines = (fun _ -> true);
      kind = Print (fun s b -> Buffer.add_string b s ; b);
    }
  in
  let stream = Nstream.of_channel channel in
  Buffer.to_bytes (IndentPrinter.proceed out stream IndentBlock.empty buffer)

let check_ml_indent ~update file =
  let input = open_in file in
  let original = read_buffered input in
  seek_in input 0 ;
  let modified = ocp_indent input in
  close_in input ;
  let result = Bytes.equal original modified in
  if update && not result then
    let output = open_out file in
    output_bytes output modified ;
    close_out output ;
    true
  else
    result

(* C/H *)

let check_c_indent ~update file =
  let opt = if update then "-i" else "--dry-run -Werror" in
  0 = Sys.command (Printf.sprintf "clang-format %s \"%s\"" opt file)

exception Bad_ext

let check_indent ~update file =
  match Filename.extension file with
  | ".c" | ".h" -> check_c_indent ~update file
  | ".ml" | ".mli" -> check_ml_indent ~update file
  | _ -> raise Bad_ext

let res = ref true

(* Main checks *)

let check ~verbose ~update file params =
  if verbose then
    Printf.printf "Checking %s\n" file ;
  if Sys.is_directory file then ()
  else begin
    let in_chan = open_in file in
    let content = read_buffered in_chan in
    close_in in_chan ;
    (* UTF8 *)
    if params.utf8 then
      if not @@ is_utf8 content then begin
        Printf.eprintf "Bad encoding (not UTF8) for %s\n" file ;
        res := false
      end ;
    (* Blanks *)
    let rewrite = ref false in
    let syntactic_check checker content message  =
      let new_content, was_ok = checker ~update content in
      if update && not was_ok
      then begin rewrite := true ; new_content end
      else if not was_ok then begin
        Printf.eprintf "%s for %s\n" message file ;
        res := false ; new_content
      end
      else new_content
    in
    let content =
      if params.syntax
      then syntactic_check check_syntax content "Bad syntax"
      else content
    in
    let content =
      if params.eoleof || params.syntax
      then syntactic_check check_eoleof content "Bad EOF"
      else content
    in
    if !rewrite then begin
      let out_chan = open_out file in
      output_bytes out_chan content ;
      close_out out_chan
    end ;
    (* Indentation *)
    if params.indent then
      if not @@ check_indent ~update file then begin
        Printf.eprintf "Bad indentation for %s\n" file ;
        res := false
      end ;
  end

(**************************************************************************)
(* Options *)

let exec_name = Sys.argv.(0)
let update = ref false
let verbose = ref false

let rec argspec = [
  "--help", Arg.Unit print_usage, "print this option list and exits" ;
  "-u", Arg.Set update, "update ill-formed files (does not handle UTF8 update)" ;
  "-v", Arg.Set verbose, "verbose mode" ;
]
and sort argspec =
  List.sort (fun (name1, _, _) (name2, _, _) -> String.compare name1 name2)
    argspec
and print_usage () =
  Arg.usage
    (Arg.align (sort argspec))
    (Printf.sprintf "Usage: %s [-u]" exec_name) ;
  exit 0

(**************************************************************************)
(* Main *)

let () =
  Arg.parse
    (Arg.align (sort argspec))
    (fun s -> Printf.eprintf "Unknown argument: %s" s)
    "";
  collect @@ lines_from_in stdin ;
  Hashtbl.iter (check ~verbose:!verbose ~update:!update) table ;
  if not !res then exit 1
