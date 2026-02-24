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

  let state_name = Domain.name ^ ".Store"

  (* This module stores the resulting states of an Eva analysis. They depends on
     the set of parameters with which the analysis has been run, and must be
     cleared each time one of this parameter is changed. Thus, the tables of
     this module have as dependencies Self.state, the internal state of Eva
     (all parameters of Eva are added as codependencies of this state).  *)
  let dependencies = [ Self.state ]
  let size = 16

  module type Ref = sig
    val get : unit -> bool
    val set : bool -> unit
  end

  (* Boolean reference saved on the disk. *)
  module Bool_Ref_State =
    State_builder.Ref
      (Datatype.Bool)
      (struct
        let dependencies = dependencies
        let name = state_name ^ ".Storage"
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
  module Storage =
    (val (if Descr.is_unmarshable Domain.datatype_descr
          then (module Bool_Ref)
          else (module Bool_Ref_State)) : Ref)

  module Global_State =
    State_builder.Option_ref (Domain)
      (struct
        let dependencies = dependencies
        let name = state_name ^ ".Global_State"
      end)

  module States_by_callstack =
    Callstack.Hashtbl.Make (Domain)

  module Table_By_Callstack =
    Cil_state_builder.Stmt_hashtbl(States_by_callstack)
      (struct
        let name = state_name ^ ".Table_By_Callstack"
        let size = size
        let dependencies = dependencies
      end)
  module Table =
    Cil_state_builder.Stmt_hashtbl (Domain)
      (struct
        let name = state_name ^ ".Table"
        let size = size
        let dependencies = [ Table_By_Callstack.self ]
      end)

  module AfterTable_By_Callstack =
    Cil_state_builder.Stmt_hashtbl (States_by_callstack)
      (struct
        let name = state_name ^ ".AfterTable_By_Callstack"
        let size = size
        let dependencies = dependencies
      end)
  module AfterTable =
    Cil_state_builder.Stmt_hashtbl (Domain)
      (struct
        let name = state_name ^ ".AfterTable"
        let size = size
        let dependencies = [ AfterTable_By_Callstack.self ]
      end)

  module Called_Functions_By_Callstack =
    State_builder.Hashtbl
      (Kernel_function.Hashtbl)
      (States_by_callstack)
      (struct
        let name = state_name ^ ".Called_Functions_By_Callstack"
        let size = 11
        let dependencies = dependencies
      end)

  module Called_Functions_Memo =
    State_builder.Hashtbl
      (Kernel_function.Hashtbl)
      (Domain)
      (struct
        let name = state_name ^ ".Called_Functions_Memo"
        let size = 11
        let dependencies = [ Called_Functions_By_Callstack.self ]
      end)


  let set_global_state state =
    (* Check parameters -eva-results and -eva-no-results-domain. *)
    let eva_results = Parameters.ResultsAll.get () in
    let domain_results = not (Parameters.NoResultsDomains.mem Domain.name) in
    let storage = eva_results && domain_results in
    Storage.set storage;
    if storage then Global_State.set state

  let get_global_state () =
    if not (Storage.get ())
    then `Value Domain.top
    else match Global_State.get_option () with
      | None -> `Bottom
      | Some state -> `Value state


  let set_initial_state ?callstack kf state =
    if Storage.get () then
      match callstack with
      | None -> Called_Functions_Memo.replace kf state
      | Some callstack ->
        let create _kf = Callstack.Hashtbl.create 7 in
        let by_callstack = Called_Functions_By_Callstack.memo create kf in
        Callstack.Hashtbl.replace by_callstack callstack state

  let get_initial_state ?callstack kf =
    if Storage.get ()
    then
      try
        match callstack with
        | None -> `Value (Called_Functions_Memo.find kf)
        | Some callstack ->
          let cs_tbl = Called_Functions_By_Callstack.find kf in
          `Value (Callstack.Hashtbl.find cs_tbl callstack)
      with Not_found -> `Bottom
    else `Value Domain.top

  let set_stmt_state ?callstack ~after stmt state =
    if Storage.get () then
      match callstack with
      | None ->
        if after
        then AfterTable.add stmt state
        else Table.add stmt state
      | Some callstack ->
        let create _stmt = Callstack.Hashtbl.create 7 in
        let by_callstack =
          if after
          then AfterTable_By_Callstack.memo create stmt
          else Table_By_Callstack.memo create stmt
        in
        Callstack.Hashtbl.replace by_callstack callstack state

  let get_stmt_state ?callstack ~after stmt =
    if Storage.get () then
      try
        match callstack with
        | None ->
          if after
          then `Value (AfterTable.find stmt)
          else `Value (Table.find stmt)
        | Some callstack ->
          let cs_tbl =
            if after
            then AfterTable_By_Callstack.find stmt
            else Table_By_Callstack.find stmt
          in
          `Value (Callstack.Hashtbl.find cs_tbl callstack)
      with Not_found -> `Bottom
    else `Value Domain.top


  let kf_callstacks kf =
    if Storage.get () then
      try `Value (Called_Functions_By_Callstack.find kf |> Callstack.Hashtbl.to_seq_keys)
      with Not_found -> `Value Seq.empty
    else `Top

  let stmt_callstacks stmt =
    if Storage.get () then
      try `Value (Table_By_Callstack.find stmt |> Callstack.Hashtbl.to_seq_keys)
      with Not_found -> `Value Seq.empty
    else `Top

  let is_enabled () = Storage.get ()
end
