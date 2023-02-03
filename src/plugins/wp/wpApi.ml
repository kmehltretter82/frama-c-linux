(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(* -------------------------------------------------------------------------- *)
(* --- Server API for WP                                                  --- *)
(* -------------------------------------------------------------------------- *)

module P = Server.Package
module D = Server.Data
module R = Server.Request
module S = Server.States
module Md = Markdown
module AST = Server.Kernel_ast

let package = P.package ~plugin:"wp" ~title:"WP Plugin" ()

(* -------------------------------------------------------------------------- *)
(* --- WPO Index                                                          --- *)
(* -------------------------------------------------------------------------- *)

module INDEX = State_builder.Ref
    (Datatype.Make
       (struct
         include Datatype.Undefined
         type t = (string,Wpo.t) Hashtbl.t
         let name = "WpApi.INDEX.Datatype"
         let reprs = [ Hashtbl.create 0 ]
         let mem_project = Datatype.never_any_project
       end))
    (struct
      let name = "WpAPpi.INDEX"
      let dependencies = [ Ast.self ]
      let default () = Hashtbl.create 0
    end)

module WPO : D.S with type t = Wpo.t =
struct
  type t = Wpo.t
  let jtype = D.declare ~package ~name:"goal"
      ~descr:(Md.plain "Proof Obligations") (Jkey "wpo")
  let of_json js = Hashtbl.find (INDEX.get ()) (Json.string js)
  let to_json g =
    let id = g.Wpo.po_gid in
    let index = INDEX.get () in
    if not (Hashtbl.mem index id) then Hashtbl.add index id g ;
    `String id
end

(* -------------------------------------------------------------------------- *)
(* --- VCS Provers                                                        --- *)
(* -------------------------------------------------------------------------- *)

module PROVER =
struct
  type t = VCS.prover
  let jtype = D.declare ~package ~name:"prover"
      ~descr:(Md.plain "Prover Identifier") (Jkey "prover")
  let to_json prv = `String (VCS.name_of_prover prv)
  let of_json js =
    match VCS.parse_prover @@ Json.string js with
    | Some prv -> prv
    | None -> D.failure "Unknown prover name"
end

module RESULT =
struct
  type t = VCS.result
  let jtype = D.declare ~package ~name:"result"
      ~descr:(Md.plain "Prover Result")
      (Jrecord [
          "descr", Jstring ;
          "cached", Jboolean ;
          "verdict", Jstring ;
          "solverTime", Jnumber ;
          "proverTime", Jnumber ;
          "proverSteps", Jnumber ;
        ])
  let of_json _ = failwith "Not implemented"
  let to_json (r : VCS.result) = `Assoc [
      "descr", `String (Pretty_utils.to_string VCS.pp_result r) ;
      "cached", `Bool r.cached ;
      "verdict", `String (VCS.name_of_verdict r.verdict) ;
      "solverTime", `Float r.solver_time ;
      "proverTime", `Float r.prover_time ;
      "proverSteps", `Int r.prover_steps ;
    ]
end

module STATS =
struct
  type t = bool * Stats.stats
  let jtype = D.declare ~package ~name:"stats"
      ~descr:(Md.plain "Prover Result")
      (Jrecord [
          "summary", Jstring;
          "tactics", Jnumber;
          "proved", Jnumber;
          "total", Jnumber;
        ])
  let to_json (smoke,cs) : Json.t =
    let verdict = match cs.Stats.verdict with
      | VCS.Valid -> if smoke then "Doomed" else "Valid"
      | VCS.Unknown -> if smoke then "Passed" else "Unknown"
      | Failed -> "Failure"
      | NoResult -> "No Result"
      | Computing _ -> "Computing"
      | Timeout -> "Timeout"
      | Stepout -> "Stepout"
      | Invalid -> "Invalid"
    in
    let summary = Format.asprintf "%s%a" verdict
        (Stats.pp_stats ~shell:false ~cache:Update) cs
    in `Assoc [
      "summary", `String summary ;
      "tactics", `Int cs.tactics ;
      "proved", `Int cs.proved ;
      "total", `Int (Stats.proofs cs) ;
    ]
end

(* -------------------------------------------------------------------------- *)
(* --- WPO Array                                                          --- *)
(* -------------------------------------------------------------------------- *)

let gmodel : Wpo.t S.model = S.model ()

let () = S.column gmodel ~name:"property"
    ~descr:(Md.plain "Property Marker")
    ~data:(module AST.Marker)
    ~get:(fun g -> Printer_tag.PIP (WpPropId.property_of_id g.Wpo.po_pid))

let get_kf g = match g.Wpo.po_idx with
  | Function(kf,_) -> Some kf
  | Axiomatic _ -> None

let get_bhv g = match g.Wpo.po_idx with
  | Function(_,bhv) -> bhv
  | Axiomatic _ -> None

let get_thy g = match g.Wpo.po_idx with
  | Function _ -> None
  | Axiomatic ax -> ax

let get_stats g = Wpo.is_smoke_test g, ProofEngine.consolidated g

let () = S.column gmodel ~name:"name"
    ~descr:(Md.plain "Informal name") ~data:(module D.Jstring)
    ~get:(fun g -> g.Wpo.po_name)

let () = S.column gmodel ~name:"fct"
    ~descr:(Md.plain "Associated function, if any")
    ~data:(module D.Joption(AST.Kf)) ~get:get_kf

let () = S.column gmodel ~name:"bhv"
    ~descr:(Md.plain "Associated behavior, if any")
    ~data:(module D.Joption(D.Jstring)) ~get:get_bhv

let () = S.column gmodel ~name:"thy"
    ~descr:(Md.plain "Associated axiomatic, if any")
    ~data:(module D.Joption(D.Jstring)) ~get:get_thy

let () = S.column gmodel ~name:"smoke"
    ~descr:(Md.plain "Smoke Test Goal")
    ~data:(module D.Jbool) ~get:Wpo.is_smoke_test

let () = S.column gmodel ~name:"passed"
    ~descr:(Md.plain "Successfull Goal")
    ~data:(module D.Jbool) ~get:Wpo.is_passed

let () = S.column gmodel ~name:"stats"
    ~descr:(Md.plain "Verdict Details")
    ~data:(module STATS) ~get:get_stats

(*TODO: remove this field! *)
let () = S.column gmodel ~name:"results"
    ~descr:(Md.plain "Prover Results")
    ~data:(module D.Jlist(D.Jpair(PROVER)(RESULT)))
    ~get:Wpo.get_results

let _garray = S.register_array ~package ~name:"goals"
    ~descr:(Md.plain "Generated Goals")
    ~key:(fun g -> g.Wpo.po_gid)
    ~keyName:"wpo"
    ~keyType:(Jkey "wpo")
    ~iter:Wpo.iter_on_goals
    ~add_update_hook:Wpo.add_modified_hook
    ~add_remove_hook:Wpo.add_removed_hook
    ~add_reload_hook:Wpo.add_cleared_hook
    gmodel

(* -------------------------------------------------------------------------- *)
