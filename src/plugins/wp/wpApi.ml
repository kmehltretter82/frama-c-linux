(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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

module WP_Prover = Prover

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

let indexGoal g =
  let id = g.Wpo.po_gid in
  let index = INDEX.get () in
  if not (Hashtbl.mem index id) then Hashtbl.add index id g ; id

module Goal : D.S with type t = Wpo.t =
struct
  type t = Wpo.t
  let jtype = D.declare ~package ~name:"goal"
      ~descr:(Md.plain "Proof Obligations") (Jkey "wpo")
  let of_json js = Hashtbl.find (INDEX.get ()) (Json.string js)
  let to_json g = `String (indexGoal g)
end

(* -------------------------------------------------------------------------- *)
(* --- VCS Provers                                                        --- *)
(* -------------------------------------------------------------------------- *)

module Prover =
struct
  type t = Prover.t
  let jtype = D.declare ~package ~name:"prover"
      ~descr:(Md.plain "Prover Identifier") (Jkey "prover")
  let to_json prv = `String (WP_Prover.name prv)
  let of_json js =
    match Prover.parse @@ Json.string js with
    | Some prv -> prv
    | None -> D.failure "Unknown prover name"
end

module Provers = D.Jlist(Prover)

let signal = ref None
let provers = ref None

let parse cmdline =
  let cmdline = match cmdline with
    | [] -> [ "Alt-Ergo" ]
    | provers -> provers
  in
  let parse s =
    match WP_Prover.parse s with
    | None -> None
    | Some (Qed | Tactical) -> None
    | Some prv as result -> if WP_Prover.is_auto prv then result else None in
  List.filter_map parse cmdline

let getProvers () =
  match !provers with
  | Some prvs -> prvs
  | None ->
    let selection = parse @@ Wp_parameters.Provers.get () in
    provers := Some selection ; selection

let updProvers prv =
  provers := Some prv

let setProvers prv =
  updProvers prv ;
  Option.iter (fun s -> R.emit s)
    !signal

let () =
  Wp_parameters.Provers.add_update_hook
    (fun _ provers -> setProvers @@ parse provers)

let () =
  let s =
    S.register_state ~package ~name:"provers"
      ~descr:(Md.plain "Selected Provers")
      ~data:(module Provers)
      ~get:getProvers
      ~set:updProvers ()
  in signal := Some s

(* -------------------------------------------------------------------------- *)
(* --- Server Processes                                                   --- *)
(* -------------------------------------------------------------------------- *)

let _ =
  S.register_state ~package
    ~name:"process"
    ~descr:(Md.plain "Server Processes")
    ~data:(module D.Jint)
    ~get:Wp_parameters.Procs.get
    ~set:(fun procs ->
        Wp_parameters.Procs.set procs ;
        ignore @@ ProverTask.server ~procs ())
    ~add_hook:Wp_parameters.Procs.add_hook_on_update ()

(* -------------------------------------------------------------------------- *)
(* --- Provers Timeout                                                    --- *)
(* -------------------------------------------------------------------------- *)

let _ =
  S.register_state ~package
    ~name:"timeout"
    ~descr:(Md.plain "Prover's Timeout")
    ~data:(module D.Jint)
    ~get:Wp_parameters.Timeout.get
    ~set:Wp_parameters.Timeout.set
    ~add_hook:Wp_parameters.Timeout.add_hook_on_update ()

(* -------------------------------------------------------------------------- *)
(* --- Available Provers                                                  --- *)
(* -------------------------------------------------------------------------- *)

let get_name = function
  | WP_Prover.Qed -> "Qed"
  | Tactical -> "Script"
  | Why3 p -> Why3Provers.name p

let get_version = function
  | WP_Prover.Qed | Tactical -> System_config.Version.id_and_codename
  | Why3 p -> Why3Provers.version p

let iter_provers fn =
  List.iter
    (fun p ->
       if Why3Provers.is_mainstream p then fn (WP_Prover.Why3 p))
  @@ Why3Provers.provers ()

let _ : WP_Prover.t S.array =
  let model = S.model () in
  S.column ~name:"name" ~descr:(Md.plain "Prover Name")
    ~data:(module D.Jalpha) ~get:get_name model ;
  S.column ~name:"version" ~descr:(Md.plain "Prover Version")
    ~data:(module D.Jalpha) ~get:get_version model ;
  S.column ~name:"descr" ~descr:(Md.plain "Prover Full Name (description)")
    ~data:(module D.Jalpha) ~get:(WP_Prover.title ~version:true) model ;
  S.register_array ~package
    ~name:"ProverInfos" ~descr:(Md.plain "Available Provers")
    ~key:WP_Prover.name
    ~keyName:"prover"
    ~keyType:Prover.jtype
    ~iter:iter_provers model

(* -------------------------------------------------------------------------- *)
(* --- Interactive provers                                                --- *)
(* -------------------------------------------------------------------------- *)

let _ =
  R.register
    ~package ~kind:`GET ~name:"isInteractiveProver"
    ~descr:(Md.plain "Tells whether the prover is interactive")
    ~input:(module Prover)
    ~output:(module D.Jbool)
    (fun p -> not @@ WP_Prover.is_auto p)

module InteractiveMode =
struct
  include D.Enum

  let dictionary : WP_Prover.InteractiveMode.t dictionary = dictionary ()

  let tag name descr value = tag ~name ~descr:(Md.plain descr) ~value dictionary

  let batch  = tag "batch"  "Batch"     WP_Prover.InteractiveMode.Batch
  let update = tag "update" "Update"    WP_Prover.InteractiveMode.Update
  let edit   = tag "edit"   "Edit"      WP_Prover.InteractiveMode.Edit
  let fix    = tag "fix"    "Fix"       WP_Prover.InteractiveMode.Fix
  let fixup  = tag "fixup"  "FixUpdate" WP_Prover.InteractiveMode.FixUpdate

  let lookup = function
    | WP_Prover.InteractiveMode.Batch -> batch
    | Update -> update
    | Edit -> edit
    | Fix -> fix
    | FixUpdate -> fixup

  let () =
    set_lookup dictionary lookup

  include
    (val publish
        ~package
        ~descr:(Md.plain "interactive mode")
        ~name:"InteractiveMode"
        dictionary)
end

(* -------------------------------------------------------------------------- *)
(* --- Counter Examples                                                   --- *)
(* -------------------------------------------------------------------------- *)

let _ =
  S.register_state ~package
    ~name:"counterExamples"
    ~descr:(Md.plain "Enabled Counter Examples")
    ~data:(module D.Jbool)
    ~get:Wp_parameters.CounterExamples.get
    ~set:Wp_parameters.CounterExamples.set
    ~add_hook:Wp_parameters.CounterExamples.add_hook_on_update ()

(* -------------------------------------------------------------------------- *)
(* --- Results and Stats                                                  --- *)
(* -------------------------------------------------------------------------- *)

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
      "verdict", `String (VCS.name_of_verdict ~computing:true r.verdict) ;
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
      | Valid -> if smoke then "DOOMED" else "VALID"
      | Invalid -> if smoke then "PASSED" else "INVALID"
      | Unknown -> if smoke then "PASSED" else "UNKNOWN"
      | Timeout -> if smoke then "PASSED" else "TIMEOUT"
      | Stepout -> if smoke then "PASSED" else "STEPOUT"
      | Failed -> "FAILED"
      | NoResult -> "NORESULT"
      | Computing _ -> "COMPUTING"
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
    let cache = Cache.get_mode () in
    let summary = Pretty_utils.to_string
        (Stats.pp_stats ~shell:false ~cache) cs
    in `Assoc [
      "summary", `String summary ;
      "tactics", `Int cs.tactics ;
      "proved", `Int cs.proved ;
      "total", `Int (Stats.subgoals cs) ;
    ]
end

(* -------------------------------------------------------------------------- *)
(* --- Goal Array                                                         --- *)
(* -------------------------------------------------------------------------- *)

let gmodel : Wpo.t S.model = S.model ()

let get_property g = Printer_tag.PIP (WpPropId.property_of_id g.Wpo.po_pid)

let get_marker g =
  match g.Wpo.po_formula.source with
  | Some(stmt,_) -> Printer_tag.localizable_of_stmt stmt
  | None ->
    let ip = WpPropId.property_of_id g.Wpo.po_pid in
    match ip with
    | IPOther { io_loc = OLStmt(_,stmt) } ->
      Printer_tag.localizable_of_stmt stmt
    | _ -> Printer_tag.PIP ip

let get_decl g = match g.Wpo.po_idx with
  | Function(kf,_) -> Some (Printer_tag.SFunction kf)
  | Axiomatic _ -> None (* TODO *)

let get_fct g = match g.Wpo.po_idx with
  | Function(kf,_) -> Some (Kernel_function.get_name kf)
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

let get_ast_dependencies g =
  let open Wpo in
  let module Stmts = Cil_datatype.Stmt.Set in
  let module Props = Property.Set in
  let add_stmt s l = Printer_tag.localizable_of_stmt s :: l in
  let add_prop p l = Printer_tag.PIP p :: l in
  Stmts.fold add_stmt g.po_formula.path @@
  Props.fold add_prop g.po_formula.deps []

let () = S.column gmodel ~name:"marker"
    ~descr:(Md.plain "Associated Marker")
    ~data:(module AST.Marker) ~get:get_marker

let () = S.column gmodel ~name:"scope"
    ~descr:(Md.plain "Associated declaration, if any")
    ~data:(module D.Joption(AST.Decl)) ~get:get_decl

let () = S.column gmodel ~name:"property"
    ~descr:(Md.plain "Property Marker")
    ~data:(module AST.Marker) ~get:get_property

let () = S.option gmodel ~name:"fct"
    ~descr:(Md.plain "Associated function name, if any")
    ~data:(module D.Jstring) ~get:get_fct

let () = S.option gmodel ~name:"bhv"
    ~descr:(Md.plain "Associated behavior name, if any")
    ~data:(module D.Jstring) ~get:get_bhv

let () = S.option gmodel ~name:"thy"
    ~descr:(Md.plain "Associated axiomatic name, if any")
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

let () = S.column gmodel ~name:"proof"
    ~descr:(Md.plain "Proof Tree")
    ~data:(module D.Jbool)
    ~get:ProofEngine.has_proof

let () = S.option gmodel ~name:"script"
    ~descr:(Md.plain "Script File")
    ~data:(module D.Jstring)
    ~get:(fun wpo ->
        match ProofSession.get wpo with
        | NoScript -> None
        | Script a | Deprecated a -> Some (Filepath.to_string_abs a))

let () = S.column gmodel ~name:"saved"
    ~descr:(Md.plain "Saved Script")
    ~data:(module D.Jbool)
    ~get:(fun wpo -> ProofEngine.get wpo = `Saved)

let () = S.column gmodel ~name:"deps"
    ~descr:(Md.plain "Dependencies")
    ~data:(module D.Jlist(AST.Marker))
    ~get:get_ast_dependencies

let filter hook fn = hook (fun g -> if not @@ Wpo.is_tactic g then fn g)
let (++) h1 h2 fn = h1 fn ; h2 fn

let goals =
  let add_remove_hook =
    filter Wpo.add_removed_hook in
  let add_update_hook =
    filter Wpo.add_modified_hook ++ ProofEngine.add_goal_hook in
  let add_reload_hook = Wpo.add_cleared_hook in
  S.register_array ~package ~name:"goals"
    ~descr:(Md.plain "Generated Goals")
    ~key:indexGoal
    ~keyName:"wpo"
    ~keyType:Goal.jtype
    ~iter:(filter Wpo.iter_on_goals)
    ~preload:ProofEngine.consolidate
    ~add_remove_hook
    ~add_update_hook
    ~add_reload_hook
    gmodel

let () =
  R.register ~package ~kind:`GET ~name:"getGoalsFromASTMarker"
    ~descr:(Md.plain "Get goals from AST marker")
    ~input:(module AST.Marker)
    ~output:(module D.Jlist(Goal))
    begin fun marker ->
      let open Printer_tag in
      let has_marker g =
        let is_marker = Localizable.equal marker in
        let in_stmt = match g.Wpo.po_formula.source with
          | Some(stmt,_) -> is_marker @@ localizable_of_stmt stmt
          | None -> false
        in
        in_stmt ||
        match WpPropId.property_of_id g.Wpo.po_pid with
        | IPOther {io_loc = OLStmt(_,s)} -> is_marker @@ localizable_of_stmt s
        | ip -> is_marker @@ Printer_tag.PIP ip
      in
      let select g = has_marker g && not @@ Wpo.is_tactic g in
      let l = ref [] in
      Wpo.iter_on_goals(fun g -> if select g then l := g :: !l) ;
      List.sort Wpo.S.compare !l
    end

(* -------------------------------------------------------------------------- *)
(* --- Generate RTEs                                                      --- *)
(* -------------------------------------------------------------------------- *)

let () =
  R.register ~package ~kind:`EXEC ~name:"generateRTEGuards"
    ~descr:(Md.plain "Generate RTE guards for the function")
    ~input:(module AST.Marker)
    ~output:(module D.Junit)
    begin function
      | PVDecl (Some kf, _, _) ->
        let setup = Factory.parse (Wp_parameters.Model.get ()) in
        let driver = Driver.load_driver () in
        let model = Factory.instance setup driver in
        WpRTE.generate model kf
      | _ -> ()
    end

(* -------------------------------------------------------------------------- *)
(* --- Generate goals                                                     --- *)
(* -------------------------------------------------------------------------- *)

let is_call stmt =
  match stmt.Cil_types.skind with
  | Instr (Call _) | Instr (Local_init (_, ConsInit _, _)) -> true
  | _ -> false

let start_proofs_marker = function
  | Printer_tag.PExp _  | PTermLval _ | PLval _
  | PGlobal _ | PType _ | PVDecl (None, _, _) ->
    (* We cannot run anything here *) ()
  | PStmtStart (_, stmt) | PStmt (_, stmt) when is_call stmt ->
    VC.command @@ VC.generate_call stmt
  | PStmtStart (kf, stmt) | PStmt (kf, stmt) ->
    let fold_ips _ ca bag =
      let ids = WpPropId.mk_code_annot_ids kf stmt ca in
      let props = Bag.ulist @@
        List.map VC.generate_ip @@
        List.map WpPropId.property_of_id ids
      in
      Bag.concat bag props
    in
    VC.command @@ Annotations.fold_code_annot fold_ips stmt Bag.empty
  | PVDecl (Some kf, _, _) ->
    VC.command @@ VC.generate_kf kf
  | PIP property ->
    VC.command @@ VC.generate_ip property

let () =
  R.register ~package ~kind:`EXEC ~name:"startProofs"
    ~descr:(Md.plain "Generate goals and run provers")
    ~input:(module D.Joption(AST.Marker))
    ~output:(module D.Junit)
    begin function
      | None -> VC.command @@ VC.generate_all ()
      | Some marker -> start_proofs_marker marker
    end

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
