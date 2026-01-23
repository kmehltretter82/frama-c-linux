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
(* --- Strategy debug information                                         --- *)
(* -------------------------------------------------------------------------- *)

type debug_entry = {
  name: string ; (* empty for selection *)
  pattern: string ;
  value: string ;
  target: Ptip.target ;
}

type debug_info = {
  selection: debug_entry option ;
  params: debug_entry list ;
  matched: debug_entry list ;
}

let empty_debug_info = {
  selection = None ;
  params = [] ;
  matched = [] ;
}

type diagnostic = {
  message: string ;
  severity : [ `Ok | `Ignored | `Warning | `Error ] ;
  location : Cil_types.location option ;
}

let valid ~loc ~message =
  { message ; severity = `Ok ; location = Some loc }

let ignored ~loc ~reason =
  { message = reason ; severity = `Ignored ; location = Some loc }

let warning ~loc ~message =
  { message ; severity = `Warning ; location = Some loc }

let error ~loc ~message =
  { message ; severity = `Error ; location = Some loc }

type alternative_result = {
  location: Cil_types.location option ;
  diagnostic: diagnostic list ;
  debug: debug_info ;
}

let alternative_result ?loc diagnostic ?(debug=empty_debug_info) () =
  { location = loc ; diagnostic ; debug }

type result = {
  diagnostic: diagnostic ;
  alts: alternative_result list ;
}

let failed_strategy ?loc ~message () =
  let diagnostic = { message ; severity = `Error ; location = loc } in
  { diagnostic ; alts = [] }

(* -------------------------------------------------------------------------- *)
(* --- Ivette Serializers                                                 --- *)
(* -------------------------------------------------------------------------- *)

let package =
  Package.package ~plugin:"wp"
    ~name:"strategydebugger"
    ~title:"WP Strategy Debugger" ()

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

module Target = Data.Jpair(WpTipApi.Part)(Data.Joption(WpTipApi.Term))

module Debug_entry : Data.S with type t = debug_entry =
struct
  type t = debug_entry
  let jtype =
    Data.declare ~package ~name:"debugEntry" @@
    Package.(Jrecord [
        "name", Jstring ;
        "pattern", Jstring ;
        "value", Jstring ;
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
      "value" , `String m.value ;
      "target", Target.to_json target ;
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Debug_entry"
end

module Debug_entry_opt = Data.Joption(Debug_entry)
module Debug_entry_list = Data.Jlist(Debug_entry)

module Debug_info : Data.S with type t = debug_info =
struct
  type t = debug_info
  let jtype =
    Data.declare ~package ~name:"debugInfo" @@
    Package.(Jrecord [
        "selection", Debug_entry_opt.jtype ;
        "params", Debug_entry_list.jtype ;
        "matched", Debug_entry_list.jtype ;
      ])

  let to_json { selection ; params ; matched } =
    `Assoc [
      "selection" , Debug_entry_opt.to_json selection ;
      "params" , Debug_entry_list.to_json params ;
      "matched" , Debug_entry_list.to_json matched ;
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Debug_info"
end

module RangeOpt = Data.Joption(Range)

module Diagnostic : Data.S with type t = diagnostic =
struct
  type t = diagnostic
  let jtype =
    let union =
      Package.Junion [
        Jtag "Warning" ;
        Jtag "Error" ;
        Jtag "Ok" ;
        Jtag "Ignored"
      ]
    in
    Data.declare ~package ~name:"diag" @@
    Package.(Jrecord [
        "message", Jstring ;
        "severity", union ;
        "range", RangeOpt.jtype ;
      ])

  let severity_tag = function
    | `Ok -> "Ok"
    | `Warning -> "Warning"
    | `Error -> "Error"
    | `Ignored -> "Ignored"

  let to_json d = `Assoc [
      "message" , `String d.message ;
      "severity" , `String (severity_tag d.severity) ;
      "range" , RangeOpt.to_json d.location
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Diag"
end

module Diagnostic_list = Data.Jlist(Diagnostic)

module Alternative_result : Data.S with type t = alternative_result =
struct
  type t = alternative_result
  let jtype =
    Data.declare ~package ~name:"alternativeResult" @@
    Package.(Jrecord [
        "location", RangeOpt.jtype ;
        "diagnostic", Diagnostic_list.jtype ;
        "debug", Debug_info.jtype ;
      ])

  let to_json ar =
    `Assoc [
      "location" , RangeOpt.to_json ar.location ;
      "diagnostic" , Diagnostic_list.to_json ar.diagnostic ;
      "debug", Debug_info.to_json ar.debug ;
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Alternative_result"
end

module Alternative_result_list = Data.Jlist(Alternative_result)

module Result : Data.S with type t = result =
struct
  type t = result
  let jtype =
    Data.declare ~package ~name:"result" @@
    Package.(Jrecord [
        "diagnostic", Diagnostic.jtype ;
        "alts", Alternative_result_list.jtype ;
      ])

  let to_json r =
    `Assoc [
      "diagnostic" , Diagnostic.to_json r.diagnostic ;
      "alts", Alternative_result_list.to_json r.alts ;
    ]

  let of_json _ = failwith "Wp.PatternDebugger.Result"
end

(* -------------------------------------------------------------------------- *)
(* --- Local tokenizer                                                    --- *)
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
      if tok = "" then "unexpected end of strategy" else
        Printf.sprintf "unexpected token %S" tok in
    raise (ParseError (loc, msg))

let parse_string s =
  Logic_env.builtin_types_as_typenames () ;
  let finally = Logic_env.reset_typenames in
  let work () = parse_string s in
  Fun.protect ~finally work

(* -------------------------------------------------------------------------- *)
(* --- Debugger                                                           --- *)
(* -------------------------------------------------------------------------- *)

(* Custom printers for clause and selection, using TIP printer:
   we want printed values to be consistent with the current printer. *)

let rec pp_selection printer fmt = function
  | Tactical.Empty ->
    Format.pp_print_string fmt "None."
  | Inside(_,t) ->
    Format.fprintf fmt "Term:  %a" printer#pp_term t
  | Clause (Goal p) -> Format.fprintf fmt "Goal:  %a" printer#pp_pred p
  | Clause (Step s) -> printer#pp_step fmt s
  | Compose(Cint k) ->
    Format.fprintf fmt "Const: %a" Z.pretty k
  | Compose(Range(a,b)) ->
    Format.fprintf fmt "Range: %d..%d" a b
  | Compose(Code(e,_,_)) ->
    Format.fprintf fmt "@[<hov 2>Calc:  %a@]" printer#pp_term e ;
  | Multi es ->
    Format.fprintf fmt "@[<hov 2>Multi:" ;
    List.iter (Format.fprintf fmt "@ %a;" @@ pp_selection printer) es ;
    Format.fprintf fmt "@]"

let extract_matchings debug_table printer ?select ?params sigma =
  let pp_selection = pp_selection printer in
  let matched = ref [] in
  (* Extracting matchings ... *)
  let iter name m =
    let target = printer#selection_to_target m in
    let pattern =
      match Hashtbl.find_opt debug_table name with
      | Some pattern -> Format.asprintf "%a" Pattern.pp_pattern pattern
      | None -> name (* this is a user defined name *)
    in
    let value = Format.asprintf "%a" pp_selection m in
    matched := { name ; pattern ; value ; target } :: !matched
  in
  Pattern.iter_sigma iter sigma ;
  let params =
    (* Extracting parameters *)
    match params with
    | None -> []
    | Some l ->
      let to_matching (name, selection) =
        let target = printer#selection_to_target selection in
        let pattern = Format.asprintf "Parameter %S" name in
        let value = Format.asprintf "%a" pp_selection selection in
        { name ; pattern ; value ; target }
      in
      List.map to_matching l
  in
  let selection =
    (* Extracting selection *)
    match select with
    | None -> None
    | Some selection ->
      let target = printer#selection_to_target selection in
      let pattern = "Selection" in
      let value = Format.asprintf "%a" pp_selection selection in
      Some { name = "None" ; pattern ; value ; target }
  in
  { selection ; params ; matched = !matched }

let parameters env sigma tactical params =
  let fold_parameter (diags, sels) (a, v) =
    let sels = (a.ProofStrategy.value, Pattern.select sigma v) :: sels in
    let diags =
      try ProofStrategy.configure env tactical sigma (a, v) ; diags
      with Pattern.TypeError(loc, message) -> error ~loc ~message :: diags
    in
    diags, sels
  in
  List.fold_left fold_parameter ([], []) params

let pool sequent =
  Lang.new_pool ~vars:(Conditions.vars_seq sequent) ()


let debug_tactic env ctxt loc (t: ProofStrategy.tactic) node =
  let result = alternative_result ~loc in
  match node with
  | None -> result [valid ~loc ~message:"Valid tactic"] ()
  | Some node ->
    let printer = WpTipApi.lookup_printer node in
    let debug_table = ProofStrategy.debug_table ctxt in
    let get_matchings = extract_matchings debug_table printer in
    let sequent = snd @@ Wpo.compute @@ ProofEngine.goal node in
    let rec apply_all sigma = function
      | [] -> (* we successfully matched all patterns *)
        let goal = if t.lookup = [] then Some (snd sequent) else None in
        let tactical = ProofStrategy.tactical t.tactic in
        let select = ProofStrategy.select sigma ?goal t.select in
        let diags, params = parameters env sigma tactical t.params in
        let debug = get_matchings ~select ~params sigma in
        begin match diags with
          | _ :: _ -> (* parameters configuration failed *)
            result diags ~debug ()
          | [] -> (* now try to apply the tactic *)
            let pool = pool sequent in
            let console = new ProofScript.console ~pool ~title:"debug" in
            let diagnositc =
              match Lang.local ~pool (tactical#select console) select with
              | exception exn ->
                let message =
                  Format.asprintf
                    "Tactic configuration error (%s)"
                    (Printexc.to_string exn) in
                [ error ~loc ~message ]
              | Not_configured ->
                [ error ~loc ~message:"Tactic configuration error" ]
              | Not_applicable ->
                [ warning ~loc ~message:"Tactic cannot be applied" ]
              | Applicable _ ->
                [ valid ~loc ~message:"Applicable tactic" ]
            in
            result diagnositc ~debug ()
        end

      | p::ps ->
        match Pattern.psequent p sigma sequent with
        | Some sigma -> (* there are still patterns to match *)
          apply_all sigma ps
        | None -> (* we failed to match all patterns *)
          let loc = Pattern.pattern_loc p.pattern in
          let debug = get_matchings sigma in
          let diag = warning ~loc ~message:"Unmatched pattern" in
          result [diag] ~debug ()
    in apply_all Pattern.empty t.lookup

let debug_alternative env ctxt strategy node alt =

  let mk_result diag =
    Some (alternative_result ~loc:alt.ProofStrategy.loc diag ())
  in
  try
    match alt with
    | ProofStrategy.{ value = Default } ->
      None (* *silently* ignored (no loc to display, nor useful feedback) *)

    | { value = Strategy s }  ->
      if s.value <> strategy then ProofStrategy.typecheck_strategy env s ;
      let reason = "Debugging is not recursively applied" in
      mk_result [ignored ~loc:s.loc ~reason]

    | { value = Auto a }  ->
      ProofStrategy.typecheck_auto env a ;
      let reason = "Debugging is not recursively applied" in
      mk_result [ignored ~loc:a.loc ~reason]

    | { value = Provers (provers, _) }  ->
      let diag prover =
        try ProofStrategy.typecheck_prover env prover ; None
        with Pattern.TypeError (loc, message) -> Some(error ~loc ~message)
      in
      let reason = "Debugging does not execute provers" in
      mk_result @@ begin match List.filter_map diag provers with
        | [] -> [ignored ~loc:alt.loc ~reason]
        | l -> l
      end

    | { value = Tactic t ; loc = alt_loc }  ->
      ProofStrategy.typecheck_tactic env t ;
      Some (debug_tactic env ctxt alt_loc t node)

  with Pattern.TypeError(loc, message) ->
    mk_result [error ~loc ~message]

exception Empty

let debug strategy ?node () =
  let ctxt = ProofStrategy.context () in
  let env = Pattern.env ~raise:true () in

  let parse string =
    match parse_string string with
    | [] ->
      raise Empty
    | Logic_ptree.{ lexpr_node = PLnamed(value, p) } :: ps ->
      value, ProofStrategy.parse_alternatives ctxt (p :: ps)
    | ps ->
      "", ProofStrategy.parse_alternatives ctxt ps
  in
  match parse strategy with
  | exception ParseError (loc, message)
  | exception Pattern.TypeError (loc, message) ->
    failed_strategy ~loc ~message ()
  | exception Empty ->
    let diagnostic =
      { message = "Empty strategy" ; severity = `Ignored ; location = None } in
    { diagnostic ; alts = []}
  | exception exn ->
    let message = Printf.sprintf "Failure (%s)" (Printexc.to_string exn) in
    failed_strategy ~message ()
  | strategy, alternatives ->
    let diagnostic = { message = "" ; severity = `Ok ; location = None } in
    let alts =
      List.filter_map
        (debug_alternative env ctxt strategy node) alternatives in
    { diagnostic ; alts }

let () =
  let signature = Request.signature ~output:(module Result) () in
  let get_text = Request.param signature ~name:"strategy"
      ~descr:(Md.plain "Strategy text")
      ~default:"" (module Data.Jstring) in
  let get_node = Request.param_opt signature ~name:"node"
      ~descr:(Md.plain "Node to check strategy on (optional)")
      (module WpTipApi.Node) in
  Request.register_sig ~package ~kind:`GET ~name:"debug"
    ~descr:(Md.plain "Debug strategy")
    signature
    begin fun rq () ->
      let text = get_text rq in
      let node = get_node rq in
      debug text ?node ()
    end

(* -------------------------------------------------------------------------- *)
