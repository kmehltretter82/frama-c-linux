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
  | Provers of string loc list * int option (* timeout *)
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

module S = Datatype.Make
    (struct
      include Datatype.Undefined
      type t = strategy
      let reprs = [{
          name = { loc = Location.unknown ; value = "" };
          alternatives = [];
        }]
      let name = "Wp.ProofStrategy.S"
      let structural_descr = Structural_descr.t_abstract
      let rehash = Datatype.identity
      let mem_project = Datatype.never_any_project
    end)

module Strategies = State_builder.Hashtbl(Datatype.String.Hashtbl)(S)
    (struct
      let size = 0
      let name = "Wp.ProofStrategy.Registry"
      let dependencies = [Ast.self;Kid.self]
    end)

(* -------------------------------------------------------------------------- *)
(* --- Alternative Parser                                                 --- *)
(* -------------------------------------------------------------------------- *)

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
      parse_provers ctxt provers (Some time) ps
    | PLconstant (StringConstant value) ->
      parse_provers ctxt ( { loc ; value } :: provers ) timeout ps
    | _ -> ctxt.error loc "Invalid prover specification"

let parse_name ctxt ~kind p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar value
  | PLapp(value,[],[])
  | PLconstant(StringConstant value)
    -> { loc ; value }
  | _ -> ctxt.error loc "%s name expected" kind

let parse_lookup penv ?(goal=false) ?(hyps=false) p =
  match p.lexpr_node with
  | PLrange(None,Some p) ->
    { goal ; hyps ; head = false ; pattern = Pattern.pa_pattern penv p }
  | _ ->
    { goal ; hyps ; head = true ; pattern = Pattern.pa_pattern penv p }

let rec parse_tactic ctxt penv ~tactic ~select ~lookup ~params ~children ~default ps =
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
    let cc = parse_tactic ctxt penv ~tactic in
    match p.lexpr_node with
    | PLapp("\\when",[],qs) ->
      let qs = List.map (parse_lookup ~hyps:true penv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\for",[],qs) ->
      let qs = List.map (parse_lookup ~goal:true penv) qs in
      let lookup = List.rev_append qs lookup in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\lookup",[],qs) ->
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
      let prefix = parse_name ctxt ~kind:"Child" prefix in
      let strategy = parse_name ctxt ~kind:"Strategy" strategy in
      let children = (prefix,strategy)::children in
      cc ~select ~lookup ~params ~children ~default ps
    | PLapp("\\default",[],[strategy]) ->
      if default <> None then ctxt.error loc "Duplicate \\default parameter" ;
      let default = Some (parse_name ctxt ~kind:"Strategy" strategy) in
      cc ~select ~lookup ~params ~children ~default ps
    | _ -> ctxt.error loc "Tactic parameter expected"

let parse_alternative ctxt p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLvar value | PLapp(value,[],[]) -> Strategy { loc ; value }
  | PLapp("\\prover",[],ps) ->
    let prvs,timeout = parse_provers ctxt [] None ps in
    Provers(prvs,timeout)
  | PLapp("\\tactic",[value],ps) ->
    parse_tactic ctxt (Pattern.context ctxt) ~tactic:{ loc ; value }
      ~select:[] ~lookup:[] ~params:[] ~children:[] ~default:None ps
  | _ -> ctxt.error loc "Strategy definition expected"

(* -------------------------------------------------------------------------- *)
(* --- Strategy Parser                                                    --- *)
(* -------------------------------------------------------------------------- *)

let parse_strategy_name ctxt loc = function
  | [] -> ctxt.error loc "Empty strategy"
  | p::ps ->
    match p.lexpr_node with
    | PLnamed(value,p) -> { loc ; value }, p::ps
    | _ -> ctxt.error loc "Missing strategy name (strategy A: ...)"

let parse_strategy ctxt loc ps =
  let name,ps = parse_strategy_name ctxt loc ps in
  try
    let old = Strategies.find name.value in
    ctxt.error loc "Duplicate strategy definition ('%s', at %a)"
      name.value Location.pretty old.name.loc
  with Not_found ->
    let alternatives = List.map (parse_alternative ctxt) ps in
    let id = fresh () in
    Strategies.add name.value { name ; alternatives } ;
    Ext_id id

let () = Acsl_extension.register_global "strategy" parse_strategy false

(* -------------------------------------------------------------------------- *)
(* --- Proof Parser                                                       --- *)
(* -------------------------------------------------------------------------- *)

module LemmaProofs =
  State_builder.Hashtbl(Datatype.String.Hashtbl)(Datatype.String)
    (struct
      let size = 0
      let name = "Wp.ProofStrategy.LemmaProofs"
      let dependencies = [Ast.self;Kid.self]
    end)

module FunctionProofs =
  State_builder.Hashtbl(Datatype.String.Hashtbl)(Datatype.String)
    (struct
      let size = 0
      let name = "Wp.ProofStrategy.FunctionProofs"
      let dependencies = [Ast.self;Kid.self]
    end)

module PropertyProofs =
  State_builder.Hashtbl(Datatype.String.Hashtbl)(Datatype.String)
    (struct
      let size = 0
      let name = "Wp.ProofStrategy.PropertyProofs"
      let dependencies = [Ast.self;Kid.self]
    end)

let rec parse_hints ctxt names p =
  let loc = p.lexpr_loc in
  match p.lexpr_node with
  | PLnamed(value,p) -> parse_hints ctxt ({ loc ; value } :: names) p
  | PLvar value | PLapp(value,[],[]) -> names, { loc ; value }
  | _ -> ctxt.error loc "Invalid proof specification"

let parse_proofs ~kind ~mem ~add ctxt _loc ps =
  List.iter
    (fun p ->
       let names, st = parse_hints ctxt [] p in
       List.iter
         (fun name ->
            if mem name.value then
              ctxt.error name.loc
                "Duplicate proof for %s '%s'" kind name.value ;
            if not (Strategies.mem st.value) then
              ctxt.error st.loc "Unknown proof strategy %S" st.value ;
            add name.value st.value
         ) names
    ) ps ;
  Ext_id 0

let () = Acsl_extension.register_global "prove_lemma" (
    parse_proofs
      ~kind:"lemma"
      ~mem:LemmaProofs.mem
      ~add:LemmaProofs.add
  ) false

let () = Acsl_extension.register_global "prove_function" (
    parse_proofs
      ~kind:"function"
      ~mem:FunctionProofs.mem
      ~add:FunctionProofs.add
  ) false

let () = Acsl_extension.register_global "prove_property" (
    parse_proofs
      ~kind:"property"
      ~mem:PropertyProofs.mem
      ~add:PropertyProofs.add
  ) false

(* -------------------------------------------------------------------------- *)
(* --- Strategy Resolution                                                --- *)
(* -------------------------------------------------------------------------- *)

let strategies ?kf ?lemma ?pred () =
  let collect find name = try [find name] with Not_found -> [] in
  let list find xs = List.concat (List.map (collect find) xs) in
  let option find = function None -> [] | Some a -> find a in
  option (fun p -> list PropertyProofs.find p.pred_name) pred @
  option (collect LemmaProofs.find) lemma @
  option (fun kf ->
      collect FunctionProofs.find (Kernel_function.get_name kf)) kf

let lookup (target : Property.t) : strategy list =
  List.map Strategies.find @@
  let rec forip (ip : Property.t) =
    match ip with
    | IPBehavior p ->
      strategies ~kf:p.ib_kf ()
    | IPLemma p ->
      strategies ~lemma:p.il_name ~pred:p.il_pred.tp_statement ()
    | IPCodeAnnot p ->
      let kf = p.ica_kf in
      begin
        match p.ica_ca.annot_content with
        | AInvariant(_,_,tp)
        | AAssert(_,tp)
          -> strategies ~kf ~pred:tp.tp_statement ()
        | AAssigns _ | AVariant _ | AAllocation _  | APragma _
        | AStmtSpec _ | AExtended _ ->
          strategies ~kf ()
      end
    | IPPredicate p ->
      strategies ~kf:p.ip_kf ~pred:p.ip_pred.ip_content.tp_statement ()
    | IPComplete p | IPDisjoint p -> strategies ~kf:p.ic_kf ()
    | IPFrom p -> strategies ~kf:p.if_kf ()
    | IPAssigns p -> strategies ~kf:p.ias_kf ()
    | IPAllocation p -> strategies ~kf:p.ial_kf ()
    | IPDecrease p -> strategies ~kf:p.id_kf ()
    | IPReachable p -> strategies ?kf:p.ir_kf ()
    | IPPropertyInstance { ii_kf = kf ; ii_pred = Some p } ->
      strategies ~kf ~pred:p.ip_content.tp_statement ()
    | IPPropertyInstance { ii_ip } -> forip ii_ip
    | IPTypeInvariant p -> strategies ~pred:p.iti_pred ()
    | IPGlobalInvariant p -> strategies ~pred:p.igi_pred ()
    | IPOther { io_loc = (OLContract kf | OLStmt(kf,_)) } ->
      strategies ~kf ()
    | IPOther { io_loc = OLGlob _ }
    | IPExtended _
    | IPAxiomatic _
      -> []
  in forip target

(* -------------------------------------------------------------------------- *)
