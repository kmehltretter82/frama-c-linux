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

(* -------------------------------------------------------------------------- *)
(* --- Server API for WP                                                  --- *)
(* -------------------------------------------------------------------------- *)

module P = Server.Package
module D = Server.Data
module R = Server.Request
module S = Server.States
module Md = Markdown
module AST = Server.Kernel_ast

let package = P.package ~plugin:"wp" ~title:"WP Main Services" ()

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

module Prover =
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

module Result =
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

module STATUS =
struct
  type t = { smoke : bool ; verdict : VCS.verdict }
  let jtype = D.declare ~package ~name:"status"
      ~descr:(Md.plain "Test Status")
      (Junion [
          Jkey "NORESULT" ;
          Jkey "COMPUTING" ;
          Jkey "FAILED" ;
          Jkey "STEPOUT" ;
          Jkey "UNKNOWN" ;
          Jkey "VALID" ;
          Jkey "PASSED" ;
          Jkey "DOOMED" ;
        ])
  let to_json { smoke ; verdict } =
    `String begin
      match verdict with
      | VCS.Valid -> if smoke then "DOOMED" else "VALID"
      | VCS.Unknown -> if smoke then "PASSED" else "UNKNOWN"
      | Failed -> "FAILED"
      | NoResult -> "NORESULT"
      | Computing _ -> "COMPUTING"
      | Timeout -> "TIMEOUT"
      | Stepout -> "STEPOUT"
    end
end

module STATS =
struct
  type t = Stats.stats
  let jtype = D.declare ~package ~name:"stats"
      ~descr:(Md.plain "Prover Result")
      (Jrecord [
          "summary", Jstring;
          "tactics", Jnumber;
          "proved", Jnumber;
          "total", Jnumber;
        ])
  let to_json cs : Json.t =
    let summary = Pretty_utils.to_string
        (Stats.pp_stats ~shell:false ~cache:Update) cs
    in `Assoc [
      "summary", `String summary ;
      "tactics", `Int cs.tactics ;
      "proved", `Int cs.proved ;
      "total", `Int (Stats.subgoals cs) ;
    ]
end

let () = R.register ~package ~kind:`GET ~name:"getAvailableProvers"
    ~descr:(Md.plain "Returns the list of configured provers from why3")
    ~input:(module D.Junit) ~output:(module D.Jlist(Prover))
    (fun () ->
       List.map (fun p -> VCS.Why3 p) @@
       List.filter Why3Provers.is_mainstream @@
       Why3Provers.provers ())

(* -------------------------------------------------------------------------- *)
(* --- Goal Array                                                         --- *)
(* -------------------------------------------------------------------------- *)

let gmodel : Wpo.t S.model = S.model ()

let get_decl g = match g.Wpo.po_idx with
  | Function(kf,_) -> Some (Printer_tag.SFunction kf)
  | Axiomatic _ -> None (* TODO *)

let get_kf g = match g.Wpo.po_idx with
  | Function(kf,_) -> Some kf
  | Axiomatic _ -> None

let get_bhv g = match g.Wpo.po_idx with
  | Function(_,bhv) -> bhv
  | Axiomatic _ -> None

let get_thy g = match g.Wpo.po_idx with
  | Function _ -> None
  | Axiomatic ax -> ax

let get_status g =
  STATUS.{
    smoke = Wpo.is_smoke_test g ;
    verdict = (ProofEngine.consolidated g).best ;
  }

let () = S.column gmodel ~name:"property"
    ~descr:(Md.plain "Property Marker")
    ~data:(module AST.Marker)
    ~get:(fun g -> Printer_tag.PIP (WpPropId.property_of_id g.Wpo.po_pid))

let () = S.column gmodel ~name:"scope"
    ~descr:(Md.plain "Associated declaration, if any")
    ~data:(module D.Joption(AST.Decl)) ~get:get_decl

let () = S.column gmodel ~name:"fct"
    ~descr:(Md.plain "Associated function, if any")
    ~data:(module D.Joption(AST.Function)) ~get:get_kf

let () = S.option gmodel ~name:"bhv"
    ~descr:(Md.plain "Associated behavior, if any")
    ~data:(module D.Jstring) ~get:get_bhv

let () = S.option gmodel ~name:"thy"
    ~descr:(Md.plain "Associated axiomatic, if any")
    ~data:(module D.Jstring) ~get:get_thy

let () = S.column gmodel ~name:"name"
    ~descr:(Md.plain "Informal Property Name")
    ~data:(module D.Jstring)
    ~get:(fun g -> g.Wpo.po_name)

let () = S.column gmodel ~name:"smoke"
    ~descr:(Md.plain "Smoking (or not) goal")
    ~data:(module D.Jbool) ~get:Wpo.is_smoke_test

let () = S.column gmodel ~name:"passed"
    ~descr:(Md.plain "Valid or Passed goal")
    ~data:(module D.Jbool) ~get:Wpo.is_passed

let () = S.column gmodel ~name:"status"
    ~descr:(Md.plain "Verdict, Status")
    ~data:(module STATUS) ~get:get_status

let () = S.column gmodel ~name:"stats"
    ~descr:(Md.plain "Prover Stats Summary")
    ~data:(module STATS) ~get:ProofEngine.consolidated

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

let _ = S.register_array ~package ~name:"goals"
    ~descr:(Md.plain "Generated Goals")
    ~key:(fun g -> g.Wpo.po_gid)
    ~keyName:"wpo"
    ~keyType:Goal.jtype
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
