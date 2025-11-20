(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server

let package =
  Package.package ~plugin:"wp" ~name:"patterndebugger" ~title:"WP Pattern Debugger" ()


exception ParseError of Cil_types.location * string

let set_initial_position dest_lexbuf src_pos =
  dest_lexbuf.Lexing.lex_curr_p <- src_pos;
  dest_lexbuf.lex_abs_pos <- src_pos.pos_cnum

let parse_string s =
  let open Current_loc.Operators in
  let pos_path = Filepath.of_string "<user-string>" in
  let s = String.cat s "\n" in
  let count_lines s =
    let i = ref 0 in
    String.iter (function '\n' -> incr i | _ -> ()) s ; !i
  in
  let pbeg = { Filepath.empty_pos with pos_path ; pos_lnum = 0 } in
  let pend = { Filepath.empty_pos with pos_path ; pos_lnum = count_lines s } in

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
  | _ ->
    let msg = Format.asprintf "unexpected token '%s'" (Lexing.lexeme lb) in
    raise (ParseError (get_loc (), msg))

type parse_result =
  | Patterns of Pattern.pattern list
  | Error of Cil_types.location * string

let parse_patterns s =
  let context = Pattern.context () in
  try Patterns (List.map (Pattern.pa_pattern context) @@ parse_string s)
  with ParseError (loc, msg) | Pattern.TypeError (loc, msg) ->
    Error (loc, msg)


module Location = Data.Jpair(Data.Jint)(Data.Jint)


(**************************************************************************)
(* First strategy ... *)

module Result_S1 = Data.Joption(Data.Jpair(Location)(Data.Jstring))

let () =
  Request.register ~package ~kind:`GET
    ~name:"typecheckPattern" ~descr:(Markdown.plain "Typecheck pattern")
    ~input:(module Data.Jstring)
    ~output:(module Result_S1)
    begin function
      | "" -> None
      | s ->
        match parse_patterns s with
        | Patterns _ -> None
        | Error ((l1, l2), msg) -> Some ((l1.pos_cnum, l2.pos_cnum), msg)
    end

(**************************************************************************)

(**************************************************************************)
(* Second strategy ... *)

module Reason = Data.Joption(Data.Jpair(Location)(Data.Jstring))

type rkind = Error | Warning | Ok

type result = {
  kind: rkind ;
  reason: ((int * int) * string) option ;
}

module Rkind = struct
  let dictionnary : rkind Data.Enum.dictionary = Data.Enum.dictionary ()

  let tag name value =
    Data.Enum.tag
      ~name ~descr:(Markdown.plain ("Case: " ^ name)) ~value dictionnary

  let _tag_error = tag "ERROR" Error
  let _tag_warning = tag "WARNING" Warning
  let _tag_ok = tag "OK" Ok

  let enum =
    Data.Enum.publish
      ~package ~name:"rkind" ~descr:(Markdown.plain "") dictionnary

  include (val enum)
end

module Result = struct
  let signature : result Data.Record.signature = Data.Record.signature ()

  let field_kind =
    Data.Record.field signature
      ~name:"kind"
      ~descr:(Markdown.plain "kind of result")
      (module Rkind)

  let field_reason =
    Data.Record.field signature
      ~name:"reason"
      ~descr:(Markdown.plain "result data when kind is not OK")
      (module Reason)

  let record =
    Data.Record.publish
      ~package ~name:"result" ~descr:(Markdown.plain "...") signature

  include (val record)

  let make r = default |> set field_kind r.kind |> set field_reason r.reason
end

let start_debug s n =
  match parse_patterns s with
  | Error ((l1, l2), msg) ->
    { kind = Error ; reason = Some ((l1.pos_cnum, l2.pos_cnum), msg) }
  | Patterns ps ->
    let lookup pattern =
      Pattern.{
        head = false ;
        goal = true ;
        hyps = true ;
        split = true ;
        pattern
      } in
    let ps = List.mapi (fun i -> Pattern.named ("$" ^ string_of_int i)) ps in
    let sequent = snd @@ Wpo.compute @@ ProofEngine.goal n in
    let apply_pattern (sigma, result) p =
      match sigma with
      | None -> sigma, result
      | Some sigma ->
        match Pattern.psequent (lookup p) sigma sequent with
        | Some sigma -> Some sigma, result
        | None ->
          let (l1, l2) = Pattern.pattern_loc p in
          let loc = l1.pos_cnum, l2.pos_cnum in
          let msg = "Cannot match term with this pattern" in
          None, { kind = Warning ; reason = Some (loc, msg) }
    in
    snd @@ List.fold_left
      apply_pattern
      (Some Pattern.empty, { kind = Ok ; reason = None})
      ps

let () =
  Request.register ~package ~kind:`GET
    ~name:"startDebug" ~descr:(Markdown.plain "Start debugging")
    ~input:(module Data.Jpair(Data.Jstring)(WpTipApi.Node))
    ~output:(module Result)
    (fun (s, n) -> Result.make @@ start_debug s n)


(**************************************************************************)
(* Small debug tool *)

let () =
  Request.register ~package ~kind:`GET
    ~name:"getMatches" ~descr:(Markdown.plain "Show matched terms")
    ~input:(module Data.Jpair(Data.Jstring)(WpTipApi.Node))
    ~output:(module Data.Junit)
    begin function
      | "", _ -> ()
      | s, node ->
        match parse_patterns s with
        | Error _ | Patterns [] -> ()
        | Patterns ps ->
          let ps = List.mapi (fun i -> Pattern.named ("$" ^ string_of_int i)) ps in
          let sigma = Pattern.empty in
          let lookup pattern =
            Pattern.{
              head = false ;
              goal = true ;
              hyps = true ;
              split = true ;
              pattern
            } in
          let sequent = snd @@ Wpo.compute @@ ProofEngine.goal node in
          let sigma =
            List.fold_left
              begin fun acc p ->
                match acc with
                | None -> None
                | Some sigma -> Pattern.psequent (lookup p) sigma sequent
              end
              (Some sigma)
              ps
          in
          match sigma with
          | None -> ()
          | Some sigma -> Kernel.feedback "%a" Pattern.pp_sigma sigma

    end
