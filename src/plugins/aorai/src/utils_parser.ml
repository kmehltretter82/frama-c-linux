(******************************************************************************)
(*                                                                            *)
(*  SPDX-License-Identifier LGPL-2.1                                          *)
(*  Copyright (C)                                                             *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)      *)
(*  INRIA (Institut National de Recherche en Informatique et en Automatique)  *)
(*  INSA (Institut National des Sciences Appliquees)                          *)
(*                                                                            *)
(******************************************************************************)

open Lexing

let abort_current lex fmt =
  let loc = Fileloc.of_lexing_loc (lexeme_start_p lex, lexeme_end_p lex) in
  let fmt = "before or at token %s@\n%a@\n" ^^ fmt in
  Aorai_option.abort fmt
    (Lexing.lexeme lex)
    (Errorloc.pp_context_from_file ~ctx:2) loc

let unknown_token lex =
  abort_current lex
    "Unexpected character: '%c'" (lexeme_char lex (lexeme_start lex))

let newline lexbuf =
  let pos = lexbuf.lex_curr_p in
  lexbuf.lex_curr_p <-
    { pos with pos_lnum = pos.pos_lnum + 1; pos_bol = pos.pos_cnum }

let unterminated_comment lexbuf =
  abort_current lexbuf
    "Unterminated C comment"
