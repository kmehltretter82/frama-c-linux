(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Cil_types
open Cil_datatype
open Logic_typing
open Logic_ptree
open Pattern
module D = Datatype

(* -------------------------------------------------------------------------- *)
(* --- Proof Strategy Engine                                              --- *)
(* -------------------------------------------------------------------------- *)

type 'a loc = { loc : location ; value : 'a }

(* Abstract Syntax Tree: must be stdlib-marshallable *)
type strategy = {
  name: string loc ;
  alternatives: alternative list ;
}

and alternative =
  | Strategy of string loc
  | Provers of string loc list * float option (* timeout *)
  | Auto of string loc (* deprecated -wp-auto *)
  | Tactic of {
      tactic : string loc ;
      select : value list ;
      lookup : lookup list ;
      params : (string loc * value) list ;
      children : (string loc * string loc) list ; (* name prefix and strategy *)
      default: string loc option; (* None is default *)
    }

(* -------------------------------------------------------------------------- *)
(* --- Unique Identifiers                                                 --- *)
(* -------------------------------------------------------------------------- *)

module Kid = State_builder.Int_ref
    (struct
      let default () = 0
      let name = "Wp.ProofStrategy.Kid"
      let dependencies = [Ast.self]
    end)

let fresh () = let id = succ @@ Kid.get () in Kid.set id ; id

(* -------------------------------------------------------------------------- *)
(* --- Proof Strategy Registry                                            --- *)
(* -------------------------------------------------------------------------- *)

module S = D.Make
    (struct
      include D.Undefined
      type t = strategy
      let reprs = [{
          name = { loc = Location.unknown ; value = "" };
          alternatives = [];
        }]
      let name = "Wp.ProofStrategy.S"
      let structural_descr = Structural_descr.t_abstract
      let rehash = D.identity
      let mem_project = D.never_any_project
    end)

module Strategies = State_builder.Hashtbl(D.String.Hashtbl)(S)
    (struct
      let size = 0
      let name = "Wp.ProofStrategy.Registry"
      let dependencies = [Ast.self;Kid.self]
    end)

(* -------------------------------------------------------------------------- *)
(* --- Alternative Parser                                                 --- *)
(* -------------------------------------------------------------------------- *)

let debug fmt p =
  Format.fprintf fmt "@[<hov 2>at: %a@]" Logic_print.print_lexpr p

let rec parse_provers ctxt provers timeout = function
  | [] -> List.rev provers,timeout
  | p::ps ->
    let loc = p.lexpr_loc in
    match p.lexpr_node with
    | PLconstant (IntConstant t) ->
      let time = try int_of_string t with Invalid_argument _ ->
        ctxt.error loc "Invalid timeout" in
      if time < 0 then ctxt.error loc "Invalid timeout" ;
      if timeout <> None then ctxt.error loc "Duplicate timeout" ;
      parse_provers ctxt provers (Some (float time)) ps
    | PLconstant (FloatConstant t) ->
      let time = try float_of_string t with Invalid_argument _ ->
        ctxt.error loc "Invalid timeout" in
      if time < 0.0 then ctxt.error loc "Invalid timeout" ;
      if timeout <> None then ctxt.error loc "Duplicate timeout" ;
      parse_provers ctxt provers (Some time) ps
    | PLconstant (StringConstant value) ->
      parse_provers ctxt ( { loc ; value } :: provers ) timeout ps
    | _ -> ctxt.error loc "Invalid prover specification (%a)" debug p

let parse_name ctxt ~kind ?check p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar value
  | PLapp(value,[],[])
  | PLconstant(StringConstant value)
    ->
    Option.iter (fun f -> f loc value) check ;
    { loc ; value }
  | _ -> ctxt.error loc "%s name expected (%a)" kind debug p

let parse_lookup penv ?(goal=false) ?(hyps=false) p =
  match p.lexpr_node with
  | PLrange(None,Some p) ->
    { goal ; hyps ; head = false ; pattern = Pattern.pa_pattern penv p }
  | _ ->
    { goal ; hyps ; head = true ; pattern = Pattern.pa_pattern penv p }

let rec parse_tactic_params ctxt penv
    ~tactic ~select ~lookup ~params ~children ~default ps =
  match ps with
  | [] -> Tactic {
      tactic ;
      select = List.rev select ;
      lookup = List.rev lookup ;
      params = List.rev params ;
      children = List.rev children ;
      default ;
    }
  | p::ps ->
    let loc = p.lexpr_loc in
    let cc = parse_tactic_params ctxt penv ~tactic in
    match p.lexpr_node with
    | PLapp("\\when",[],qs) ->
      let qs = List.map (parse_lookup ~hyps:true penv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\for",[],qs) ->
      let qs = List.map (parse_lookup ~goal:true penv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\pattern",[],qs) ->
      let qs = List.map (parse_lookup ~goal:true ~hyps:true penv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\select",[],vs) ->
      let vs = List.map (Pattern.pa_value penv) vs in
      let select = List.rev_append vs select in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\param",[],[param;value]) ->
      let param = parse_name ctxt ~kind:"Parameter" param in
      let value = Pattern.pa_value penv value in
      let params = (param,value)::params in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\child",[],[prefix;strategy]) ->
      let subgoal = parse_name ctxt ~kind:"Subgoal" prefix in
      let strategy = parse_name ctxt ~kind:"Strategy" strategy in
      let children = (subgoal,strategy)::children in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\children",[],[strategy]) ->
      if default <> None then ctxt.error loc "Duplicate \\children parameter" ;
      let default = Some (parse_name ctxt ~kind:"Strategy" strategy) in
      cc ~select ~lookup ~params ~children ~default ps
    | _ -> ctxt.error loc "Tactic parameter expected (%a)" debug p

let parse_alternatives ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar value | PLapp(value,[],[]) -> [ Strategy { loc ; value } ]
  | PLapp("\\prover",[],ps) ->
    let prvs,timeout = parse_provers ctxt [] None ps in
    [ Provers(prvs,timeout) ]
  | PLapp("\\tactic",[],p::ps) ->
    let tactic = parse_name ctxt ~kind:"tactic" p in
    [ parse_tactic_params ctxt (Pattern.context ctxt) ~tactic
        ~select:[] ~lookup:[] ~params:[] ~children:[] ~default:None ps ]
  | PLapp("\\auto",[],ps) ->
    List.map (fun p -> Auto (parse_name ctxt ~kind:"auto" p)) ps
  | _ -> ctxt.error loc "Strategy definition expected (%a)" debug p

(* -------------------------------------------------------------------------- *)
(* --- Strategy Parser                                                    --- *)
(* -------------------------------------------------------------------------- *)

let parse_strategy_name ctxt loc = function
  | [] -> ctxt.error loc "Empty strategy"
  | p::ps ->
    match p.lexpr_node with
    | PLnamed(value,p) -> { loc ; value }, p::ps
    | _ -> ctxt.error loc "Missing strategy name (%a)" debug p

let parse_strategy ctxt loc ps =
  let name,ps = parse_strategy_name ctxt loc ps in
  try
    let old = Strategies.find name.value in
    ctxt.error loc "Duplicate strategy definition ('%s', at %a)"
      name.value Location.pretty old.name.loc
  with Not_found ->
    let alternatives = List.concat @@ List.map (parse_alternatives ctxt) ps in
    let id = fresh () in
    Strategies.add name.value { name ; alternatives } ;
    Ext_id id

let () = Acsl_extension.register_global "strategy" parse_strategy false

(* -------------------------------------------------------------------------- *)
(* --- Proof Parser                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Hints = State_builder.List_ref
    (D.Pair(D.String)(D.List(D.String)))
    (struct
      let name = "Wp.ProofStrategy.Hints"
      let dependencies = [Ast.self]
    end)

let parse_hints ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar x -> [x]
  | PLconstant(StringConstant x) -> String.split_on_char ',' x
  | _ -> ctxt.error loc "Proof hint expected (see -wp-proop) (%a)" debug p

let parse_proofs ctxt loc ps =
  let name , ps = parse_strategy_name ctxt loc ps in
  let strategy = name.value in
  if not (Strategies.mem strategy) then
    ctxt.error name.loc "Unknown strategy '%s'" strategy ;
  let props = List.concat @@ List.map (parse_hints ctxt) ps in
  Hints.set (Hints.get () @ [ strategy , props ]) ;
  Ext_id 0

let () = Acsl_extension.register_global "prove" parse_proofs false

(* -------------------------------------------------------------------------- *)
(* --- Strategy Resolution                                                --- *)
(* -------------------------------------------------------------------------- *)

let name s = s.name.value
let find a = try Some (Strategies.find a) with Not_found -> None
let resolve name =
  try Some (Strategies.find name.value)
  with Not_found ->
    Wp_parameters.error ~source:(fst name.loc) ~once:true
      "Strategy '%s' undefined (skipped)." name.value ;
    None

(* -------------------------------------------------------------------------- *)
(* --- Strategy Hints                                                     --- *)
(* -------------------------------------------------------------------------- *)

let hints pid =
  List.map (fun (name,_) -> Strategies.find name) @@
  List.filter (fun (_,ps) ->
      WpPropId.select_by_name ps pid
    ) (Hints.get ())

(* -------------------------------------------------------------------------- *)
(* --- Strategy Forward Step                                              --- *)
(* -------------------------------------------------------------------------- *)

let alternatives s = s.alternatives

let provers = function
  | Provers(ps,tm) ->
    List.fold_right
      (fun p ps ->
         match VCS.parse_prover p.value with
         | Some p -> p::ps
         | None ->
           Wp_parameters.error ~source:(fst p.loc) ~once:true
             "Prover '%s' not found (skipped)." p.value ; ps
      ) ps [],
    begin match tm with
      | Some tm -> tm
      | None -> float @@ Wp_parameters.Timeout.get ()
    end
  | Strategy _ | Tactic _ | Auto _ -> [],0.0

let fallback = function
  | Strategy s -> resolve s
  | Tactic _ | Auto _ | Provers _ -> None

(* -------------------------------------------------------------------------- *)
(* --- Strategy Tactical Step                                             --- *)
(* -------------------------------------------------------------------------- *)

let tactical a =
  try Tactical.lookup ~id:a.value with Not_found ->
    Wp_parameters.error ~source:(fst a.loc) ~once:true
      "Tactical '%s' not found (skipped alternative)." a.value ;
    raise Not_found

let parameter (t : Tactical.tactical) a =
  try List.find (fun p -> Tactical.pident p = a.value) t#params
  with Not_found ->
    Wp_parameters.error ~source:(fst a.loc) ~once:true
      "Parameter '%s' not found (skipped alternative)." a.value ;
    raise Not_found

let rec bind sigma sequent = function
  | [] -> sigma
  | lookup::binders ->
    match Pattern.psequent lookup sigma sequent with
    | None -> raise Not_found
    | Some sigma -> bind sigma sequent binders

let select sigma = function
  | [] -> Tactical.Empty
  | [v] -> Pattern.select sigma v
  | vs -> Tactical.Multi (List.map (Pattern.select sigma) vs)

let configure tactic sigma (a,v) =
  match parameter tactic a with
  | Checkbox fd ->
    begin
      try tactic#set_field fd (Pattern.bool v)
      with Not_found ->
        Wp_parameters.error ~source:(fst a.loc)
          "Expected boolean for parameter '%s' (%a)" a.value
          Pattern.pp_value v ;
        raise Not_found
    end
  | Spinner(fd,_) ->
    begin
      let value = Pattern.select sigma v in
      match Tactical.get_int value with
      | Some v -> tactic#set_field fd v
      | None ->
        Wp_parameters.error ~source:(fst a.loc)
          "Expected integer for parameter '%s'@ (%a)" a.value
          Tactical.pp_selection value ;
        raise Not_found
    end
  | Composer(fd,_) -> tactic#set_field fd (Pattern.select sigma v)
  | Selector(fd,vs,_) ->
    begin
      try
        let id = Pattern.string v in
        let v = List.find (fun v -> v.Tactical.vid = id) vs in
        tactic#set_field fd v.value
      with Not_found ->
        Wp_parameters.error ~source:(fst a.loc)
          "Expected string for parameter '%s'@ (%a)" a.value
          Pattern.pp_value v ;
        raise Not_found
    end
  | Search(fd,_,lookup) ->
    begin
      try
        let id = Pattern.string v in
        let v = lookup id in
        tactic#set_field fd (Some v)
      with Not_found ->
        Wp_parameters.error ~source:(fst a.loc)
          "Expected string for parameter '%s'@ (%a)" a.value
          Pattern.pp_value v ;
        raise Not_found
    end

let subgoal (children : (string loc * string loc) list)
    (default : string loc option) (goal,node) =
  let hint = List.find_map (fun (g,s) ->
      if String.starts_with ~prefix:g.value goal then Some s else None
    ) children in
  begin
    match hint, default with
    | None, None -> ()
    | Some s , _ | None , Some s ->
      if not @@ Strategies.mem s.value then
        Wp_parameters.error ~source:(fst s.loc)
          "Unknown strategy '%s' (skipped)" s.value
      else ProofEngine.set_hint node s.value
  end ; node

let tactic tree node strategy = function
  | Strategy _ | Auto _ | Provers _ -> None
  | Tactic t ->
    try
      let tactic = tactical t.tactic in
      let pool = ProofEngine.pool tree in
      let title = tactic#title in
      let ctxt = ProofEngine.node_context node in
      let sequent = snd @@ Wpo.compute @@ ProofEngine.goal node in
      let console = new ProofScript.console ~pool ~title in
      let subgoals = WpContext.on_context ctxt
          begin fun () ->
            let sigma = bind Pattern.empty sequent t.lookup in
            List.iter (configure tactic sigma) t.params ;
            let selection = select sigma t.select in
            match tactic#select console selection with
            | exception (Not_found | Exit) -> raise Not_found
            | Not_applicable ->
              raise Not_found
            | exception exn when Wp_parameters.protect exn ->
              Wp_parameters.warning ~source:(fst t.tactic.loc)
                "Tactical '%s' configuration error (%s)"
                t.tactic.value (Printexc.to_string exn) ;
              raise Not_found
            | Not_configured ->
              Wp_parameters.error ~source:(fst t.tactic.loc)
                "Tactical '%s' configuration error"
                t.tactic.value ;
              raise Not_found
            | Applicable process ->
              let strategy = strategy.name.value in
              let script = ProofScript.jtactic ~strategy tactic selection in
              let fork = ProofEngine.fork tree ~anchor:node script process in
              snd @@ ProofEngine.commit fork
          end () in
      Some (List.map (subgoal t.children t.default) subgoals)
    with Not_found -> None

(* -------------------------------------------------------------------------- *)
