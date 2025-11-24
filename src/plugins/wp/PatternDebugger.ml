(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server
module Md = Markdown

(* -------------------------------------------------------------------------- *)
(* --- Pattern Diagnostic                                                 --- *)
(* -------------------------------------------------------------------------- *)

let package =
  Package.package ~plugin:"wp"
    ~name:"patterndebugger"
    ~title:"WP Pattern Debugger" ()

type diagnostic = {
  message : string ;
  details : string ;
  severity : [ `Ok | `Warning | `Error ] ;
  location : Cil_types.location option ;
}

module Range : Data.S with type t = Cil_types.location =
struct
  type t = Cil_types.location
  let jtype =
    Data.declare ~package ~name:"range" @@
    Package.(Jrecord [
        "offset", Jnumber;
        "length", Jnumber;
      ])
  let to_json (loc : t) =
    let offset = (fst loc).pos_cnum in
    let length = (snd loc).pos_cnum - offset in
    `Assoc [ "offset", `Int offset ; "length", `Int length ]

  let of_json _ = failwith "Wp.PatternDebugger.Range"
end

module RangeOpt = Data.Joption(Range)

module Diagnostic : Request.Output with type t = diagnostic =
struct
  type t = diagnostic
  let jtype =
    Data.declare ~package ~name:"diagnostic" @@
    Package.(Jrecord [
        "message", Jstring ;
        "details", Jstring ;
        "severity", Junion [ Jtag "Warning" ; Jtag "Error" ; Jtag "Ok" ] ;
        "range", RangeOpt.jtype ;
      ])
  let severity_tag = function
    | `Ok -> "Ok" | `Warning -> "Warning" | `Error -> "Error"
  let to_json d = `Assoc [
      "message" , `String d.message ;
      "details" , `String d.details ;
      "severity" , `String (severity_tag d.severity) ;
      "range" , RangeOpt.to_json d.location
    ]
end

let valid ~message ?(details="") () =
  { severity = `Ok ; message ; details ; location = None }
let warning ?loc ~message ?(details="") () =
  { severity = `Warning ; message ; details ; location = loc }
let error ?loc ~message ?(details="") () =
  { severity = `Error ; message ; details ; location = loc }

(* -------------------------------------------------------------------------- *)
(* --- Local Pattern Parser                                               --- *)
(* -------------------------------------------------------------------------- *)

exception ParseError of Cil_types.location * string

let set_initial_position dest_lexbuf src_pos =
  dest_lexbuf.Lexing.lex_curr_p <- src_pos;
  dest_lexbuf.lex_abs_pos <- src_pos.pos_cnum

let parse_string s =
  let open Current_loc.Operators in
  let pos_path = Filepath.of_string "<user-string>" in
  let s = String.cat s "\n" in
  let pos_cnum = String.length s in
  let pos_lnum =
    let i = ref 0 in
    String.iter (function '\n' -> incr i | _ -> ()) s ; !i in
  let pbeg = { Filepath.empty_pos with pos_path ; pos_cnum = 0 } in
  let pend = { Filepath.empty_pos with pos_path ; pos_cnum ; pos_lnum } in
  let lb = Lexing.from_string s in
  let get_loc () =
    Cil_datatype.Position.of_lexing_pos @@ Lexing.lexeme_start_p lb,
    Cil_datatype.Position.of_lexing_pos @@ Lexing.lexeme_end_p lb
  in
  let<> UpdatedCurrentLoc = (pbeg, pend) in
  set_initial_position lb (Cil_datatype.Position.to_lexing_pos pbeg);
  try Logic_parser.lexpr_list_eof Logic_lexer.token lb
  with
  | Logic_utils.Not_well_formed (loc, msg) ->
    raise (ParseError (loc, msg))
  | Logic_lexer.Error (_, msg) ->
    raise (ParseError(get_loc (), msg))
  | Parsing.Parse_error ->
    let loc = get_loc () in
    let tok = Lexing.lexeme lb in
    let msg =
      if tok = "" then "unexpected token" else
        Printf.sprintf "unexpected token %S" tok in
    raise (ParseError (loc, msg))

type parse_result =
  | Patterns of Pattern.pattern list
  | Error of Cil_types.location * string

let parse_patterns s =
  let context = Pattern.context () in
  try Patterns (List.map (Pattern.pa_pattern context) @@ parse_string s)
  with ParseError (loc, msg) | Pattern.TypeError (loc, msg) -> Error (loc, msg)

(* -------------------------------------------------------------------------- *)
(* --- Debug Request                                                      --- *)
(* -------------------------------------------------------------------------- *)

let check_pattern sequent sigma pattern =
  Pattern.psequent Pattern.{
      head = false ;
      goal = true ;
      hyps = true ;
      split = true ;
      pattern
    } sigma sequent

let debug pattern ?node () =
  match parse_patterns pattern with
  | exception exn ->
    let message = Printf.sprintf "Failure (%s)" (Printexc.to_string exn) in
    error ~message ()
  | Error (loc, message) -> error ~loc ~message ()
  | Patterns ps ->
    if ps=[] then warning ~message:"Empty pattern" () else
      match node with
      | None -> valid ~message:"Valid pattern" ()
      | Some node ->
        let sequent = snd @@ Wpo.compute @@ ProofEngine.goal node in
        let rec apply_all sigma = function
          | [] ->
            let details = Format.asprintf "%a" Pattern.pp_sigma sigma in
            valid ~message:"Applicable pattern" ~details ()
          | p::ps ->
            match check_pattern sequent sigma p with
            | Some sigma -> apply_all sigma ps
            | None ->
              let loc = Pattern.pattern_loc p in
              warning ~loc ~message:"Unmatched pattern" ()
        in apply_all Pattern.empty @@
        List.mapi (fun i -> Pattern.named (Printf.sprintf "$%d" i)) ps

let () =
  let signature = Request.signature ~output:(module Diagnostic) () in
  let get_text = Request.param signature ~name:"pattern"
      ~descr:(Md.plain "Pattern text")
      ~default:"" (module Data.Jstring) in
  let get_node = Request.param_opt signature ~name:"node"
      ~descr:(Md.plain "Node to check pattern on (optional)")
      (module WpTipApi.Node) in
  Request.register_sig ~package ~kind:`GET ~name:"debug"
    ~descr:(Md.plain "Debug pattern")
    signature
    begin fun rq () ->
      let text = get_text rq in
      let node = get_node rq in
      debug text ?node ()
    end

(* -------------------------------------------------------------------------- *)
