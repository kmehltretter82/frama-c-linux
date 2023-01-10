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
(* Supported indent formatter *)

type formatter_cmds =
  { mutable is_available : bool option ;
    available_cmd : string ;
    check_cmd: string ;
    update_cmd: string
  }

let c_indent_formatter =
  { is_available = None ;
    available_cmd = "clang-format --version > /dev/null";
    check_cmd = "clang-format --dry-run -Werror" ;
    update_cmd = "clang-format -i"
  }

let python_indent_formatter =
  { is_available = None ;
    available_cmd = "black --version > /dev/null";
    check_cmd = "black --quiet --line-length 100 --check" ;
    update_cmd = "black --quiet --line-length 100"
  }

type indent_formatter = Ocp_indent | Tool of formatter_cmds

let ml_indent_formatter = Ocp_indent

type indent_check = NoCheck | Check of indent_formatter option

let parse_indent_formatter ~file ~attr ~value = match value with
  | "unset" -> NoCheck
  | "set"   -> Check None (* use the default formatter *)
  | "ocp-indent" -> Check (Some ml_indent_formatter)
  | "clang-format" -> Check (Some (Tool c_indent_formatter))
  | "black" -> Check (Some (Tool python_indent_formatter))
  | _ -> Format.eprintf "Unsupported indent formatter: %s %s=%s@."
           file attr value;
    NoCheck

(**************************************************************************)
(* Available Checks and corresponding attributes *)

type checks =
  { eoleof : bool
  ; indent : indent_check
  ; syntax : bool
  ; utf8 : bool
  }

let no_checks =
  { eoleof = false
  ; indent = NoCheck
  ; syntax = false
  ; utf8 = false
  }

let add_attr ~file ~attr ~value checks =
  let is_set = function
    | "set" -> true
    | "unset" -> false
    | _ -> failwith (Format.sprintf "Invalid attribute value: %s %s=%s" file attr value)
  in
  match attr with
  | "check-eoleof" -> { checks with eoleof = is_set value }
  | "check-syntax" -> { checks with syntax = is_set value }
  | "check-utf8"   -> { checks with utf8 = is_set value }
  | "check-indent" -> { checks with
                        indent = parse_indent_formatter ~file ~attr ~value }
  | _ -> failwith (Format.sprintf "Unknown attribute: %s %s=%s" file attr value)

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
    Hashtbl.replace table file (add_attr ~file ~attr ~value checks) ;
    collect tl
  | [] -> ()
  | [ file ; attr ] -> Format.eprintf "Missing attribute value: %s %s=?@." file attr
  | [ file ] -> Format.eprintf "Missing attribute name for file: %s@." file

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

let is_formatter_available indent_formatter =
  match indent_formatter.is_available with
  | None ->
    let is_available = (0 = Sys.command indent_formatter.available_cmd) in
    indent_formatter.is_available <- Some is_available ;
    is_available
  | Some is_available -> is_available

exception Bad_ext

let check_indent ~indent_formatter ~update file =
  let tool = match indent_formatter with
    | Some tool -> tool
    | None -> (* uses the default formatter *)
      match Filename.extension file with
      | ".c" | ".h" -> Tool c_indent_formatter
      | ".ml" | ".mli" -> ml_indent_formatter
      | ".py" -> Tool python_indent_formatter
      | _ -> raise Bad_ext
  in match tool with
  | Ocp_indent -> check_ml_indent ~update file
  | Tool indent_formatter ->
    if not @@ is_formatter_available indent_formatter then true
    else if not update then
      0 = Sys.command (Format.sprintf "%s \"%s\"" indent_formatter.check_cmd file)
    else 0 = Sys.command (Format.sprintf "%s \"%s\"" indent_formatter.update_cmd file)

let res = ref true

(* Main checks *)

let check ~verbose ~update file params =
  if verbose then
    Format.printf "Checking %s@." file ;
  if Sys .is_directory file then ()
  else begin
    let in_chan = open_in file in
    let content = read_buffered in_chan in
    close_in in_chan ;
    (* UTF8 *)
    if params.utf8 then
      if not @@ is_utf8 content then begin
        Format.eprintf "Bad encoding (not UTF8) for %s@." file ;
        res := false
      end ;
    (* Blanks *)
    let rewrite = ref false in
    let syntactic_check checker content message  =
      let new_content, was_ok = checker ~update content in
      if update && not was_ok
      then begin rewrite := true ; new_content end
      else if not was_ok then begin
        Format.eprintf "%s for %s@." message file ;
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
    try
      begin
        match params.indent with
        | NoCheck -> ()
        | Check indent_formatter ->
          if not @@ check_indent ~indent_formatter ~update file then begin
            Format.eprintf "Bad indentation for %s@." file ;
            res := false
          end ;
      end ;
    with Bad_ext ->
      Format.eprintf "Don't know how to (check) indent %s@." file ;
      res := false
  end

(**************************************************************************)
(* Options *)

let exec_name = Sys.argv.(0)
let update = ref false
let verbose = ref false

let argspec = [
  "-u", Arg.Set update, " update ill-formed files (does not handle UTF8 update)" ;
  "-v", Arg.Set verbose, " verbose mode" ;
]
let sort argspec =
  List.sort (fun (name1, _, _) (name2, _, _) -> String.compare name1 name2)
    argspec

(**************************************************************************)
(* Main *)

let () =
  if not @@ is_formatter_available c_indent_formatter then
    Format.eprintf "clang-format unavailable, I will not check C files@." ;
  if not @@ is_formatter_available python_indent_formatter then
    Format.eprintf "black unavailable, I will not check Python files@." ;
  Arg.parse
    (Arg.align (sort argspec))
    (fun s -> Format.eprintf "Unknown argument: %s" s)
    ("Usage: git ls-files -z | git check-attr --stdin -z -a | " ^ exec_name ^ " [options]");
  collect @@ lines_from_in stdin ;
  Hashtbl.iter (check ~verbose:!verbose ~update:!update) table ;
  if not !res then exit 1
