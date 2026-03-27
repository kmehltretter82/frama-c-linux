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
  mutable current_origin : Filepos.t option;
  origins : Filepos.t Datatype.Int.Hashtbl.t;
}

let current = ref None

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
    let path = Filepath.of_string fname in
    match Parse_env.open_source ~scan_references path with
    | Error msg -> Kernel.fatal "%s" msg
    | Ok in_str ->
      let lexbuf = Lexing.from_string in_str in
      let menhir_pos, lexer = MenhirLib.ErrorReports.wrap lexer in
      (* Initialize lexer buffer. *)
      lexbuf.Lexing.lex_curr_p <-
        { Lexing.pos_fname = Filepath.to_string_abs path;
          Lexing.pos_lnum  = 1;
          Lexing.pos_bol   = 0;
          Lexing.pos_cnum  = 0
        };
      current := Some
          { lexbuf;
            menhir_pos;
            current_working_directory = None;
            current_origin = None;
            origins = Datatype.Int.Hashtbl.create 100;
          };
      lexbuf, lexer

let finishParsing () =
  match !current with
  | None -> Kernel.fatal "Parsing called while lexbuf is empty"
  | Some _ -> current := None

let update_origins current =
  let line = current.lexbuf.lex_curr_p.pos_lnum in
  let add_origin = Datatype.Int.Hashtbl.replace current.origins line in
  Option.iter add_origin current.current_origin

(* Call this function to announce a new line *)
let newline () =
  let current = Option.get !current in
  Lexing.new_line current.lexbuf;
  current.current_origin <- Option.map Filepos.incr_line current.current_origin;
  update_origins current

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

let setCurrentLine ?(filename: string option) (line: int) =
  let current = Option.get !current in
  match filename with
  | Some filename ->
    let base = current.current_working_directory in
    let path = Filepath.of_string ?base filename in
    if not (is_special_file filename) && not (Filesystem.exists path) then
      (* do not change line number if directive refers to non-existing file *)
      Kernel.warning ~wkey:Kernel.wkey_line_directive ~once:true
        "ignoring non-existing file '%a', referenced in a line directive"
        Filepath.pretty path
    else
      let new_origin = match current.current_origin with
        | Some origin -> Filepos.update_line ~path ~line origin
        | None -> Filepos.make ~path ~line ()
      in
      current.current_origin <- Some new_origin;
      update_origins current
  | None ->
    match current.current_origin with
    | None ->
      (* Some test use #line directive to reduce changes in non-regression
         tests. We update the current line to support this behavior, but the
         position is likely meaningless. *)
      current.lexbuf.lex_curr_p <-
        { current.lexbuf.lex_curr_p with
          pos_lnum = line;
          pos_bol = current.lexbuf.lex_curr_p.pos_cnum;
        };
    | Some origin ->
      let new_origin = Filepos.update_line ~line origin in
      current.current_origin <- Some new_origin;
      update_origins current

let convert_pos pos =
  let open Option.Operators in
  let origin =
    let* current = !current in
    let line = pos.Lexing.pos_lnum in
    let+ origin = Datatype.Int.Hashtbl.find_opt current.origins line in
    Filepos.Preprocessed origin
  in
  Filepos.of_lexing_pos ?origin pos

let convert_loc (pos_start, pos_end) =
  convert_pos pos_start, convert_pos pos_end

(* Prints the line(s) between start_pos and pos,
   plus up to [ctx] lines before and after (if they exist),
   similar to 'grep -C<ctx>'.
   Most exceptions are silently caught and printing is stopped if they occur. *)
let pp_context_from_file ?(ctx=2) fmt (start_pos, pos) =
  let open Filesystem.Operators in
  (* We cannot give any context on unknown locations *)
  if not (Filepos.is_known start_pos) then ()
  else
    let start_pos =
      if Filepath.equal (Filepos.path start_pos) (Filepos.path pos)
      then start_pos
      else pos
    in
    try
      let$ in_ch = Filesystem.with_open_in_exn (Filepos.path pos) in
      let first_error_line = min (Filepos.line start_pos) (Filepos.line pos)
      and last_error_line = max (Filepos.line start_pos) (Filepos.line pos)
      and start_char = Filepos.input_column start_pos
      and end_char = Filepos.input_column pos
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
          let len = end_char - start_char + 1 in
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

let pp_location = Fileloc.pretty_line_range

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
        convert_loc (current.lexbuf.lex_start_p, current.lexbuf.lex_curr_p)
      else
        let _,start_pos = Stack.pop all_pos in
        let last_pos =
          if Stack.is_empty all_pos then
            current.lexbuf.Lexing.lex_curr_p
          else
            fst (Stack.pop all_pos)
        in
        convert_loc (start_pos, last_pos)
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
              Fileloc.pretty_line_range loc
              pretty_token (Lexing.lexeme current.lexbuf);
            Format.fprintf fmt "%a@."
              (pp_context_from_file ~ctx:2) loc);
      raise (Log.AbortError "kernel"))
    msg


(* More parsing support functions: line, file, char count *)
let currentLoc () =
  let current = Option.get !current in
  let start_pos = Lexing.lexeme_start_p current.lexbuf
  and end_pos = Lexing.lexeme_end_p current.lexbuf in
  convert_loc (start_pos, end_pos)


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
