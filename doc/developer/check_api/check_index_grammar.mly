/**************************************************************************/
/*                                                                        */
/*  This file is part of Frama-C.                                         */
/*                                                                        */
/*  Copyright (C) 2007-2024                                               */
/*    CEA (Commissariat à l'énergie atomique et aux énergies              */
/*         alternatives)                                                  */
/*                                                                        */
/*  you can redistribute it and/or modify it under the terms of the GNU   */
/*  Lesser General Public License as published by the Free Software       */
/*  Foundation, version 2.1.                                              */
/*                                                                        */
/*  It is distributed in the hope that it will be useful,                 */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*  GNU Lesser General Public License for more details.                   */
/*                                                                        */
/*  See the GNU Lesser General Public License version 2.1                 */
/*  for more details (enclosed in the file licenses/LGPLv2.1).            */
/*                                                                        */
/**************************************************************************/

%{
%}
%token <string> WORD
%token KWD_WITH_ARG
%token KWD_WITH_DOUBLE_ARGS
%token EOL
%token EOF
%token LPAR
%token RPAR
%token ENTRY
%token <string> STRING
%start main
%type <string> main
%nonassoc lowest
%nonassoc EOL WORD KWD_WITH_DOUBLE_ARGS
%nonassoc highest
%%
main:
 | file EOF                                             { $1 }
 | filtered_string EOF                                  { $1 }
filtered_string: STRING                                 { $1 }
 | STRING filtered_string                      { $1 ^ $2 }

mult_eol: EOL                                           { "" }
 | EOL mult_eol %prec highest                           { "" }

mult_word:
 | WORD       %prec lowest      { $1 }
 | WORD mult_word  %prec highest { $1 ^ " " ^ $2 }
 | KWD_WITH_DOUBLE_ARGS LPAR WORD RPAR LPAR WORD RPAR mult_word %prec highest
     { (* the keyword and the 2 integer arguments are ignored *)
       $8 }

bracket_word: LPAR mult_word RPAR                       { $2 }

string_with_bracket: mult_word                          { $1 }
 | bracket_word                                         { $1 }
 | mult_word string_with_bracket                        { $1 ^ $2 }
 | LPAR KWD_WITH_ARG string_with_bracket RPAR           { "" }
 | LPAR RPAR                                            { "" }

file: line                                              { $1 }
 | file mult_eol   %prec lowest                         { $1 }
 | file mult_eol file          %prec lowest             { $1 ^ $3 }

piece: mult_word KWD_WITH_ARG bracket_word              { $1 }

mult_piece:
 | piece              { $1 }
 | piece mult_piece   { $1 ^ " " ^ $2 }

line:
 | ENTRY LPAR string_with_bracket RPAR bracket_word   { "" }
 | ENTRY LPAR mult_piece RPAR bracket_word            { $3 ^ "\n" }
 | ENTRY LPAR mult_piece LPAR RPAR RPAR bracket_word  { $3 ^ "\n" }
