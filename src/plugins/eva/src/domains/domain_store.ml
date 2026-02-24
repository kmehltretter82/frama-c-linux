(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

module type InputDomain = sig
  include Datatype.S
  val name: string
  val top: t
end

module type S = sig
  type t

  val set_global_state: t -> unit
  val set_initial_state: ?callstack:Callstack.t -> kernel_function -> t -> unit
  val set_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t -> unit

  val get_global_state: unit -> t or_bottom
  val get_initial_state: ?callstack:Callstack.t -> kernel_function -> t or_bottom
  val get_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t or_bottom

  val kf_callstacks: kernel_function -> Callstack.t Seq.t or_top
  val stmt_callstacks: stmt -> Callstack.t Seq.t or_top

  val is_enabled: unit -> bool
end

module Make (Domain: InputDomain) = struct

  let info name : (module State_builder.Info_with_size) =
    (module struct
      let name = Format.asprintf "Eva.Domain_store.%s.%s" name Domain.name
      let size = 17
      let dependencies = [ Self.state ]
    end)

  module type Ref = sig
    val get : unit -> bool
    val set : bool -> unit
  end

  (* Boolean reference saved on the disk. *)
  module Bool_Ref_State =
    State_builder.Ref
      (Datatype.Bool)
      (struct
        let dependencies = [ Self.state ]
        let name = "Eva.Domain_store.Save." ^ Domain.name
        let default () = false
      end)

  (* Boolean reference. Not saved on the disk. *)
  module Bool_Ref = struct
    let x = ref false
    let set y = x := y
    let get () = !x
  end

  (* A boolean reference indicating whether the states of the domain have been
     saved. False by default, it becomes true when the engine calls
     [register_global_state] at the start of the analysis.
     If the domain is unmarshallable, its states cannot be saved on the
     disk, and this boolean should not be saved either. *)
  module Save =
    (val (if Descr.is_unmarshable Domain.datatype_descr
          then (module Bool_Ref)
          else (module Bool_Ref_State)) : Ref)

  module Global_State =
    State_builder.Option_ref (Domain) (val info "Global_State")

  (* Initial state by function. *)
  module Initial_State =
    Kernel_function.Make_Table (Domain) (val info "Initial_State")

  (* Consolidated state before each statement.*)
  module Before_Stmt =
    Cil_state_builder.Stmt_hashtbl (Domain) (val info "Before_Stmt")

  (* Consolidated state after each statement.*)
  module After_Stmt =
    Cil_state_builder.Stmt_hashtbl (Domain) (val info "After_Stmt")

  module States_by_callstack = Callstack.Hashtbl.Make (Domain)

  (* Initial state by callstack. *)
  module Initial_State_By_Callstack =
    Kernel_function.Make_Table
      (States_by_callstack) (val info "Initial_State_By_Callstack")

  (* State before statement, by callstack. *)
  module Before_Stmt_By_Callstack =
    Cil_state_builder.Stmt_hashtbl
      (States_by_callstack) (val info "Before_Stmt_By_Callstack")

  (* State after statement, by callstack. *)
  module After_Stmt_By_Callstack =
    Cil_state_builder.Stmt_hashtbl
      (States_by_callstack) (val info "After_Stmt_By_Callstack")


  let set_global_state state =
    (* Check parameters -eva-results and -eva-no-results-domain. *)
    let eva_results = Parameters.ResultsAll.get () in
    let domain_results = not (Parameters.NoResultsDomains.mem Domain.name) in
    let save = eva_results && domain_results in
    Save.set save;
    if save then Global_State.set state

  let get_global_state () =
    if not (Save.get ())
    then `Value Domain.top
    else match Global_State.get_option () with
      | None -> `Bottom
      | Some state -> `Value state


  let set_initial_state ?callstack kf state =
    if Save.get () then
      match callstack with
      | None -> Initial_State.replace kf state
      | Some callstack ->
        let create _kf = Callstack.Hashtbl.create 7 in
        let by_callstack = Initial_State_By_Callstack.memo create kf in
        Callstack.Hashtbl.replace by_callstack callstack state

  let get_initial_state ?callstack kf =
    if Save.get ()
    then
      try
        match callstack with
        | None -> `Value (Initial_State.find kf)
        | Some callstack ->
          let cs_tbl = Initial_State_By_Callstack.find kf in
          `Value (Callstack.Hashtbl.find cs_tbl callstack)
      with Not_found -> `Bottom
    else `Value Domain.top

  let set_stmt_state ?callstack ~after stmt state =
    if Save.get () then
      match callstack with
      | None ->
        if after
        then After_Stmt.replace stmt state
        else Before_Stmt.replace stmt state
      | Some callstack ->
        let create _stmt = Callstack.Hashtbl.create 7 in
        let by_callstack =
          if after
          then After_Stmt_By_Callstack.memo create stmt
          else Before_Stmt_By_Callstack.memo create stmt
        in
        Callstack.Hashtbl.replace by_callstack callstack state

  let get_stmt_state ?callstack ~after stmt =
    if Save.get () then
      try
        match callstack with
        | None ->
          if after
          then `Value (After_Stmt.find stmt)
          else `Value (Before_Stmt.find stmt)
        | Some callstack ->
          let cs_tbl =
            if after
            then After_Stmt_By_Callstack.find stmt
            else Before_Stmt_By_Callstack.find stmt
          in
          `Value (Callstack.Hashtbl.find cs_tbl callstack)
      with Not_found -> `Bottom
    else `Value Domain.top


  let kf_callstacks kf =
    if Save.get () then
      try `Value (Initial_State_By_Callstack.find kf
                  |> Callstack.Hashtbl.to_seq_keys)
      with Not_found -> `Value Seq.empty
    else `Top

  let stmt_callstacks stmt =
    if Save.get () then
      try `Value (Before_Stmt_By_Callstack.find stmt
                  |> Callstack.Hashtbl.to_seq_keys)
      with Not_found -> `Value Seq.empty
    else `Top

  let is_enabled () = Save.get ()
end
