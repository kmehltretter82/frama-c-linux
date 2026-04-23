(***************************************************************************)
(*                                                                         *)
(*  SPDX-License-Identifier BSD-3-Clause                                   *)
(*  Copyright (C) 2001-2003                                                *)
(*  George C. Necula    <necula@cs.berkeley.edu>                           *)
(*  Scott McPeak        <smcpeak@cs.berkeley.edu>                          *)
(*  Wes Weimer          <weimer@cs.berkeley.edu>                           *)
(*  Ben Liblit          <liblit@cs.berkeley.edu>                           *)
(*  All rights reserved.                                                   *)
(*  File modified by                                                       *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)   *)
(*  INRIA (Institut National de Recherche en Informatique et Automatique)  *)
(*                                                                         *)
(***************************************************************************)

(* Copied and modified from [cil/src/errormsg.ml] *)

(***** Handling parsing errors ********)
type parseinfo = {
  lexbuf : Lexing.lexbuf;
  menhir_pos: (Lexing.position * Lexing.position) MenhirLib.ErrorReports.buffer;
  mutable current_working_directory : Filepath.t option;
}

let current = ref None

(* Used to temporarily store current line before knowing the current file *)
let currentLine = ref None

let startParsing fname lexer =
  (* We only support one open file at a time *)
  match !current with
  | Some { lexbuf } ->
    Kernel.fatal
      "[Errorloc.startParsing] supports only one open file: \
       You want to open %S and %S is still open"
      fname (Lexing.lexeme_start_p lexbuf).Lexing.pos_fname
  | None ->
    let scan_references = Kernel.EagerLoadSources.get () in
    let filepath = Filepath.of_string fname in
    match Parse_env.open_source ~scan_references filepath with
    | Error msg -> Kernel.fatal "%s" msg
    | Ok in_str ->
      let lexbuf = Lexing.from_string in_str in
      let menhir_pos, lexer = MenhirLib.ErrorReports.wrap lexer in
      let i = { lexbuf; menhir_pos; current_working_directory = None } in
      (* Initialize lexer buffer. *)
      lexbuf.Lexing.lex_curr_p <-
        { Lexing.pos_fname = Filepath.to_string_abs filepath;
          Lexing.pos_lnum  = 1;
          Lexing.pos_bol   = 0;
          Lexing.pos_cnum  = 0
        };
      current := Some i;
      lexbuf, lexer

let finishParsing () =
  match !current with
  | None -> Kernel.fatal "Errorloc.finishParsing called while lexbuf is empty"
  | Some _ -> current := None

(* Call this function to announce a new line *)
let newline () =
  let current = Option.get !current in
  if !currentLine <> None then begin
    (* line directive without file name; update line number *)
    let pos = current.lexbuf.Lexing.lex_curr_p in
    current.lexbuf.Lexing.lex_curr_p <-
      { pos with
        Lexing.pos_lnum = Option.get !currentLine;
        Lexing.pos_bol = pos.Lexing.pos_cnum;
      };
    currentLine := None
  end;
  Lexing.new_line current.lexbuf

let setCurrentLine (i: int) =
  currentLine := Some i

let setCurrentWorkingDirectory fp =
  let current = Option.get !current in
  current.current_working_directory <- Some fp

(* preprocessors tend to use '<xxx>' filenames in line directives to
   denote special locations, e.g. builtin or command-line-defined macros.
   Worse, this can get localized. We are thus a bit liberal in what we
   consider special filenames.
*)
let is_special_file n =
  let len = String.length n in
  (* not sure an empty string can realistically happen here,
     but it can't hurt to check. *)
  len = 0 || n.[0] = '<' && n.[len-1] = '>'

let setCurrentFile n =
  let current = Option.get !current in
  let base = current.current_working_directory in
  let norm = Filepath.of_string ?base n in
  if not (is_special_file n) && not (Filesystem.exists norm)
  then begin
    currentLine := None;
    Kernel.warning ~wkey:Kernel.wkey_line_directive ~once:true
      "ignoring non-existing file '%a', referenced in a line directive"
      Filepath.pretty norm
  end else begin
    let pos = current.lexbuf.Lexing.lex_curr_p in
    current.lexbuf.Lexing.lex_curr_p <- {
      pos with Lexing.pos_fname = Filepath.to_string_abs norm;
               Lexing.pos_lnum = (Option.get !currentLine);
               Lexing.pos_bol = pos.Lexing.pos_cnum;
    }
  end

(* Prints the line(s) between start_pos and pos,
   plus up to [ctx] lines before and after (if they exist),
   similar to 'grep -C<ctx>'.
   Most exceptions are silently caught and printing is stopped if they occur. *)
let pp_context_from_file ?(ctx=2) fmt ((start_pos, pos) as loc) =
  let open Filesystem.Operators in
  (* We cannot give any context on unknown locations *)
  if Cil_datatype.Location.is_unknown loc then ()
  else
    let start_pos =
      if Filepath.equal start_pos.pos_path pos.pos_path
      then start_pos
      else pos
    in
    try
      let$ in_ch = Filesystem.with_open_in_exn pos.pos_path in
      let first_error_line, start_char, last_error_line =
        min start_pos.pos_lnum pos.pos_lnum,
        (start_pos.pos_cnum - start_pos.pos_bol),
        max start_pos.pos_lnum pos.pos_lnum
      in

      (** Add an offset to the starting position if we're not on the first column.
          This is used to underline only the problem and not its preceding
          character, for example :
          [
            Cannot resolve variable y
              int x = t[y];
                       ^^
            (* becomes *)
            Cannot resolve variable y
              int x = t[y];
                        ^
          ]
          Since there are no preceding character when the error starts on the
          first column, we do not need an offset.
      *)
      let start_char = if start_char = 1 then start_char else start_char + 1 in

      (* The difference between the first and last error lines can be very
          large; in this case, we print only the first and last [error_ctx]
          lines, with "..." between them. *)
      let first_to_print = max (first_error_line-ctx) 1 in
      let last_to_print = last_error_line+ctx in
      let error_ctx = 3 in
      let error_height = last_error_line - first_error_line + 1 in
      let compress_error = error_height > 2 * error_ctx + 1 + 2 in
      let i = ref 1 in
      try
        (* advance to line *)
        while !i < first_to_print do
          ignore (input_line in_ch);
          incr i
        done;
        (* print context before first error line *)
        while !i < first_error_line do
          let line = input_line in_ch in
          Format.fprintf fmt "%-6d%s\n" !i line;
          incr i
        done;
        (* if more than one line of context, print blank line *)
        if last_error_line <> first_error_line then
          Format.fprintf fmt "\n";
        (* print error lines *)
        while !i <= last_error_line do
          let line = input_line in_ch in
          if compress_error && !i = first_error_line + error_ctx then
            Format.fprintf fmt "%d-%d [... omitted ...]\n"
              (first_error_line + error_ctx) (last_error_line - error_ctx)
          else if compress_error && !i > first_error_line + error_ctx &&
                  !i <= last_error_line - error_ctx then
            () (* ignore line *)
          else begin
            Format.fprintf fmt "%-6d%s\n" !i line;
          end;
          incr i
        done;
        (* if more than one line of context, print blank line,
            otherwise print arrows *)
        if last_error_line <> first_error_line then
          Format.fprintf fmt "\n"
        else begin
          let len = pos.pos_cnum - pos.pos_bol - start_char + 1 in
          (* output at least one '^' *)
          let len = if len <= 0 then 1 else len in
          let cursor =
            String.make 6 ' ' ^
            String.make (start_char - 1) ' ' ^
            String.make len '^'
          in
          Format.fprintf fmt "%s\n" cursor
        end;
        while !i <= last_to_print do
          let line = input_line in_ch in
          Format.fprintf fmt "%-6d%s\n" !i line;
          incr i
        done;
      with End_of_file ->
        if !i <= last_error_line then (* could not reach line, print warning *)
          Kernel.warning "end of file reached before line %d" last_error_line
        else (* context after line n, no warning *) ()
    with Sys_error _ -> ()

let pp_location = Cil_datatype.Location.pretty_line_range

let parse_error ?loc msg =
  let current = Option.get !current in
  (* there are cases when we are called before menhir has requested at
     least two tokens, ending up in an assertion failure. Unfortunately,
     ErrorReports API does not allow us to check whether the buffer is
     empty or not.
  *)
  let all_pos = Stack.create() in
  let () =
    (* this is absolutely not a hack and used MenhirLib exactly as intended. *)
    try
      let pp loc = Stack.push loc all_pos; "" in
      ignore (MenhirLib.ErrorReports.show pp current.menhir_pos)
    with _ -> ()
  in
  let loc =
    match loc with
    | Some loc -> loc
    | None ->
      if Stack.is_empty all_pos then
        Cil_datatype.Location.of_lexing_loc
          (current.lexbuf.Lexing.lex_start_p, current.lexbuf.Lexing.lex_curr_p)
      else
        let _,start_pos = Stack.pop all_pos in
        let last_pos =
          if Stack.is_empty all_pos then
            current.lexbuf.Lexing.lex_curr_p
          else
            fst (Stack.pop all_pos)
        in
        Cil_datatype.Location.of_lexing_loc (start_pos, last_pos)
  in
  let pretty_token fmt token =
    (* prints more detailed information around the erroneous token;
       due to the fact that some tokens are normalized (e.g. single-line ACSL
       comments), we blacklist them to avoid confusing the user *)
    let blacklist = ["*/"] in
    if List.mem token blacklist then ()
    else
      Format.fprintf fmt ", before or at token: %s" token
  in
  Format.kasprintf (fun str ->
      Kernel.feedback ~source:(fst loc) "%s:@." str
        ~append:(fun fmt ->
            Format.fprintf fmt "Location: %a%a\n"
              Cil_datatype.Location.pretty_line_range loc
              pretty_token (Lexing.lexeme current.lexbuf);
            Format.fprintf fmt "%a@."
              (pp_context_from_file ~ctx:2) loc);
      raise (Log.AbortError "kernel"))
    msg


(* More parsing support functions: line, file, char count *)
let currentLoc () =
  let i = Option.get !current in
  Cil_datatype.Location.of_lexing_loc
    (Lexing.lexeme_start_p i.lexbuf, Lexing.lexeme_end_p i.lexbuf)


(** Handling of errors during parsing *)

let abort_context ?(loc=Current_loc.get ()) msg =
  let append fmt =
    Format.pp_print_newline fmt ();
    pp_context_from_file fmt loc
  in
  Kernel.abort ~source:(fst loc) ~append msg

let hadErrors = ref false
let had_errors () = !hadErrors
let clear_errors () = hadErrors := false

let set_error (_:Log.event) = hadErrors := true

let () =
  Kernel.register Log.Error set_error;
  Kernel.register Log.Failure set_error
