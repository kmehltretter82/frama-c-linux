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
      let name = "WpApi.INDEX"
      let dependencies = [ Ast.self ]
      let default () = Hashtbl.create 0
    end)

module Goal : D.S with type t = Wpo.t =
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

let () = R.register ~package ~kind:`GET ~name:"getAvailableProvers"
    ~descr:(Md.plain "Returns the list of configured provers from why3")
    ~input:(module D.Junit) ~output:(module D.Jlist(PROVER))
    (fun () ->
       List.map (fun p -> VCS.Why3 p) @@
       List.filter Why3Provers.is_mainstream @@
       Why3Provers.provers ())

(* -------------------------------------------------------------------------- *)
(* --- Goal Array                                                         --- *)
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

let () = S.option gmodel ~name:"bhv"
    ~descr:(Md.plain "Associated behavior, if any")
    ~data:(module D.Jstring) ~get:get_bhv

let () = S.option gmodel ~name:"thy"
    ~descr:(Md.plain "Associated axiomatic, if any")
    ~data:(module D.Jstring) ~get:get_thy

let () = S.column gmodel ~name:"smoke"
    ~descr:(Md.plain "Smoke Test Goal")
    ~data:(module D.Jbool) ~get:Wpo.is_smoke_test

let () = S.column gmodel ~name:"passed"
    ~descr:(Md.plain "Successfull Goal")
    ~data:(module D.Jbool) ~get:Wpo.is_passed

let () = S.column gmodel ~name:"stats"
    ~descr:(Md.plain "Verdict Details")
    ~data:(module STATS) ~get:get_stats

let () = S.option gmodel ~name:"script"
    ~descr:(Md.plain "Script File")
    ~data:(module D.Jstring)
    ~get:(fun wpo ->
        match ProofSession.get wpo with
        | NoScript -> None
        | Script a | Deprecated a -> Some a)

let () = S.column gmodel ~name:"saved"
    ~descr:(Md.plain "Saved Script")
    ~data:(module D.Jbool)
    ~get:(fun wpo -> ProofEngine.get wpo = `Saved)

let garray = S.register_array ~package ~name:"goals"
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
(* --- Proof Server                                                       --- *)
(* -------------------------------------------------------------------------- *)

let serverActivity = R.signal ~package
    ~name:"serverActivity"
    ~descr:(Md.plain "Proof Server Activity")

let () =
  let server_sig = R.signature ~input:(module D.Junit) () in
  let set_procs = R.result server_sig
      ~name:"procs" ~descr:(Md.plain "Max parallel tasks") (module D.Jint) in
  let set_active = R.result server_sig
      ~name:"active" ~descr:(Md.plain "Active tasks") (module D.Jint) in
  let set_done = R.result server_sig
      ~name:"done" ~descr:(Md.plain "Finished tasks") (module D.Jint) in
  let set_todo = R.result server_sig
      ~name:"todo" ~descr:(Md.plain "Remaining jobs") (module D.Jint) in
  R.register_sig ~package ~kind:`GET ~name:"getScheduledTasks"
    ~descr:(Md.plain "Scheduled tasks in proof server")
    ~signals:[serverActivity]
    server_sig
    begin
      let monitored = ref false in
      fun rq () ->
        let server = ProverTask.server () in
        if not !monitored then
          begin
            monitored := true ;
            let signal () = R.emit serverActivity in
            Task.on_server_activity server signal ;
            Task.on_server_start server signal ;
            Task.on_server_stop server signal ;
          end ;
        set_procs rq (Task.get_procs server) ;
        set_active rq (Task.running server) ;
        set_done rq (Task.terminated server) ;
        set_todo rq (Task.remaining server) ;
    end

let () = R.register ~package ~kind:`SET ~name:"cancelProofTasks"
    ~descr:(Md.plain "Cancel all scheduled proof tasks")
    ~input:(module D.Junit) ~output:(module D.Junit)
    (fun () -> let server = ProverTask.server () in Task.cancel_all server)

(* -------------------------------------------------------------------------- *)
(* --- Proof Node                                                         --- *)
(* -------------------------------------------------------------------------- *)

let proofStatus = R.signal ~package ~name:"proofStatus"
    ~descr:(Md.plain "Proof Status has changed")

module Node = D.Index(Map.Make(ProofEngine.Node))(struct let name = "node" end)

let () =
  let snode = R.signature ~input:(module Node) () in
  let set_title = R.result snode ~name:"result"
      ~descr:(Md.plain "Proof node title") (module D.Jstring) in
  let set_proved = R.result snode ~name:"proved"
      ~descr:(Md.plain "Proof node complete") (module D.Jbool) in
  let set_pending = R.result snode ~name:"pending"
      ~descr:(Md.plain "Pending children") (module D.Jint) in
  let set_size = R.result snode ~name:"size"
      ~descr:(Md.plain "Proof size") (module D.Jint) in
  let set_stats = R.result snode ~name:"stats"
      ~descr:(Md.plain "Node statistics") (module D.Jstring) in
  R.register_sig ~package ~kind:`GET ~name:"getNodeInfos"
    ~descr:(Md.plain "Proof node information") snode
    ~signals:[proofStatus;S.signal garray]
    begin fun rq node ->
      set_title rq (ProofEngine.title node) ;
      set_proved rq (ProofEngine.proved node) ;
      set_pending rq (ProofEngine.pending node) ;
      let s = ProofEngine.stats node in
      set_size rq (Stats.proofs s) ;
      set_stats rq (Pretty_utils.to_string Stats.pretty s) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Proof Tree                                                         --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let state = R.signature ~input:(module Goal) () in
  let set_current = R.result state ~name:"current"
      ~descr:(Md.plain "Current proof node") (module Node) in
  let set_parents = R.result state ~name:"parents"
      ~descr:(Md.plain "Proof node parents") (module D.Jlist(Node)) in
  let set_pending = R.result state ~name:"pending"
      ~descr:(Md.plain "Pending proof nodes") (module D.Jint) in
  let set_index = R.result state ~name:"index"
      ~descr:(Md.plain "Current node index among pending nodes (else -1)")
      (module D.Jint) in
  let set_results = R.result state ~name:"results"
      ~descr:(Md.plain "Prover results for current node")
      (module D.Jlist(D.Jpair(PROVER)(RESULT))) in
  let set_tactic = R.result state ~name:"tactic"
      ~descr:(Md.plain "Proof node tactic header (if any)")
      (module D.Jstring) in
  let set_children = R.result state ~name:"children"
      ~descr:(Md.plain "Proof node tactic children (id any)")
      (module D.Jlist(D.Jpair(D.Jstring)(Node))) in
  R.register_sig ~package
    ~kind:`GET ~name:"getProofState"
    ~descr:(Md.plain "Current Proof Status of a Goal") state
    ~signals:[proofStatus;S.signal garray]
    begin fun rq wpo ->
      let tree = ProofEngine.proof ~main:wpo in
      let current,index =
        match ProofEngine.current tree with
        | `Main -> ProofEngine.root tree,-1
        | `Internal node -> node,-1
        | `Leaf(idx,node) -> node,idx in
      let rec parents node = match ProofEngine.parent node with
        | None -> []
        | Some p -> p::parents p in
      let tactic = match ProofEngine.tactical current with
        | None -> ""
        | Some { header } -> header in
      set_current rq current ;
      set_parents rq (parents current) ;
      set_index rq index ;
      set_pending rq (ProofEngine.pending current) ;
      set_results rq (Wpo.get_results (ProofEngine.goal current)) ;
      set_tactic rq tactic ;
      set_children rq (ProofEngine.children current) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Proof Tree Management                                              --- *)
(* -------------------------------------------------------------------------- *)

let () = R.register ~package ~kind:`SET ~name:"goForward"
    ~descr:(Md.plain "Go to to first pending node, or root if none")
    ~input:(module Goal) ~output:(module D.Junit)
    begin fun goal ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.forward tree ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToRoot"
    ~descr:(Md.plain "Go to root of proof tree")
    ~input:(module Goal) ~output:(module D.Junit)
    begin fun goal ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.goto tree `Main ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToIndex"
    ~descr:(Md.plain "Go to k-th pending node of proof tree")
    ~input:(module D.Jpair(Goal)(D.Jint)) ~output:(module D.Junit)
    begin fun (goal,index) ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.goto tree (`Leaf index) ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToNode"
    ~descr:(Md.plain "Set current node of associated proof tree")
    ~input:(module Node) ~output:(module D.Junit)
    begin fun node ->
      let tree = ProofEngine.tree node in
      ProofEngine.goto tree (`Node node) ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"removeNode"
    ~descr:(Md.plain "Remove node from tree and go to parent")
    ~input:(module Node) ~output:(module D.Junit)
    begin fun node ->
      let tree = ProofEngine.tree node in
      ProofEngine.remove tree node ;
      R.emit proofStatus ;
    end

(* -------------------------------------------------------------------------- *)
