(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA   (Commissariat à l'énergie atomique et aux énergies            *)
(*           alternatives)                                                *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
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

  open Logic_parser
  open Lexing

  type state = Normal | Test

  let state_stack = Stack.create ()

  let () = Stack.push Normal state_stack

  let get_state () = try Stack.top state_stack with Stack.Empty -> Normal

  let pop_state () = try ignore (Stack.pop state_stack) with Stack.Empty -> ()

  exception Error of (int * int) * string

  let loc lexbuf = (lexeme_start lexbuf, lexeme_end lexbuf)

  let lex_error lexbuf s =
    raise (Error (loc lexbuf, "lexical error, " ^ s))

  let find_utf8 =
    let h = Hashtbl.create 97 in
    List.iter (fun (i,t) -> Hashtbl.add h i t)
      [ Utf8_logic.forall, FORALL;
        Utf8_logic.exists, EXISTS;
        Utf8_logic.eq, EQ;
        Utf8_logic.neq, NE;
        Utf8_logic.le, LE;
        Utf8_logic.ge, GE;
        Utf8_logic.implies,IMPLIES;
        Utf8_logic.iff, IFF;
        Utf8_logic.conj, AND;
        Utf8_logic.disj, OR;
        Utf8_logic.neg, NOT;
        Utf8_logic.x_or, HATHAT;
        Utf8_logic.minus, MINUS;
        Utf8_logic.boolean, BOOLEAN;
        Utf8_logic.integer, INTEGER;
        Utf8_logic.real, REAL;
        Utf8_logic.inset, IN;
        Utf8_logic.pi, PI;
      ];

    fun s -> try Hashtbl.find h s
    with Not_found -> IDENTIFIER s

  let all_digits s =
    let is_digit =
      function
      | '0'..'9' | 'a'..'f' | 'A'..'F' -> ()
      | _ -> raise Exit
    in
    try String.iter is_digit s; true with Exit -> false

  let is_ucn s =
    if String.length s <= 2 || s.[0] <> '\\' then false else begin
      match s.[1] with
      | 'U' -> String.length s = 10 && all_digits (String.sub s 2 8)
      | 'u' -> String.length s = 6 && all_digits (String.sub s 2 4)
      | _ -> false
    end

  let int_of_digit chr =
    match chr with
    | '0'..'9' -> (Char.code chr) - (Char.code '0')
    | 'a'..'f' -> (Char.code chr) - (Char.code 'a') + 10
    | 'A'..'F' -> (Char.code chr) - (Char.code 'A') + 10
    | _ -> assert false

  (* assumes is_ucn s *)
  let unicode_char s =
    let code = ref 0 in
    let add_digit c = code := 16 * !code + int_of_digit c in
    String.iter add_digit (String.sub s 2 (String.length s - 2));
    let c = Utf8_logic.from_unichar !code in
    find_utf8 c

  let identifier, is_acsl_keyword =
    let all_kw = Hashtbl.create 37 in
    let type_kw = Hashtbl.create 3 in
    List.iter
      (fun (i,t) -> Hashtbl.add all_kw i t;)
      [
        "admit", (fun _ -> ADMIT);
        "allocates", (fun _ -> ALLOCATES);
        "assert", (fun _ -> ASSERT);
        "assigns", (fun _ -> ASSIGNS);
        "assumes", (fun _ -> ASSUMES);
        "at", (fun _ -> EXT_AT);
        (* ACSL extension for external spec file *)
        "axiom", (fun _ -> AXIOM);
        "axiomatic", (fun _ -> AXIOMATIC);
        "behavior", (fun _ -> BEHAVIOR);
        "behaviors", (fun _ -> BEHAVIORS);
        "_Bool", (fun _ -> BOOL);
        "breaks", (fun _ -> BREAKS);
        "case", (fun _ -> CASE);
        "char", (fun _ -> CHAR);
        "check", (fun _ -> CHECK);
        "complete", (fun _ -> COMPLETE);
        "const", (fun _ -> CONST);
        "continues", (fun _ -> CONTINUES);
        "contract", (fun _ -> CONTRACT);
        (* ACSL extension for external spec file *)
        "decreases", (fun _ -> DECREASES);
        "disjoint", (fun _ -> DISJOINT);
        "double", (fun _ -> DOUBLE);
        "else", (fun _ -> ELSE);
        "ensures", (fun _ -> ENSURES);
        "enum", (fun _ -> ENUM);
        "exits", (fun _ -> EXITS);
        "frees", (fun _ -> FREES);
        "function", (fun _ -> FUNCTION);
        (* ACSL extension for external spec file *)
        "float", (fun _ -> FLOAT);
        "for", (fun _ -> FOR);
        "global", (fun _ -> GLOBAL);
        "if", (fun _ -> IF);
	"impact", (fun _ -> IMPACT);
	"inductive", (fun _ -> INDUCTIVE);
	"include", (fun _ -> INCLUDE);
        (* ACSL extension for external spec file *)
        "int", (fun _ -> INT);
        "invariant", (fun _ -> INVARIANT);
        "label", (fun _ -> LABEL);
        "lemma", (fun _ -> LEMMA);
        "let", (fun _ -> EXT_LET);
        (* ACSL extension for external spec file *)
        "logic", (fun _ -> LOGIC);
        "long", (fun _ -> LONG);
        "loop", (fun _ -> LOOP);
        "model", (fun _ -> MODEL);
        (* ACSL extension for model fields *)
        "module", (fun _ -> MODULE);
        (* ACSL extension for external spec file *)
        "pragma", (fun _ -> PRAGMA);
        "predicate", (fun _ -> PREDICATE);
        "reads", (fun _ -> READS);
        "requires", (fun _ -> REQUIRES);
        "returns", (fun _ -> RETURNS);
        "short", (fun _ -> SHORT);
        "signed", (fun _ -> SIGNED);
        "sizeof", (fun _ -> SIZEOF);
        "slice", (fun _ -> SLICE);
        "struct", (fun _ -> STRUCT);
        "terminates", (fun _ -> TERMINATES);
        "type", (fun _ -> TYPE);
        "union", (fun _ -> UNION);
        "unsigned", (fun _ -> UNSIGNED);
        "variant", (fun _ -> VARIANT);
        "void", (fun _ -> VOID);
        "volatile", (fun _ -> VOLATILE);
        "writes", (fun _ -> WRITES);
        "__FC_FILENAME__",
        (fun loc ->
           let filename =
             Filepath.(Normalized.to_pretty_string (fst loc).pos_path)
           in
           STRING_LITERAL (false,filename));
      ];
    List.iter (fun (x, y) -> Hashtbl.add type_kw x y)
      ["integer", INTEGER; "real", REAL; "boolean", BOOLEAN; ];
    (fun s loc ->
      try
        (Hashtbl.find all_kw s)
        loc
      with Not_found ->
        let res =
          match Logic_env.extension_category s with
          | exception Not_found -> None
          | Cil_types.Ext_contract -> Some (EXT_CONTRACT s)
          | Cil_types.Ext_global ->
            begin
              match Logic_env.is_extension_block s with
              | false -> Some (EXT_GLOBAL s)
              | true -> Some (EXT_GLOBAL_BLOCK s)
            end
          | Cil_types.Ext_code_annot _ -> Some (EXT_CODE_ANNOT s)
        in
        match res with
        | None ->
          if Logic_env.typename_status s then TYPENAME s
          else
            (try
               Hashtbl.find type_kw s
             with Not_found -> IDENTIFIER s)
        | Some lex -> lex
    ),
    (fun s -> Hashtbl.mem all_kw s || Hashtbl.mem type_kw s)

  let bs_identifier =
    let h = Hashtbl.create 97 in
    List.iter (fun (i,t) -> Hashtbl.add h i t)
      [
        "\\allocation", ALLOCATION;
        "\\allocable", ALLOCABLE;
        "\\automatic", AUTOMATIC;
        "\\at", AT;
        "\\base_addr", BASE_ADDR;
        "\\block_length", BLOCK_LENGTH;
        "\\dynamic", DYNAMIC;
        "\\empty", EMPTY;
        "\\exists", EXISTS;
        "\\false", FALSE;
        "\\forall", FORALL;
        "\\freeable", FREEABLE;
        "\\fresh", FRESH;
        "\\from", FROM;
        "\\ghost", BSGHOST;
        "\\initialized", INITIALIZED;
        "\\dangling", DANGLING;
        "\\in", IN;
        "\\inter", INTER;
        "\\lambda", LAMBDA;
        "\\let", LET;
        "\\nothing", NOTHING;
        "\\null", NULL;
        "\\offset", OFFSET;
        "\\old", OLD;
        "\\pi", PI;
        "\\register", REGISTER;
        "\\result", RESULT;
        "\\separated", SEPARATED;
        "\\static", STATIC;
        "\\true", TRUE;
        "\\type", BSTYPE;
        "\\typeof", TYPEOF;
        "\\unallocated", UNALLOCATED;
        "\\union", BSUNION;
        "\\object_pointer", OBJECT_POINTER;
        "\\valid", VALID;
        "\\valid_read", VALID_READ;
        "\\valid_index", VALID_INDEX;
        "\\valid_range", VALID_RANGE;
        "\\valid_function", VALID_FUNCTION;
        "\\with", WITH;
      ];
    fun lexbuf ->
      let s = lexeme lexbuf in
      if is_ucn s then unicode_char s else begin
        try Hashtbl.find h s with Not_found ->
          if Logic_env.typename_status s then TYPENAME s
          else IDENTIFIER s
      end

  (* Update lexer buffer. *)
  let update_line_pos lexbuf line =
    let pos = lexbuf.Lexing.lex_curr_p in
    lexbuf.Lexing.lex_curr_p <-
      { pos with
	Lexing.pos_lnum = line;
	Lexing.pos_bol = pos.Lexing.pos_cnum;
      }

  let update_file_pos lexbuf file =
   let pos = lexbuf.Lexing.lex_curr_p in
    lexbuf.Lexing.lex_curr_p <- { pos with Lexing.pos_fname = file }

  let accept_c_comments_into_acsl_spec = ref false

  let hack_merge_tokens current next =
    match (current,next) with
    | CHECK, REQUIRES -> true, CHECK_REQUIRES
    | CHECK, ENSURES -> true, CHECK_ENSURES
    | CHECK, EXITS -> true, CHECK_EXITS
    | CHECK, RETURNS -> true, CHECK_RETURNS
    | CHECK, BREAKS -> true, CHECK_BREAKS
    | CHECK, CONTINUES -> true, CHECK_CONTINUES
    | CHECK, LOOP -> true, CHECK_LOOP
    | CHECK, INVARIANT -> true, CHECK_INVARIANT
    | CHECK, LEMMA -> true, CHECK_LEMMA
    | ADMIT, REQUIRES -> true, ADMIT_REQUIRES
    | ADMIT, ENSURES -> true, ADMIT_ENSURES
    | ADMIT, EXITS -> true, ADMIT_EXITS
    | ADMIT, RETURNS -> true, ADMIT_RETURNS
    | ADMIT, BREAKS -> true, ADMIT_BREAKS
    | ADMIT, CONTINUES -> true, ADMIT_CONTINUES
    | ADMIT, LOOP -> true, ADMIT_LOOP
    | ADMIT, INVARIANT -> true, ADMIT_INVARIANT
    | ADMIT, LEMMA -> true, ADMIT_LEMMA
    | _ -> false, current

  let type_to_string = function
    | TYPENAME s -> s
    | REAL -> "real"
    | BOOLEAN -> "boolean"
    | INTEGER -> "integer"
    | _ -> assert false

  let check_ext_plugin source plugin tok =
    match tok with
    | IDENTIFIER s ->
      if Plugin.is_present plugin then
        Kernel.warning ~once:true ~wkey:Kernel.wkey_extension_unknown ~source
          "Unregistered extension '%s' for plug-in %s" s plugin
      else
        Kernel.warning ~once:true ~wkey:Kernel.wkey_plugin_not_loaded ~source
          "Ignored extensions for unloaded plug-in %s" plugin;
      IDENTIFIER_EXT s
    | EXT_CODE_ANNOT s
    | EXT_GLOBAL s
    | EXT_GLOBAL_BLOCK s
    | EXT_CONTRACT s ->
      let plugin_from = Logic_env.extension_from s in
      if plugin_from = plugin && plugin = "kernel" then
        Kernel.abort ~source
          "Extension '%s' from frama-c's kernel should not be used with the syntax \
          \\kernel::%s" s s;
      if plugin_from <> plugin then
        Kernel.abort ~source
          "Extension '%s' is from %s and not %s" s plugin_from plugin;
      tok
    | _ ->
      Kernel.abort ~source
        "Type token \'%s\' received instead of extension identifier"
        (type_to_string tok)
}

let space = [' ' '\t' '\012' '\r' '@' ]

let rB = ['0' '1']
let rD = ['0'-'9']
let rO = ['0'-'7']
let rL = ['a'-'z' 'A'-'Z' '_']
let rH = ['a'-'f' 'A'-'F' '0'-'9']
let rE = ['E''e']['+''-']? rD+
let rP = ['P''p']['+''-']? rD+
let rFS	= ('f'|'F'|'l'|'L'|'d'|'D')
let rIS = ('u'|'U'|'l'|'L')*
let comment_line = "//" [^'\n']*
let rIdentifier = rL (rL | rD)*

(* Do not forget to update also the corresponding chr rule if you add
   a supported escape sequence here. *)
let escape = '\\'
   ('\'' | '"' | '?' | '\\' | 'a' | 'b' | 'f' | 'n' | 'r'
   | 't' | 'v')

let hex_escape = '\\' ['x' 'X'] rH+
let oct_escape = '\\' rO rO? rO?

let utf8_char = ['\128'-'\254']+

rule token = parse
  | space+ { token lexbuf }
  | '\n' { Lexing.new_line lexbuf; token lexbuf }
  | comment_line '\n' { Lexing.new_line lexbuf; token lexbuf }
  | comment_line eof { token lexbuf }
  | "*/" { lex_error lexbuf "unexpected block-comment closing" }
  | "/*" { if !accept_c_comments_into_acsl_spec
           then comment lexbuf
           else lex_error lexbuf "unexpected block-comment opening"
         }
  | '\\' (rIdentifier as plugin) "::" (rIdentifier as name) {
     let loc = Lexing.(lexeme_start_p lexbuf, lexeme_end_p lexbuf) in
     let cabsloc = Cil_datatype.Location.of_lexing_loc loc in
     let tok = identifier name cabsloc in
     check_ext_plugin (fst cabsloc) plugin tok
     }
  | '\\' rIdentifier { bs_identifier lexbuf }
  | rIdentifier       {
      let loc = Lexing.(lexeme_start_p lexbuf, lexeme_end_p lexbuf) in
      let cabsloc = Cil_datatype.Location.of_lexing_loc loc in
      let s = lexeme lexbuf in
      let curr_tok = identifier s cabsloc in
      if curr_tok = CHECK || curr_tok = ADMIT then begin
        let next_tok =
          token { lexbuf with refill_buff = lexbuf.refill_buff }
        in
        let (eat_next, tok) = hack_merge_tokens curr_tok next_tok in
        if eat_next then ignore (token lexbuf);
        tok
      end else curr_tok
    }

  | '0'['x''X'] rH+ rIS?    { INT_CONSTANT (lexeme lexbuf) }
  | '0'['b''B'] rB+ rIS?    { INT_CONSTANT (lexeme lexbuf) }
  | '0' rD+ rIS?            { INT_CONSTANT (lexeme lexbuf) }
  | rD+                     { INT_CONSTANT (lexeme lexbuf) }
  | rD+ rIS                 { INT_CONSTANT (lexeme lexbuf) }
  | ('L'? "'" as prelude) (([^ '\\' '\'' '\n']|("\\"[^ '\n']))+ as content) "'"
      {
        let b = Buffer.create 5 in
        Buffer.add_string b prelude;
        let lbf = Lexing.from_string content in
        INT_CONSTANT (chr b lbf ^ "'")
      }
(* floating-point literals, both decimal and hexadecimal *)
  | rD+ rE rFS?
  | rD* "." rD+ (rE)? rFS?
  | rD+ "." rD* (rE)? rFS?
  | '0'['x''X'] rH+ '.' rH* rP rFS?
  | '0'['x''X'] rH* '.' rH+ rP rFS?
  | '0'['x''X'] rH+ rP rFS?
      { FLOAT_CONSTANT (lexeme lexbuf) }

 (* hack to lex 0..3 as 0 .. 3 and not as 0. .3 *)
  | (rD+ as n) ".."         { lexbuf.lex_curr_pos <- lexbuf.lex_curr_pos - 2;
                              INT_CONSTANT n }

  | 'L'? '"' as prelude (([^ '\\' '"' '\n']|("\\"[^ '\n']))* as content) '"'
      { STRING_LITERAL (prelude.[0] = 'L',content) }
  | '#'                     { hash lexbuf }
  | "==>"                   { IMPLIES }
  | "<==>"                  { IFF }
  | "-->"                   { BIMPLIES }
  | "<-->"                  { BIFF }
  | "&&"                    { AND }
  | "||"                    { OR }
  | "!"                     { NOT }
  | "$"                     { DOLLAR }
  | ","                     { COMMA }
  | "->"                    { ARROW }
  | "?"                     { Stack.push Test state_stack; QUESTION }
  | ";"                     { SEMICOLON }
  | ":"                     { match get_state() with
                                  Normal  -> COLON
                                | Test -> pop_state(); COLON2
                            }
  | "::"                    { COLONCOLON }
  | "."                     { DOT }
  | ".."                    { DOTDOT }
  | "..."                   { DOTDOTDOT }
  | "-"                     { MINUS }
  | "+"                     { PLUS }
  | "*"                     { STAR }
  | "*^"                    { STARHAT }
  | "&"                     { AMP }
  | "^^"                    { HATHAT }
  | "^"                     { HAT }
  | "|"                     { PIPE }
  | "~"                     { TILDE }
  | "/"                     { SLASH }
  | "%"                     { PERCENT }
  | "<"                     { LT }
  | ">"                     { GT }
  | "<="                    { LE }
  | ">="                    { GE }
  | "=="                    { EQ }
  | "="                     { EQUAL }
  | "!="                    { NE }
  | "("                     { Stack.push Normal state_stack; LPAR }
  | ")"                     { pop_state(); RPAR }
  | "{"                     { Stack.push Normal state_stack; LBRACE }
  | "}"                     { pop_state(); RBRACE }
  | "["                     { Stack.push Normal state_stack; LSQUARE }
  | "]"                     { pop_state(); RSQUARE }
  | "[|"                    { Stack.push Normal state_stack; LSQUAREPIPE }
  | "|]"                    { pop_state(); RSQUAREPIPE }
  | "<<"                    { LTLT }
  | ">>"                    { GTGT }
  | utf8_char as c          { find_utf8 c }
  | eof                     { EOF }
  | _   { lex_error lexbuf ("illegal character " ^ lexeme lexbuf) }

and chr buffer = parse
  | hex_escape
      { let s = lexeme lexbuf in
        let real_s = String.sub s 2 (String.length s - 2) in
        let rec add_one_char s =
          let l = String.length s in
          if l = 0 then ()
          else
          let h = int_of_digit s.[0] in
          let c,s =
            if l = 1 then (h,"")
            else
              (16*h + int_of_digit s.[1],
               String.sub s 2 (String.length s - 2))
          in
          Buffer.add_char buffer (Char.chr c); add_one_char s
        in add_one_char real_s; chr buffer lexbuf
      }
  | oct_escape
      { let s = lexeme lexbuf in
        let real_s = String.sub s 1 (String.length s - 1) in
        let rec value i s =
          if s = "" then i
          else value (8*i+int_of_digit s.[0])
            (String.sub s 1 (String.length s -1))
        in let c = value 0 real_s in
        Buffer.add_char buffer (Char.chr c); chr buffer lexbuf
      }
  | escape
      { Buffer.add_char buffer
          (match (lexeme lexbuf).[1] with
               'a' -> '\007'
             | 'b' -> '\b'
             | 'f' -> '\012'
             | 'n' -> '\n'
             | 'r' -> '\r'
             | 't' -> '\t'
             | 'v' -> '\011' (* no '\v' in OCaml 😞 *)
             | '\'' -> '\''
             | '"' -> '"'
             | '?' -> '?'
             | '\\' -> '\\'
             | _ -> (* escape regex does not allow anything else *) assert false
          ); chr buffer lexbuf}
  | eof { Buffer.contents buffer }
  | _  { Buffer.add_string buffer (lexeme lexbuf); chr buffer lexbuf }

and hash = parse
  '\n'		{ Lexing.new_line lexbuf; token lexbuf}
| [' ''\t']		{ hash lexbuf}
| rD+	        { (* We are seeing a line number. This is the number for the
                   * next line *)
                 let s = Lexing.lexeme lexbuf in
                 let lineno =
                   try
                     int_of_string s
                   with Failure _ ->
                     (* the int is too big. *)
                     Kernel.warning
                       ~source:(Cil_datatype.Position.of_lexing_pos lexbuf.lex_start_p)
                       "Bad line number in preprocessed file: %s"  s;
                     (-1)
                 in
                 update_line_pos lexbuf (lineno - 1);
                  (* A file name may follow *)
		  file lexbuf }
| "line"        { hash lexbuf } (* MSVC line number info *)
| _	        { endline lexbuf}

and file =  parse
        '\n'		        { Lexing.new_line lexbuf; token lexbuf}
|	[' ''\t''\r']			{ file lexbuf}
|	'"' ([^ '\012' '\t' '"']|"\\\"")* '"' {
    let n = Lexing.lexeme lexbuf in
    let n1 = String.sub n 1
        ((String.length n) - 2) in
    let unescape = Str.regexp_string "\\\"" in
    let n1 = Str.global_replace unescape "\"" n1 in
    update_file_pos lexbuf n1;
    endline lexbuf
  }

|	_			{ endline lexbuf}

and endline = parse
        '\n' 			{ Lexing.new_line lexbuf; token lexbuf}
|   eof                         { EOF }
|	_			{ endline lexbuf}

and comment = parse
    '\n' { Lexing.new_line lexbuf; comment lexbuf}
  | "*/" { token lexbuf}
  | eof  { lex_error lexbuf "non-terminating block-comment" }
  | _    { comment lexbuf}

{
  (* When Ocaml 4.11+ becomes mandatory, we can probably replace this with
     Lexing.set_position. *)
  let set_initial_position dest_lexbuf src_pos =
    dest_lexbuf.Lexing.lex_curr_p <- src_pos;
    dest_lexbuf.lex_abs_pos <- src_pos.pos_cnum

  let parse_from_position f (pos, s : Filepath.position * string) =
    let output = Kernel.warning ~wkey:Kernel.wkey_annot_error
    in
    let lb = from_string s in
    set_initial_position lb (Cil_datatype.Position.to_lexing_pos pos);
    try
      let res = f token lb in
      Some (Cil_datatype.Position.of_lexing_pos lb.Lexing.lex_curr_p, res)
    with
      | Failure s -> (* raised by the lexer itself, through [f] *)
          output ~source:(Cil_datatype.Position.of_lexing_pos lb.lex_curr_p) "lexing error: %s" s; None
      | Parsing.Parse_error ->
        output ~source:(Cil_datatype.Position.of_lexing_pos lb.lex_curr_p) "unexpected token '%s'" (Lexing.lexeme lb);
        None
      | Error (_, m) -> output ~source:(Cil_datatype.Position.of_lexing_pos lb.lex_curr_p) "%s" m; None
      | Logic_utils.Not_well_formed (loc, m) ->
        output ~source:(fst loc) "%s" m;
        None
      | Logic_utils.Unknown_ext -> None
      | Log.FeatureRequest(source,_,msg) ->
        let source = Option.value ~default:(Cil_datatype.Position.of_lexing_pos lb.lex_curr_p) source in
        output ~source "unimplemented ACSL feature: %s" msg; None
      | Log.AbortError _ as exn -> raise exn
      | exn ->
        Kernel.fatal ~source:(Cil_datatype.Position.of_lexing_pos lb.lex_curr_p) "Unknown error (%s)"
          (Printexc.to_string exn)

  let lexpr = parse_from_position Logic_parser.lexpr_eof

  let annot = parse_from_position Logic_parser.annot

  let spec = parse_from_position Logic_parser.spec

  let ext_spec lexbuf = try
      accept_c_comments_into_acsl_spec := true ;
      let r = Logic_parser.ext_spec token lexbuf in
      accept_c_comments_into_acsl_spec := false ;
      r
    with exn ->
      accept_c_comments_into_acsl_spec := false ;
      raise exn

  type 'a parse = Filepath.position * string -> (Filepath.position * 'a) option

  let chr lexbuf =
    let buf = Buffer.create 16 in
    chr buf lexbuf
}

(*
Local Variables:
compile-command: "make -C ../../.. byte"
End:
*)
