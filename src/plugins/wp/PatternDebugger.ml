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

type matching = {
  name: string ;
  pattern: string ;
  matched: string ;
  target: Ptip.target ;
}

type diagnostic = {
  message : string ;
  severity : [ `Ok | `Warning | `Error ] ;
  location : Cil_types.location option ;
  matchings : matching list option ;
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
module Target = Data.Jpair(WpTipApi.Part)(Data.Joption(WpTipApi.Term))

module Matching : Data.S with type t = matching =
struct
  type t = matching
  let jtype =
    Data.declare ~package ~name:"matching" @@
    Package.(Jrecord [
        "name", Jstring ;
        "pattern", Jstring ;
        "matched", Jstring ;
        "target", Target.jtype ;
      ])
  let to_json m =
    let target =
      let part = match fst @@ m.target with
        | Ptip.Term -> `Term
        | Ptip.Goal -> `Goal
        | Ptip.Step s -> `Step s.id
      in
      part, snd m.target
    in
    `Assoc [
      "name" , `String m.name ;
      "pattern" , `String m.pattern ;
      "matched" , `String m.matched ;
      "target", Target.to_json target ;
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Matching"
end

module MatchingsOpt = Data.Joption(Data.Jlist(Matching))

module Diagnostic : Request.Output with type t = diagnostic =
struct
  type t = diagnostic
  let jtype =
    Data.declare ~package ~name:"diagnostic" @@
    Package.(Jrecord [
        "message", Jstring ;
        "matchings", MatchingsOpt.jtype ;
        "severity", Junion [ Jtag "Warning" ; Jtag "Error" ; Jtag "Ok" ] ;
        "range", RangeOpt.jtype ;
      ])
  let severity_tag = function
    | `Ok -> "Ok" | `Warning -> "Warning" | `Error -> "Error"
  let to_json d = `Assoc [
      "message" , `String d.message ;
      "matchings" , MatchingsOpt.to_json d.matchings ;
      "severity" , `String (severity_tag d.severity) ;
      "range" , RangeOpt.to_json d.location
    ]
end

let valid ~message ~matchings () =
  { severity = `Ok ; message ; matchings ; location = None }
let warning ?loc ~message ~matchings () =
  { severity = `Warning ; message ; matchings = matchings ; location = loc }
let error ?loc ~message () =
  { severity = `Error ; message ; matchings = None ; location = loc }

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
      if tok = "" then "unexpected end of pattern" else
        Printf.sprintf "unexpected token %S" tok in
    raise (ParseError (loc, msg))

type parse_result =
  | Error of Cil_types.location * string
  | Patterns of {
      lookups: Pattern.lookup list ;
      select: Pattern.value list ;
      debug_table: (string, Pattern.pattern) Hashtbl.t ;
    }

type denv = {
  table: (string, Pattern.pattern) Hashtbl.t ;
  mutable last: int ;
}

let parse_name ?check p =
  let open Logic_ptree in
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar value
  | PLapp(value,[],[])
  | PLconstant(StringConstant value)
    ->
    Option.iter (fun f -> f loc value) check ;
    (loc, value)
  | _ ->
    let msg = Format.asprintf "name expected" in
    raise (Pattern.TypeError(loc, msg))

let parse_lookup
    penv denv ?(head=true) ?(goal=false) ?(hyps=false) ?(split=false) p =
  let name = Format.asprintf "$%d" denv.last in
  denv.last <- denv.last + 1 ;
  let pattern = Pattern.(named name @@ pa_pattern penv p) in
  Hashtbl.add denv.table name pattern ;
  Pattern.{ goal ; hyps ; head ; split ; pattern }

let autoselect select lookup =
  match select , lookup with
  | [] , p::ps ->
    let q, v = Pattern.self p.Pattern.pattern in
    [v] , { p with pattern = q }::ps
  | _ -> select, lookup

let rec parse_tactic_params
    penv denv ~select ~(lookup:(Pattern.lookup list)) ~params ps =
  let open Logic_ptree in
  match ps with
  | [] ->
    let select = List.rev select in
    let lookup = List.rev lookup in
    autoselect select lookup
  | p::ps ->
    let loc = p.lexpr_loc in
    let cc = parse_tactic_params penv denv in
    match p.lexpr_node with
    | PLapp("\\goal",[],qs) ->
      let qs = List.map (parse_lookup ~goal:true penv denv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ps
    | PLapp("\\when",[],qs) ->
      let qs = List.map (parse_lookup ~hyps:true ~split:true penv denv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ps
    | PLapp("\\ingoal",[],qs) ->
      let qs = List.map (parse_lookup ~head:false ~goal:true penv denv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ps
    | PLapp("\\incontext",[],qs) ->
      let qs =
        List.map (parse_lookup ~head:false ~hyps:true ~split:true penv denv) qs
      in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ps
    | PLapp("\\pattern",[],qs) ->
      let qs = List.map
          (parse_lookup ~head:false ~goal:true ~hyps:true penv denv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ps
    | PLapp("\\select",[],vs) ->
      let vs = List.map (Pattern.pa_value penv) vs in
      let select = List.rev_append vs select in
      cc ~select ~lookup ~params ps
    | PLapp("\\param",[],[param;value]) ->
      let param = parse_name param in
      let value = Pattern.pa_value penv value in
      let params = (param,value)::params in
      cc ~select ~lookup ~params ps
    | PLapp("\\child",[],_) ->
      raise (Pattern.TypeError(loc, "\\child not recognized in debug mode"))
    | PLapp("\\children",[],_) ->
      raise (Pattern.TypeError(loc, "\\children not recognized in debug mode"))
    | _ ->
      raise (Pattern.TypeError(loc, "Tactic parameter expected"))

let parse_patterns s =
  let context = Pattern.context () in
  let denv = { table = Hashtbl.create 13 ; last = 0 } in
  try
    let tokens = parse_string s in
    let select, lookups =
      parse_tactic_params context denv ~select:[] ~lookup:[] ~params:[] tokens
    in
    Patterns { lookups ; select ; debug_table = denv.table }
  with ParseError (loc, msg) | Pattern.TypeError (loc, msg) -> Error (loc, msg)

(* -------------------------------------------------------------------------- *)
(* --- Debug Request                                                      --- *)
(* -------------------------------------------------------------------------- *)

(* Custom printers for clause and selection, using TIP printer:
   we want printed values to be coherent with the current printer. *)
let pp_clause printer fmt = function
  | Tactical.Goal p -> Format.fprintf fmt "%a (goal)" printer#pp_pred p
  | Step s -> Format.fprintf fmt "%a" printer#pp_step s

let rec pp_selection printer fmt = function
  | Tactical.Empty ->
    Format.pp_print_string fmt "Empty"
  | Inside(_c,t) ->
    Format.fprintf fmt "%a" printer#pp_term t
  | Clause c ->
    (pp_clause printer) fmt c
  | Compose(Cint k) ->
    Format.fprintf fmt "Constant '%a'" Z.pretty k
  | Compose(Range(a,b)) ->
    Format.fprintf fmt "Range '%d..%d'" a b
  | Compose(Code(_,id,es)) ->
    Format.fprintf fmt "@[<hov 2>Compose '%s'" id ;
    List.iter (fun e -> Format.fprintf fmt "(%a)" (pp_selection printer) e) es ;
    Format.fprintf fmt "@]"
  | Multi es ->
    Format.fprintf fmt "@[<hov 2>Multi-selection" ;
    List.iter (fun e -> Format.fprintf fmt "(%a)" (pp_selection printer) e) es ;
    Format.fprintf fmt "@]"

let extract_matchings debug_table printer sigma selection =
  let pp_selection = pp_selection printer in
  let matchings = ref [] in
  (* Extracting matchings ... *)
  let iter name matched =
    let target = printer#selection_to_target matched in
    let pattern =
      match Hashtbl.find_opt debug_table name with
      | Some pattern -> Format.asprintf "%a" Pattern.pp_pattern pattern
      | None -> name (* this is a user defined name *)
    in
    let matched = Format.asprintf "%a" pp_selection matched in
    matchings := { name ; pattern ; matched ; target } :: !matchings
  in
  Pattern.iter_sigma iter sigma ;
  (* Extracting selection *)
  begin match selection with
    | None | Some [] -> ()
    | Some l ->
      let selection =
        match l with
        | [v] -> Pattern.select sigma v
        | vs -> Tactical.Multi (List.map (Pattern.select sigma) vs)
      in
      let target = printer#selection_to_target selection in
      let pattern =
        Format.asprintf "SELECT: %a"
          (Pretty_utils.pp_list ~sep:", " Pattern.pp_value) l in
      let matched = Format.asprintf "%a" pp_selection selection in
      matchings := { name = "None" ; pattern ; matched ; target } :: !matchings
  end ;
  Some !matchings

let debug pattern ?node () =

  match parse_patterns pattern with
  | exception exn ->
    let message = Printf.sprintf "Failure (%s)" (Printexc.to_string exn) in
    error ~message ()
  | Error (loc, message) ->
    error ~loc ~message ()
  | Patterns lks ->
    match node with
    | None -> valid ~message:"Valid pattern" ~matchings:None ()
    | Some node ->
      let printer = WpTipApi.lookup_printer node in
      let get_matchings = extract_matchings lks.debug_table printer in
      let sequent = snd @@ Wpo.compute @@ ProofEngine.goal node in
      let rec apply_all sigma = function
        | [] ->
          let matchings = get_matchings sigma (Some lks.select) in
          valid ~message:"Applicable pattern" ~matchings ()
        | p::ps ->
          match Pattern.psequent p sigma sequent with
          | Some sigma ->
            apply_all sigma ps
          | None ->
            let loc = Pattern.pattern_loc p.pattern in
            let matchings = get_matchings sigma None in
            warning ~loc ~message:"Unmatched pattern" ~matchings ()
      in apply_all Pattern.empty lks.lookups

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
