(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- External Driver                                                    --- *)
(* -------------------------------------------------------------------------- *)

{

  open Lexing
  open Cil_types
  open LogicBuiltins

  type token =
    | EOF
    | KEY of string
    | BOOLEAN
    | INTEGER
    | REAL
    | INT of ikind
    | FLT of fkind
    | KIND of kind
    | ID of string
    | LINK of string

  let keywords = [
    "library" , KEY "library" ;
    "type" , KEY "type" ;
    "ctor" , KEY "ctor" ;
    "logic" , KEY "logic" ;
    "predicate" , KEY "predicate" ;
    "boolean" , BOOLEAN ;
    "integer" , INTEGER ;
    "real" , REAL ;
    "char" , INT IChar ;
    "short" , INT IShort ;
    "int" , INT IInt ;
    "unsigned" , INT IUInt ;
    "float" , FLT FFloat ;
    "float32" , KIND (F Ctypes.Float32) ;
    "float64" , KIND (F Ctypes.Float64) ;
    "double" , FLT FDouble ;
  ]

  let ident x = try List.assoc x keywords with Not_found -> ID x

}

let blank = [ ' ' '\t' '\r' ]
let ident = '\\'? [ 'a'-'z' 'A'-'Z' '_' '0'-'9' ]+

rule tok = parse
    eof { EOF }
  | '\n' { new_line lexbuf ; tok lexbuf }
  | blank+ { tok lexbuf }
  | "//" [^ '\n']* '\n' { new_line lexbuf ; tok lexbuf }
  | "/*" { comment lexbuf }
  | ident as a { ident a }
  | '"' { LINK (string_val (Buffer.create 10) lexbuf) }
  | _ | ":=" | "+=" { KEY (Lexing.lexeme lexbuf) }

and comment = parse
  | eof { failwith "Unterminated comment" }
  | "*/" { tok lexbuf }
  | '\n' { new_line lexbuf ; comment lexbuf }
  | _ { comment lexbuf }

and string_val buf = parse
  | '"' { Buffer.contents buf;}
  | [^ '\\' '"'] as c
      { Buffer.add_char buf c;
        string_val buf lexbuf }
  | '\\' (['\\' '"' 'n' 'r' 't'] as c)
      { Buffer.add_char buf
          (match c with 'n' -> '\n' | 'r' -> '\r' | 't' -> '\t' | _ -> c);
        string_val buf lexbuf }
  | '\\' '\n'
      { new_line lexbuf ; string_val buf lexbuf }
  | '\\' (_ as c)
      { Buffer.add_char buf '\\';
        Buffer.add_char buf c;
        string_val buf lexbuf }
  | eof
      { failwith "Unterminated string" }

{

}
