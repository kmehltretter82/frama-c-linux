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
    | FIELD of string * string

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

  let newline lexbuf =
    lexbuf.lex_curr_p <-
      { lexbuf.lex_curr_p with pos_lnum = succ lexbuf.lex_curr_p.pos_lnum }

}

let blank = [ ' ' '\t' '\r' ]
let ident = '\\'? [ 'a'-'z' 'A'-'Z' '_' '0'-'9' ]+

rule tok = parse
    eof { EOF }
  | '\n' { newline lexbuf ; tok lexbuf }
  | blank+ { tok lexbuf }
  | "//" [^ '\n']* '\n' { newline lexbuf ; tok lexbuf }
  | "/*" { comment lexbuf }
  | ident as a { ident a }
  | '"' { LINK (string_val (Buffer.create 10) lexbuf) }
  | (ident as group) '.' (ident as var) { FIELD(group,var) }
  | _ | ":=" | "+=" { KEY (Lexing.lexeme lexbuf) }

and comment = parse
  | eof { failwith "Unterminated comment" }
  | "*/" { tok lexbuf }
  | '\n' { newline lexbuf ; comment lexbuf }
  | _ { comment lexbuf }

and value = parse
    | '\n' { newline lexbuf ; value lexbuf }
    | blank+ { value lexbuf }
    | ident  as a { a }
    | '"' { string_val (Buffer.create 10) lexbuf }
    | _ { failwith "Ident or String expected" }

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
      { string_val buf lexbuf }
  | '\\' (_ as c)
      { Buffer.add_char buf '\\';
        Buffer.add_char buf c;
        string_val buf lexbuf }
  | eof
      { failwith "Unterminated string" }

and recstring acc = parse
  | ';' | blank+ { recstring acc lexbuf }
  | '\n' { newline lexbuf ; recstring acc lexbuf }
  | '}'  { acc }
  | ident as field { recstring_bis acc field lexbuf }
  | _ { failwith "Identifier or '}' expected" }
and recstring_bis acc field = parse
  | blank+ { recstring_bis acc field lexbuf }
  | '\n' { newline lexbuf ; recstring_bis acc field lexbuf }
  | '='  { recstring_ter acc field lexbuf }
  | _    { failwith "'=' expected" }
and recstring_ter acc field = parse
  | blank+ { recstring_ter acc field lexbuf }
  | '\n'   { newline lexbuf ; recstring_ter acc field lexbuf }
  | ident as name { recstring ((field,name)::acc) lexbuf }
  | '"'
      { let name = string_val (Buffer.create 10) lexbuf in
        recstring ((field,name)::acc) lexbuf
      }
  | _ { failwith "Identifier or String expected" }

and recorstring = parse
  | '\n'   { newline lexbuf ; recorstring lexbuf }
  | blank+ { recorstring lexbuf }
  | '"'    { `String (string_val (Buffer.create 10) lexbuf) }
  | '{'    { `RecString (recstring [] lexbuf) }
  | _ as c { failwith (Printf.sprintf "found '%c' instead of \" or {" c) }

and bal = parse
  | '\n' { newline lexbuf ; bal lexbuf }
  | blank+ { bal lexbuf }
  | ('(' "right" ')') { `Right }
  | ('(' "nary"  ')') { `Nary }
  | ('(' "left"  ')')? as c { if c = "" then `Default else `Left }

{

}
