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

{
}

let alphanum = ['A'-'Z''a'-'z''0'-'9''_']
let lower_name = ['a'-'z'] alphanum*
(* in order to discriminate with other code keywords, we assume that an
   OCaml module referenced in the LaTeX index is either a single letter
   or has a lower case letter or an underscore as second character. *)
let upper_name = ['A'-'Z'] ['a'-'z''_'] alphanum*

rule token = parse
| "\\texttt"                               { Check_index_grammar.KWD_WITH_ARG }
| "\\see"                                  { Check_index_grammar.KWD_WITH_ARG }
| "\\fontsize"                     { Check_index_grammar.KWD_WITH_DOUBLE_ARGS }
| [ ' ' '\t' '|' '!' '@' '$' ]             { token lexbuf }
| '{'                                      { Check_index_grammar.LPAR }
| '}'                                      { Check_index_grammar.RPAR }
| [ '\n' '\r' ]                            { Check_index_grammar.EOL }
| "\\indexentry"                           { Check_index_grammar.ENTRY }
(* ignore argument free keywords *)
| "\\selectfont"                           { token lexbuf }
| "hyperpage"                              { token lexbuf }
| "hyperindexformat"                       { token lexbuf }
| "\\bfit"                                 { token lexbuf }
| [ ^ '\n' '\r' ' ' '{' '}' '!' '|' '@' '$' ]*
    { Check_index_grammar.WORD (Lexing.lexeme lexbuf) }
| eof                                      { Check_index_grammar.EOF }
| _ as c                           { Format.eprintf "%c@." c; assert false }

and token_2 = parse
  | '\n'* ' '* [ 'a'-'z' '-' '.' ]+[ ^ '\n' ]*                                              { token_2 lexbuf }
  | '\n'* ' '* ([ 'A'-'Z' ][ 'a'-'z' '-' '_' '.' ]+ ' '* )+ ['A'-'Z'][^ 'a'-'z' '\n']+      { token_2 lexbuf }
  | '\n'* ' '* ((upper_name ' '*)+ lower_name ' '* (upper_name ' '*)?) {
      Check_index_grammar.STRING (Lexing.lexeme lexbuf)
   }
  | '\n'* ' '* [ 'A'-'Z' '_' '-' ]+ [ ^ '\n' ]*                                     { token_2 lexbuf }
  | '\n'* eof                                                                       { Check_index_grammar.EOF }
